//! Legal move generation.
//!
//! Strategy (correctness-first per the build plan): generate pseudo-legal moves,
//! then filter out any that leave the mover's own king in check by making the
//! move, testing king safety, and unmaking. This naturally handles pins,
//! discovered checks, double checks and the en-passant discovered-check edge
//! case. Castling transit-square safety is checked during generation.

use crate::attacks::{
    bishop_attacks, king_attacks, knight_attacks, pawn_attacks, rook_attacks,
};
use crate::bitboard::{bit, pop_lsb, Bitboard};
use crate::position::Position;
use crate::types::{kind, rank_of, Color, Move, MoveList, Piece, Square};

impl Position {
    /// Generate fully legal moves for the side to move.
    pub fn generate_legal(&mut self) -> MoveList {
        if self.variant == crate::types::Variant::Atomic {
            return self.generate_legal_atomic();
        }
        if self.variant == crate::types::Variant::FogOfWar {
            // No check concept — moves are pseudo-legal (you may move "into check"
            // and capturing the enemy king is the winning move).
            let mut pseudo = MoveList::new();
            self.generate_pseudo(&mut pseudo);
            return pseudo;
        }
        let mut pseudo = MoveList::new();
        self.generate_pseudo(&mut pseudo);
        let mut legal = MoveList::new();
        let us = self.side;
        for i in 0..pseudo.len() {
            let mv = pseudo[i];
            let u = self.make_move(mv);
            if !self.is_attacked(self.king_sq(us), us.opp()) {
                legal.push(mv);
            }
            self.unmake_move(mv, u);
        }
        legal
    }

    /// Atomic legal moves: the king may not capture; a move may not blow up your
    /// own king; exploding the enemy king wins (so it is legal even into check);
    /// otherwise your king must be safe, ignoring the (non-capturing) enemy king.
    fn generate_legal_atomic(&mut self) -> MoveList {
        let mut pseudo = MoveList::new();
        self.generate_pseudo(&mut pseudo);
        let mut legal = MoveList::new();
        let us = self.side;
        let them = us.opp();
        let ksq = self.king_sq(us);
        for i in 0..pseudo.len() {
            let mv = pseudo[i];
            if mv.from() == ksq && mv.is_capture() {
                continue; // a king capture would explode the king itself
            }
            let u = self.make_move(mv);
            let our_king = self.pieces(us, Piece::King);
            let their_king = self.pieces(them, Piece::King);
            let ok = if our_king == 0 {
                false // detonated our own king
            } else if their_king == 0 {
                true // detonated the enemy king → win
            } else {
                !self.is_attacked_no_king(crate::bitboard::lsb(our_king), them)
            };
            self.unmake_move(mv, u);
            if ok {
                legal.push(mv);
            }
        }
        legal
    }

    /// Generate pseudo-legal moves (may leave own king in check).
    pub fn generate_pseudo(&self, list: &mut MoveList) {
        let us = self.side;
        self.gen_pawns(us, list);
        self.gen_pieces(us, list);
        self.gen_castling(us, list);
        if matches!(
            self.variant,
            crate::types::Variant::Crazyhouse | crate::types::Variant::Bughouse
        ) {
            self.gen_drops(us, list);
        }
    }

    /// Crazyhouse: drop each reserve piece onto any empty square (pawns may not
    /// land on the back ranks).
    fn gen_drops(&self, us: Color, list: &mut MoveList) {
        const RANK_1: Bitboard = 0xFF;
        const RANK_8: Bitboard = 0xFFu64 << 56;
        let empty = !self.all;
        for pi in 0..5u8 {
            if self.hand[us.index()][pi as usize] == 0 {
                continue;
            }
            let mut targets = if pi == Piece::Pawn.index() as u8 {
                empty & !(RANK_1 | RANK_8)
            } else {
                empty
            };
            while targets != 0 {
                list.push(Move::new(pi, pop_lsb(&mut targets), kind::DROP));
            }
        }
    }

    fn gen_pawns(&self, us: Color, list: &mut MoveList) {
        let them = us.opp();
        let enemy = self.occ[them.index()];
        let empty = !self.all;
        let (push, start_rank, promo_rank): (i16, u8, u8) = match us {
            Color::White => (8, 1, 7),
            Color::Black => (-8, 6, 0),
        };

        let mut bb = self.pieces(us, Piece::Pawn);
        while bb != 0 {
            let from = pop_lsb(&mut bb);
            let one = (from as i16 + push) as Square;

            if bit(one) & empty != 0 {
                if rank_of(one) == promo_rank {
                    push_promotions(list, from, one, false);
                } else {
                    list.push(Move::new(from, one, kind::QUIET));
                    if rank_of(from) == start_rank {
                        let two = (from as i16 + 2 * push) as Square;
                        if bit(two) & empty != 0 {
                            list.push(Move::new(from, two, kind::DOUBLE_PUSH));
                        }
                    }
                }
            }

            let mut caps = pawn_attacks(us, from) & enemy;
            while caps != 0 {
                let to = pop_lsb(&mut caps);
                if rank_of(to) == promo_rank {
                    push_promotions(list, from, to, true);
                } else {
                    list.push(Move::new(from, to, kind::CAPTURE));
                }
            }

            if let Some(epsq) = self.ep {
                if pawn_attacks(us, from) & bit(epsq) != 0 {
                    list.push(Move::new(from, epsq, kind::EP_CAPTURE));
                }
            }
        }
    }

    fn gen_pieces(&self, us: Color, list: &mut MoveList) {
        let own = self.occ[us.index()];
        let enemy = self.occ[us.opp().index()];

        let mut knights = self.pieces(us, Piece::Knight);
        while knights != 0 {
            let from = pop_lsb(&mut knights);
            emit(list, from, knight_attacks(from) & !own, enemy);
        }
        let mut bishops = self.pieces(us, Piece::Bishop);
        while bishops != 0 {
            let from = pop_lsb(&mut bishops);
            emit(list, from, bishop_attacks(from, self.all) & !own, enemy);
        }
        let mut rooks = self.pieces(us, Piece::Rook);
        while rooks != 0 {
            let from = pop_lsb(&mut rooks);
            emit(list, from, rook_attacks(from, self.all) & !own, enemy);
        }
        let mut queens = self.pieces(us, Piece::Queen);
        while queens != 0 {
            let from = pop_lsb(&mut queens);
            let att = (bishop_attacks(from, self.all) | rook_attacks(from, self.all)) & !own;
            emit(list, from, att, enemy);
        }
        // The king may be gone after a capture (Fog of War / Atomic).
        let king_bb = self.pieces(us, Piece::King);
        if king_bb != 0 {
            let ksq = crate::bitboard::lsb(king_bb);
            emit(list, ksq, king_attacks(ksq) & !own, enemy);
        }
    }

    fn gen_castling(&self, us: Color, list: &mut MoveList) {
        let them = us.opp();
        // The king may be gone after a capture (Fog of War / Atomic): no castling,
        // and avoid an out-of-bounds king lookup.
        if self.pieces(us, Piece::King) == 0 {
            return;
        }
        // Can't castle out of check.
        if self.is_attacked(self.king_sq(us), them) {
            return;
        }
        if self.variant == crate::types::Variant::Chess960 {
            self.gen_castling_960(us, them, list);
            return;
        }
        match us {
            Color::White => {
                // Kingside: f1,g1 empty; f1,g1 not attacked.
                if self.castling.has(crate::types::CastlingRights::WK)
                    && self.all & (bit(5) | bit(6)) == 0
                    && !self.is_attacked(5, them)
                    && !self.is_attacked(6, them)
                {
                    list.push(Move::new(4, 6, kind::KING_CASTLE));
                }
                // Queenside: b1,c1,d1 empty; d1,c1 not attacked.
                if self.castling.has(crate::types::CastlingRights::WQ)
                    && self.all & (bit(1) | bit(2) | bit(3)) == 0
                    && !self.is_attacked(3, them)
                    && !self.is_attacked(2, them)
                {
                    list.push(Move::new(4, 2, kind::QUEEN_CASTLE));
                }
            }
            Color::Black => {
                if self.castling.has(crate::types::CastlingRights::BK)
                    && self.all & (bit(61) | bit(62)) == 0
                    && !self.is_attacked(61, them)
                    && !self.is_attacked(62, them)
                {
                    list.push(Move::new(60, 62, kind::KING_CASTLE));
                }
                if self.castling.has(crate::types::CastlingRights::BQ)
                    && self.all & (bit(57) | bit(58) | bit(59)) == 0
                    && !self.is_attacked(59, them)
                    && !self.is_attacked(58, them)
                {
                    list.push(Move::new(60, 58, kind::QUEEN_CASTLE));
                }
            }
        }
    }

    /// Chess960 castling: king → g/c, rook → f/d, encoded as king-takes-rook
    /// (to = the castling rook's square), so it is unambiguous from from/to.
    fn gen_castling_960(&self, us: Color, them: Color, list: &mut MoveList) {
        use crate::types::CastlingRights as CR;
        let rank8 = if us == Color::White { 0u8 } else { 56u8 };
        let king_from = self.king_sq(us);
        let rights = if us == Color::White {
            [(CR::WK, true), (CR::WQ, false)]
        } else {
            [(CR::BK, true), (CR::BQ, false)]
        };
        for (right, kingside) in rights {
            if !self.castling.has(right) {
                continue;
            }
            let rook_from = self.castle_rook_sq[us.index()][if kingside { 0 } else { 1 }];
            let king_dest = rank8 + if kingside { 6 } else { 2 };
            let rook_dest = rank8 + if kingside { 5 } else { 3 };
            // Every square in the king's and rook's paths must be empty, except
            // where the king and the castling rook currently stand.
            let occ = self.all & !bit(king_from) & !bit(rook_from);
            let paths =
                rank_segment(king_from, king_dest) | rank_segment(rook_from, rook_dest);
            if paths & occ != 0 {
                continue;
            }
            // The king must not pass through (or land on) an attacked square.
            let mut kp = rank_segment(king_from, king_dest);
            let mut safe = true;
            while kp != 0 {
                if self.is_attacked(pop_lsb(&mut kp), them) {
                    safe = false;
                    break;
                }
            }
            if !safe {
                continue;
            }
            let k = if kingside { kind::KING_CASTLE } else { kind::QUEEN_CASTLE };
            list.push(Move::new(king_from, rook_from, k));
        }
    }
}

/// Bitboard of squares from `a` to `b` inclusive along their shared rank.
#[inline]
fn rank_segment(a: Square, b: Square) -> Bitboard {
    let (lo, hi) = if a <= b { (a, b) } else { (b, a) };
    let mut bb = 0u64;
    let mut s = lo;
    while s <= hi {
        bb |= 1u64 << s;
        s += 1;
    }
    bb
}

#[inline]
fn emit(list: &mut MoveList, from: Square, targets: Bitboard, enemy: Bitboard) {
    let mut t = targets;
    while t != 0 {
        let to = pop_lsb(&mut t);
        let k = if bit(to) & enemy != 0 {
            kind::CAPTURE
        } else {
            kind::QUIET
        };
        list.push(Move::new(from, to, k));
    }
}

#[inline]
fn push_promotions(list: &mut MoveList, from: Square, to: Square, capture: bool) {
    let base = if capture {
        kind::KNIGHT_PROMO_CAP
    } else {
        kind::KNIGHT_PROMO
    };
    // knight, bishop, rook, queen
    for off in 0..4 {
        list.push(Move::new(from, to, base + off));
    }
}
