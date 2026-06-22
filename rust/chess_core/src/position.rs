//! The board position: bitboards + mailbox, incremental Zobrist hash, and
//! make/unmake with full rule handling (castling, en passant, promotion).

use crate::attacks::{
    bishop_attacks, king_attacks, knight_attacks, pawn_attacks, rook_attacks,
};
use crate::bitboard::{bit, pop_lsb, Bitboard};
use crate::types::{file_of, kind, CastlingRights, Color, Move, Piece, Square, Variant, HILL};
use crate::zobrist::zobrist;

/// Hash keys mixing the per-side delivered-check counts into the Zobrist hash
/// (Three-check), so the transposition table distinguishes otherwise-identical
/// positions with different check counts. Zero counts contribute nothing.
const CHECK_KEY: [u64; 2] = [0x9E3779B97F4A7C15, 0xC2B2AE3D27D4EB4F];

#[inline]
fn check_hash(checks: [u8; 2]) -> u64 {
    (checks[0] as u64).wrapping_mul(CHECK_KEY[0])
        ^ (checks[1] as u64).wrapping_mul(CHECK_KEY[1])
}

/// Hash keys mixing the Crazyhouse reserve counts into the Zobrist hash, so the
/// transposition table distinguishes positions with different hands. Empty hands
/// contribute nothing.
const HAND_KEY: [[u64; 5]; 2] = [
    [
        0xD6E8FEB86659FD93,
        0xA0761D6478BD642F,
        0xE7037ED1A0B428DB,
        0x8EBC6AF09C88C6E3,
        0x589965CC75374CC3,
    ],
    [
        0x1D8E4E27C47D124F,
        0xEB44ACCAB455D165,
        0x589965CC75374CC3,
        0x9E6C63D0673C6E1B,
        0xC2B2AE3D27D4EB4F,
    ],
];

#[inline]
fn hand_hash(hand: [[u8; 5]; 2]) -> u64 {
    let mut h = 0u64;
    for c in 0..2 {
        for p in 0..5 {
            h ^= (hand[c][p] as u64).wrapping_mul(HAND_KEY[c][p]);
        }
    }
    h
}

/// Per-square mask ANDed into castling rights whenever the square is the source
/// or target of a move (handles king/rook moves and rook captures uniformly).
const fn castle_masks() -> [u8; 64] {
    let mut m = [0b1111u8; 64];
    m[4] = 0b1100; // e1: clear WK|WQ
    m[0] = 0b1101; // a1: clear WQ
    m[7] = 0b1110; // h1: clear WK
    m[60] = 0b0011; // e8: clear BK|BQ
    m[56] = 0b0111; // a8: clear BQ
    m[63] = 0b1011; // h8: clear BK
    m
}
static CASTLE_MASK: [u8; 64] = castle_masks();

/// State needed to reverse a [`Move`].
#[derive(Clone, Copy)]
pub struct Undo {
    captured: Option<(Color, Piece)>,
    captured_sq: Square,
    prev_castling: CastlingRights,
    prev_ep: Option<Square>,
    prev_halfmove: u16,
    prev_hash: u64,
    prev_checks: [u8; 2],
    /// Atomic: pieces removed by the explosion (the capturing piece + adjacent
    /// non-pawns), for exact restoration on unmake. Empty for non-Atomic moves.
    exploded: [Option<(Color, Piece, Square)>; 9],
    exploded_len: u8,
    /// Crazyhouse: reserve + promoted-square mask before the move (restored
    /// wholesale on unmake).
    prev_hand: [[u8; 5]; 2],
    prev_promoted: Bitboard,
}

#[derive(Clone)]
pub struct Position {
    /// [color][piece] occupancy bitboards.
    pub pieces: [[Bitboard; 6]; 2],
    /// Per-color occupancy.
    pub occ: [Bitboard; 2],
    /// All occupied squares.
    pub all: Bitboard,
    /// Redundant mailbox for fast lookups.
    pub mailbox: [Option<(Color, Piece)>; 64],
    pub side: Color,
    pub castling: CastlingRights,
    pub ep: Option<Square>,
    pub halfmove: u16,
    pub fullmove: u32,
    pub hash: u64,
    /// Game variant (Standard for normal chess).
    pub variant: Variant,
    /// Three-check: number of checks each colour has delivered. [white, black].
    pub checks: [u8; 2],
    /// Chess960 castling geometry: the king's home square per colour and each
    /// castling rook's home square ([colour][0 = kingside, 1 = queenside]).
    /// Standard values for normal chess (used only when variant == Chess960).
    pub castle_king_home: [Square; 2],
    pub castle_rook_sq: [[Square; 2]; 2],
    /// Crazyhouse reserve: captured pieces in hand, [colour][Pawn..Queen].
    pub hand: [[u8; 5]; 2],
    /// Crazyhouse: squares holding a promoted pawn (revert to pawn when taken).
    pub promoted: Bitboard,
}

impl Position {
    pub fn empty() -> Position {
        Position {
            pieces: [[0; 6]; 2],
            occ: [0; 2],
            all: 0,
            mailbox: [None; 64],
            side: Color::White,
            castling: CastlingRights(0),
            ep: None,
            halfmove: 0,
            fullmove: 1,
            hash: 0,
            variant: Variant::Standard,
            checks: [0, 0],
            // Standard chess geometry: kings on e1/e8, rooks on h/a.
            castle_king_home: [4, 60],
            castle_rook_sq: [[7, 0], [63, 56]],
            hand: [[0; 5]; 2],
            promoted: 0,
        }
    }

    /// Standard starting position.
    pub fn startpos() -> Position {
        crate::fen::parse_fen(crate::START_FEN).expect("valid start FEN")
    }

    #[inline]
    pub fn pieces(&self, c: Color, p: Piece) -> Bitboard {
        self.pieces[c.index()][p.index()]
    }

    #[inline]
    pub fn piece_at(&self, sq: Square) -> Option<(Color, Piece)> {
        self.mailbox[sq as usize]
    }

    #[inline]
    pub fn king_sq(&self, c: Color) -> Square {
        crate::bitboard::lsb(self.pieces(c, Piece::King))
    }

    pub fn put_piece(&mut self, c: Color, p: Piece, sq: Square) {
        let b = bit(sq);
        self.pieces[c.index()][p.index()] |= b;
        self.occ[c.index()] |= b;
        self.all |= b;
        self.mailbox[sq as usize] = Some((c, p));
        self.hash ^= zobrist().piece(c, p, sq);
    }

    pub fn remove_piece(&mut self, c: Color, p: Piece, sq: Square) {
        let b = bit(sq);
        self.pieces[c.index()][p.index()] &= !b;
        self.occ[c.index()] &= !b;
        self.all &= !b;
        self.mailbox[sq as usize] = None;
        self.hash ^= zobrist().piece(c, p, sq);
    }

    /// Is `sq` attacked by any piece of color `by`?
    pub fn is_attacked(&self, sq: Square, by: Color) -> bool {
        // Pawns: squares from which a `by` pawn would attack `sq`.
        if pawn_attacks(by.opp(), sq) & self.pieces(by, Piece::Pawn) != 0 {
            return true;
        }
        if knight_attacks(sq) & self.pieces(by, Piece::Knight) != 0 {
            return true;
        }
        if king_attacks(sq) & self.pieces(by, Piece::King) != 0 {
            return true;
        }
        let bishops = self.pieces(by, Piece::Bishop) | self.pieces(by, Piece::Queen);
        if bishop_attacks(sq, self.all) & bishops != 0 {
            return true;
        }
        let rooks = self.pieces(by, Piece::Rook) | self.pieces(by, Piece::Queen);
        if rook_attacks(sq, self.all) & rooks != 0 {
            return true;
        }
        false
    }

    #[inline]
    pub fn in_check(&self, c: Color) -> bool {
        let king = self.pieces(c, Piece::King);
        if king == 0 {
            return false; // king already gone (Atomic) — game is over, not "in check"
        }
        self.is_attacked(crate::bitboard::lsb(king), c.opp())
    }

    /// Like [`is_attacked`] but ignoring the enemy king (Atomic: kings can't
    /// capture, so an adjacent enemy king is not a threat).
    pub fn is_attacked_no_king(&self, sq: Square, by: Color) -> bool {
        if pawn_attacks(by.opp(), sq) & self.pieces(by, Piece::Pawn) != 0 {
            return true;
        }
        if knight_attacks(sq) & self.pieces(by, Piece::Knight) != 0 {
            return true;
        }
        let bishops = self.pieces(by, Piece::Bishop) | self.pieces(by, Piece::Queen);
        if bishop_attacks(sq, self.all) & bishops != 0 {
            return true;
        }
        let rooks = self.pieces(by, Piece::Rook) | self.pieces(by, Piece::Queen);
        if rook_attacks(sq, self.all) & rooks != 0 {
            return true;
        }
        false
    }

    /// Apply `mv`, returning state needed to [`unmake_move`](Self::unmake_move).
    pub fn make_move(&mut self, mv: Move) -> Undo {
        let z = zobrist();
        let us = self.side;
        let them = us.opp();
        let from = mv.from();
        let to = mv.to();
        let k = mv.kind();

        // Crazyhouse drop: `from` is the dropped piece's index, not a square, so
        // handle it before any board lookup of `from`.
        if k == kind::DROP {
            let piece = mv.dropped_piece();
            let undo = Undo {
                captured: None,
                captured_sq: to,
                prev_castling: self.castling,
                prev_ep: self.ep,
                prev_halfmove: self.halfmove,
                prev_hash: self.hash,
                prev_checks: self.checks,
                exploded: [None; 9],
                exploded_len: 0,
                prev_hand: self.hand,
                prev_promoted: self.promoted,
            };
            if let Some(epsq) = self.ep {
                self.hash ^= z.ep_file(file_of(epsq));
            }
            self.put_piece(us, piece, to);
            self.hand[us.index()][piece.index()] -= 1;
            self.ep = None;
            self.halfmove += 1;
            if us == Color::Black {
                self.fullmove += 1;
            }
            self.hash ^= hand_hash(undo.prev_hand) ^ hand_hash(self.hand);
            self.hash ^= z.side();
            self.side = them;
            return undo;
        }

        let (_, moving) = self.mailbox[from as usize].expect("move from empty square");

        // Determine capture (square differs for en passant).
        let (captured, captured_sq) = if k == kind::EP_CAPTURE {
            let cap_sq = if us == Color::White { to - 8 } else { to + 8 };
            (Some((them, Piece::Pawn)), cap_sq)
        } else if mv.is_capture() {
            (self.mailbox[to as usize], to)
        } else {
            (None, to)
        };

        let mut undo = Undo {
            captured,
            captured_sq,
            prev_castling: self.castling,
            prev_ep: self.ep,
            prev_halfmove: self.halfmove,
            prev_hash: self.hash,
            prev_checks: self.checks,
            exploded: [None; 9],
            exploded_len: 0,
            prev_hand: self.hand,
            prev_promoted: self.promoted,
        };

        // Remove old castling/ep contributions from the hash.
        self.hash ^= z.castle(self.castling.0);
        if let Some(epsq) = self.ep {
            self.hash ^= z.ep_file(file_of(epsq));
        }

        // Remove captured piece (castling never captures).
        if let Some((cc, cp)) = captured {
            self.remove_piece(cc, cp, captured_sq);
        }

        if k == kind::KING_CASTLE || k == kind::QUEEN_CASTLE {
            // Castling (standard + Chess960): king → g/c, rook → f/d. For 960 the
            // move is king-takes-rook (to = rook square); standard rook is on a/h.
            // Remove both first to handle 960 square overlaps cleanly.
            let kingside = k == kind::KING_CASTLE;
            let rank8 = if us == Color::White { 0u8 } else { 56u8 };
            let king_dest = rank8 + if kingside { 6 } else { 2 };
            let rook_dest = rank8 + if kingside { 5 } else { 3 };
            let rook_from = if self.variant == Variant::Chess960 {
                to
            } else {
                rank8 + if kingside { 7 } else { 0 }
            };
            self.remove_piece(us, Piece::King, from);
            self.remove_piece(us, Piece::Rook, rook_from);
            self.put_piece(us, Piece::King, king_dest);
            self.put_piece(us, Piece::Rook, rook_dest);
        } else {
            // Move our piece (handling promotion).
            self.remove_piece(us, moving, from);
            let placed = mv.promotion().unwrap_or(moving);
            self.put_piece(us, placed, to);

            // Atomic: a capture detonates — the capturing piece and every adjacent
            // NON-pawn piece (incl. kings). Pawns survive (only the captured one
            // is gone, removed above).
            if self.variant == Variant::Atomic && captured.is_some() {
                let mut blast = bit(to) | king_attacks(to);
                let mut idx = 0u8;
                while blast != 0 {
                    let sq = pop_lsb(&mut blast);
                    if let Some((cc, cp)) = self.mailbox[sq as usize] {
                        if sq == to || cp != Piece::Pawn {
                            undo.exploded[idx as usize] = Some((cc, cp, sq));
                            idx += 1;
                            self.remove_piece(cc, cp, sq);
                        }
                    }
                }
                undo.exploded_len = idx;
            }
        }

        // Crazyhouse/Bughouse: maintain the promoted-square mask (a promoted piece
        // reverts to a pawn when captured). In Crazyhouse the captured piece enters
        // OUR hand; in Bughouse the match layer routes it to the partner's board
        // instead (via add_to_hand), so the self-add is skipped here.
        if matches!(self.variant, Variant::Crazyhouse | Variant::Bughouse) {
            if self.variant == Variant::Crazyhouse {
                if let Some((_, cp)) = captured {
                    let gained = if undo.prev_promoted & bit(captured_sq) != 0 {
                        Piece::Pawn
                    } else {
                        cp
                    };
                    self.hand[us.index()][gained.index()] += 1;
                }
            }
            self.promoted &= !bit(captured_sq);
            let mover_promoted = self.promoted & bit(from) != 0;
            self.promoted &= !bit(from);
            if mv.is_promotion() || mover_promoted {
                self.promoted |= bit(to);
            }
        }

        // Update castling rights from touched squares.
        if self.variant == Variant::Chess960 {
            self.revoke_960_rights(us, from, to);
        } else {
            self.castling.0 &= CASTLE_MASK[from as usize] & CASTLE_MASK[to as usize];
        }

        // New en-passant target: only on a double pawn push AND only when an
        // enemy pawn can actually capture it (FIDE position-identity rule — keeps
        // the Zobrist hash correct for threefold and the FEN strict).
        self.ep = if k == kind::DOUBLE_PUSH {
            let ep_sq = (from + to) / 2;
            if pawn_attacks(us, ep_sq) & self.pieces(them, Piece::Pawn) != 0 {
                Some(ep_sq)
            } else {
                None
            }
        } else {
            None
        };

        // Halfmove clock.
        self.halfmove = if moving == Piece::Pawn || captured.is_some() {
            0
        } else {
            self.halfmove + 1
        };
        if us == Color::Black {
            self.fullmove += 1;
        }

        // Re-add new castling/ep contributions, flip side.
        self.hash ^= z.castle(self.castling.0);
        if let Some(epsq) = self.ep {
            self.hash ^= z.ep_file(file_of(epsq));
        }
        self.hash ^= z.side();
        self.side = them;

        // Three-check: count a delivered check (the opponent is now in check).
        if self.variant == Variant::ThreeCheck && self.in_check(them) {
            self.hash ^= check_hash(self.checks);
            self.checks[us.index()] += 1;
            self.hash ^= check_hash(self.checks);
        }

        // Crazyhouse/Bughouse: fold the (possibly grown) reserve into the hash.
        if matches!(self.variant, Variant::Crazyhouse | Variant::Bughouse) {
            self.hash ^= hand_hash(undo.prev_hand) ^ hand_hash(self.hand);
        }

        undo
    }

    /// Reverse a [`make_move`](Self::make_move).
    pub fn unmake_move(&mut self, mv: Move, undo: Undo) {
        let them = self.side;
        let us = them.opp();
        self.side = us;

        // Crazyhouse drop: lift the dropped piece, restore reserve + scalars.
        if mv.is_drop() {
            self.remove_piece(us, mv.dropped_piece(), mv.to());
            self.castling = undo.prev_castling;
            self.ep = undo.prev_ep;
            self.halfmove = undo.prev_halfmove;
            self.hash = undo.prev_hash;
            self.checks = undo.prev_checks;
            self.hand = undo.prev_hand;
            self.promoted = undo.prev_promoted;
            if us == Color::Black {
                self.fullmove -= 1;
            }
            return;
        }

        // Atomic: restore the pieces destroyed by the explosion first, so the
        // standard reversal below finds our capturing piece back on `to`.
        for i in 0..undo.exploded_len as usize {
            if let Some((cc, cp, sq)) = undo.exploded[i] {
                self.put_piece(cc, cp, sq);
            }
        }

        let from = mv.from();
        let to = mv.to();
        let k = mv.kind();

        if k == kind::KING_CASTLE || k == kind::QUEEN_CASTLE {
            // Reverse castling (standard + Chess960).
            let kingside = k == kind::KING_CASTLE;
            let rank8 = if us == Color::White { 0u8 } else { 56u8 };
            let king_dest = rank8 + if kingside { 6 } else { 2 };
            let rook_dest = rank8 + if kingside { 5 } else { 3 };
            let rook_from = if self.variant == Variant::Chess960 {
                to
            } else {
                rank8 + if kingside { 7 } else { 0 }
            };
            self.remove_piece(us, Piece::King, king_dest);
            self.remove_piece(us, Piece::Rook, rook_dest);
            self.put_piece(us, Piece::King, from);
            self.put_piece(us, Piece::Rook, rook_from);
        } else {
            // Reverse our piece move (undo promotion: original piece was a pawn).
            let placed = self.mailbox[to as usize].expect("to empty on unmake").1;
            let original = if mv.is_promotion() { Piece::Pawn } else { placed };
            self.remove_piece(us, placed, to);
            self.put_piece(us, original, from);
        }

        // Restore captured piece.
        if let Some((cc, cp)) = undo.captured {
            self.put_piece(cc, cp, undo.captured_sq);
        }

        // Restore scalar state (hash restored wholesale; intermediate xors discarded).
        self.castling = undo.prev_castling;
        self.ep = undo.prev_ep;
        self.halfmove = undo.prev_halfmove;
        self.hash = undo.prev_hash;
        self.checks = undo.prev_checks;
        self.hand = undo.prev_hand;
        self.promoted = undo.prev_promoted;
        if us == Color::Black {
            self.fullmove -= 1;
        }
    }

    /// Recompute the Zobrist hash from scratch (used to verify incremental updates).
    pub fn compute_hash(&self) -> u64 {
        let z = zobrist();
        let mut h = 0u64;
        for sq in 0..64u8 {
            if let Some((c, p)) = self.mailbox[sq as usize] {
                h ^= z.piece(c, p, sq);
            }
        }
        h ^= z.castle(self.castling.0);
        if let Some(epsq) = self.ep {
            h ^= z.ep_file(file_of(epsq));
        }
        if self.side == Color::Black {
            h ^= z.side();
        }
        h ^= check_hash(self.checks);
        h ^= hand_hash(self.hand);
        h
    }

    /// If a variant win condition is already met in this position, the winner.
    /// The losing side is always the side to move (the win was created by the
    /// previous move). `None` for Standard or an ongoing variant game.
    pub fn variant_terminal(&self) -> Option<Color> {
        match self.variant {
            Variant::ThreeCheck => {
                if self.checks[Color::White.index()] >= 3 {
                    Some(Color::White)
                } else if self.checks[Color::Black.index()] >= 3 {
                    Some(Color::Black)
                } else {
                    None
                }
            }
            Variant::KingOfTheHill => {
                for c in [Color::White, Color::Black] {
                    if HILL.contains(&self.king_sq(c)) {
                        return Some(c);
                    }
                }
                None
            }
            Variant::Atomic | Variant::FogOfWar => {
                // A king gone (blown up / captured) → that side has lost.
                if self.pieces(Color::White, Piece::King) == 0 {
                    Some(Color::Black)
                } else if self.pieces(Color::Black, Piece::King) == 0 {
                    Some(Color::White)
                } else {
                    None
                }
            }
            _ => None,
        }
    }

    /// Fog of War: the squares colour `viewer` can see — its own pieces plus
    /// every square any of its pieces attacks or can move to.
    pub fn visible_mask(&self, viewer: Color) -> Bitboard {
        let mut vis = self.occ[viewer.index()];

        let mut knights = self.pieces(viewer, Piece::Knight);
        while knights != 0 {
            vis |= knight_attacks(pop_lsb(&mut knights));
        }
        vis |= king_attacks(self.king_sq(viewer));

        let mut diag = self.pieces(viewer, Piece::Bishop) | self.pieces(viewer, Piece::Queen);
        while diag != 0 {
            vis |= bishop_attacks(pop_lsb(&mut diag), self.all);
        }
        let mut orth = self.pieces(viewer, Piece::Rook) | self.pieces(viewer, Piece::Queen);
        while orth != 0 {
            vis |= rook_attacks(pop_lsb(&mut orth), self.all);
        }

        let empty = !self.all;
        let (push, start_rank): (i16, u8) = if viewer == Color::White {
            (8, 1)
        } else {
            (-8, 6)
        };
        let mut pawns = self.pieces(viewer, Piece::Pawn);
        while pawns != 0 {
            let from = pop_lsb(&mut pawns);
            vis |= pawn_attacks(viewer, from); // diagonal sight
            let one = (from as i16 + push) as Square;
            if bit(one) & empty != 0 {
                vis |= bit(one);
                if (from >> 3) == start_rank {
                    let two = (from as i16 + 2 * push) as Square;
                    if bit(two) & empty != 0 {
                        vis |= bit(two);
                    }
                }
            }
        }
        vis
    }

    /// Crazyhouse/Bughouse: add a captured piece to colour `c`'s reserve, keeping
    /// the Zobrist hash consistent. Kings are never reserved. (Bughouse uses this
    /// to deliver a piece captured on the partner's board.)
    pub fn add_to_hand(&mut self, c: Color, p: Piece) {
        if p == Piece::King {
            return;
        }
        self.hash ^= hand_hash(self.hand);
        self.hand[c.index()][p.index()] += 1;
        self.hash ^= hand_hash(self.hand);
    }

    /// Inverse of [`add_to_hand`](Self::add_to_hand) (saturating at zero).
    pub fn take_from_hand(&mut self, c: Color, p: Piece) {
        if p == Piece::King || self.hand[c.index()][p.index()] == 0 {
            return;
        }
        self.hash ^= hand_hash(self.hand);
        self.hand[c.index()][p.index()] -= 1;
        self.hash ^= hand_hash(self.hand);
    }

    /// Chess960: revoke castling rights when the king leaves home or a castling
    /// rook leaves/is captured on its home square (the static mask is by fixed
    /// square, which doesn't fit varied 960 geometry).
    fn revoke_960_rights(&mut self, us: Color, from: Square, to: Square) {
        use crate::types::CastlingRights as CR;
        if from == self.castle_king_home[us.index()] {
            let mask = if us == Color::White {
                CR::WK | CR::WQ
            } else {
                CR::BK | CR::BQ
            };
            self.castling.0 &= !mask;
        }
        for c in [Color::White, Color::Black] {
            for side in 0..2 {
                let rsq = self.castle_rook_sq[c.index()][side];
                if from == rsq || to == rsq {
                    let bit = match (c, side) {
                        (Color::White, 0) => CR::WK,
                        (Color::White, _) => CR::WQ,
                        (Color::Black, 0) => CR::BK,
                        (Color::Black, _) => CR::BQ,
                    };
                    self.castling.0 &= !bit;
                }
            }
        }
    }

    /// Build a Chess960 (Fischer Random) start position from index `idx` (mod
    /// 960) using the Scharnagl numbering.
    pub fn chess960(idx: u16) -> Position {
        let mut files: [Option<Piece>; 8] = [None; 8];
        let mut n = idx % 960;

        files[[1usize, 3, 5, 7][(n % 4) as usize]] = Some(Piece::Bishop); // light
        n /= 4;
        files[[0usize, 2, 4, 6][(n % 4) as usize]] = Some(Piece::Bishop); // dark
        n /= 4;
        place_nth_empty(&mut files, (n % 6) as usize, Piece::Queen);
        n /= 6;

        // The remaining five files take a knights/rooks/king pattern; the king is
        // always between the two rooks (so castling is well-defined).
        const KRN: [[Piece; 5]; 10] = [
            [Piece::Knight, Piece::Knight, Piece::Rook, Piece::King, Piece::Rook],
            [Piece::Knight, Piece::Rook, Piece::Knight, Piece::King, Piece::Rook],
            [Piece::Knight, Piece::Rook, Piece::King, Piece::Knight, Piece::Rook],
            [Piece::Knight, Piece::Rook, Piece::King, Piece::Rook, Piece::Knight],
            [Piece::Rook, Piece::Knight, Piece::Knight, Piece::King, Piece::Rook],
            [Piece::Rook, Piece::Knight, Piece::King, Piece::Knight, Piece::Rook],
            [Piece::Rook, Piece::Knight, Piece::King, Piece::Rook, Piece::Knight],
            [Piece::Rook, Piece::King, Piece::Knight, Piece::Knight, Piece::Rook],
            [Piece::Rook, Piece::King, Piece::Knight, Piece::Rook, Piece::Knight],
            [Piece::Rook, Piece::King, Piece::Rook, Piece::Knight, Piece::Knight],
        ];
        let krn = KRN[(n % 10) as usize];
        let mut ki = 0;
        for f in 0..8 {
            if files[f].is_none() {
                files[f] = Some(krn[ki]);
                ki += 1;
            }
        }

        let mut pos = Position::empty();
        pos.variant = Variant::Chess960;
        for f in 0..8u8 {
            let p = files[f as usize].unwrap();
            pos.put_piece(Color::White, p, f);
            pos.put_piece(Color::Black, p, 56 + f);
            pos.put_piece(Color::White, Piece::Pawn, 8 + f);
            pos.put_piece(Color::Black, Piece::Pawn, 48 + f);
        }

        // The KRN fill above guarantees exactly one king and two rooks on the
        // back rank, so these lookups are invariants — `expect` documents them.
        let king_file = files
            .iter()
            .position(|p| *p == Some(Piece::King))
            .expect("chess960 back rank always has a king") as u8;
        let rooks: Vec<u8> = (0..8u8)
            .filter(|&f| files[f as usize] == Some(Piece::Rook))
            .collect();
        debug_assert_eq!(rooks.len(), 2, "chess960 back rank always has two rooks");
        let (qs, ks) = (rooks[0], rooks[1]); // left of king, right of king
        pos.castle_king_home = [king_file, 56 + king_file];
        pos.castle_rook_sq = [[ks, qs], [56 + ks, 56 + qs]];
        pos.castling = crate::types::CastlingRights(0b1111);
        pos.side = Color::White;

        // Finalise the hash (put_piece mixed in piece keys; side White, no ep).
        pos.hash ^= zobrist().castle(pos.castling.0);
        pos
    }
}

/// Place `p` on the `n`-th empty file (left to right).
fn place_nth_empty(files: &mut [Option<Piece>; 8], n: usize, p: Piece) {
    let mut count = 0;
    for f in 0..8 {
        if files[f].is_none() {
            if count == n {
                files[f] = Some(p);
                return;
            }
            count += 1;
        }
    }
}
