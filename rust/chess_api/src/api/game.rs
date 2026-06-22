//! Bridge-facing game API. Holds a `chess_core::Game` plus an authoritative
//! `Clock` as an opaque handle the Flutter side drives; all chess + clock logic
//! stays in the pure core. The UI renders the [`GameView`] this returns and
//! forwards user intent (square taps/drags) and elapsed time (`tick`).

use chess_core::attacks::{
    bishop_attacks, king_attacks, knight_attacks, pawn_attacks, queen_attacks, rook_attacks,
};
use chess_core::bitboard::{pop_lsb, Bitboard};
use chess_core::types::rank_of;
use chess_core::{Clock, Color, Game, GameStatus, Move, Piece, Position, TimeControl, Variant};
use flutter_rust_bridge::frb;

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum PieceColor {
    White,
    Black,
}

/// Game variant exposed to Flutter.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum GameVariant {
    Standard,
    ThreeCheck,
    KingOfTheHill,
    Chess960,
    Atomic,
    Crazyhouse,
    Bughouse,
    FogOfWar,
}

pub(crate) fn to_variant(v: GameVariant) -> Variant {
    match v {
        GameVariant::Standard => Variant::Standard,
        GameVariant::ThreeCheck => Variant::ThreeCheck,
        GameVariant::KingOfTheHill => Variant::KingOfTheHill,
        GameVariant::Chess960 => Variant::Chess960,
        GameVariant::Atomic => Variant::Atomic,
        GameVariant::Crazyhouse => Variant::Crazyhouse,
        GameVariant::Bughouse => Variant::Bughouse,
        GameVariant::FogOfWar => Variant::FogOfWar,
    }
}

fn from_variant(v: Variant) -> GameVariant {
    match v {
        Variant::Standard => GameVariant::Standard,
        Variant::ThreeCheck => GameVariant::ThreeCheck,
        Variant::KingOfTheHill => GameVariant::KingOfTheHill,
        Variant::Chess960 => GameVariant::Chess960,
        Variant::Atomic => GameVariant::Atomic,
        Variant::Crazyhouse => GameVariant::Crazyhouse,
        Variant::Bughouse => GameVariant::Bughouse,
        Variant::FogOfWar => GameVariant::FogOfWar,
    }
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum PieceKind {
    Pawn,
    Knight,
    Bishop,
    Rook,
    Queen,
    King,
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct SquarePiece {
    pub color: PieceColor,
    pub kind: PieceKind,
}

/// Result of attempting a move from one square to another.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum MoveOutcome {
    Played,
    /// from→to is a legal pawn move to the last rank; the UI must pick a piece
    /// and call `play` again with `promotion` set.
    NeedsPromotion,
    Illegal,
}

/// Flattened (payload-free, so no `freezed` dependency is needed on Dart).
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum GameOutcome {
    Ongoing,
    WhiteWins,
    BlackWins,
    WhiteWinsOnTime,
    BlackWinsOnTime,
    Stalemate,
    DrawFiftyMove,
    DrawThreefold,
    DrawInsufficientMaterial,
}

/// Lightweight clock-only snapshot, polled at high frequency by the clock UI so
/// the board does not rebuild on every tick.
#[derive(Clone, Copy, Debug)]
pub struct ClockSnapshot {
    pub infinite: bool,
    pub white_ms: i64,
    pub black_ms: i64,
    pub running: PieceColor,
    pub over: bool,
}

/// A complete snapshot for rendering. Board index 0 = a1, 63 = h8.
#[derive(Clone, Debug)]
pub struct GameView {
    pub board: Vec<Option<SquarePiece>>,
    pub side_to_move: PieceColor,
    pub in_check: bool,
    pub status: GameOutcome,
    pub last_from: Option<u32>,
    pub last_to: Option<u32>,
    pub san_moves: Vec<String>,
    pub captured_by_white: Vec<PieceKind>,
    pub captured_by_black: Vec<PieceKind>,
    pub halfmove: u32,
    pub fullmove: u32,
    pub fen: String,
    /// Active variant + Three-check counters (0 for other variants).
    pub variant: GameVariant,
    pub white_checks: u32,
    pub black_checks: u32,
    /// The last move was an Atomic explosion (drive the blast animation).
    pub last_explosion: bool,
    /// Crazyhouse reserve counts [Pawn,Knight,Bishop,Rook,Queen] per colour, and
    /// the promoted-square mask (for the AI). Empty/0 for other variants.
    pub white_hand: Vec<u32>,
    pub black_hand: Vec<u32>,
    pub promoted: u64,
    // Clock state (authoritative). `clock_infinite` true → no clock.
    pub clock_infinite: bool,
    pub clock_white_ms: i64,
    pub clock_black_ms: i64,
    pub clock_running: PieceColor,
}

/// Opaque game session held by Dart.
#[frb(opaque)]
pub struct ChessGame {
    game: Game,
    san_history: Vec<String>,
    uci_history: Vec<String>,
    moves: Vec<(u32, u32)>,
    clock: Clock,
    clock_undo: Vec<Clock>,
    clock_start: Clock,
    timeout: Option<Color>,
    status: GameStatus,
    /// Whether the most recently applied move was an Atomic explosion (for the
    /// UI's blast animation). Reset on undo.
    last_explosion: bool,
    /// Bughouse: the piece the most recent move made available to pass to the
    /// partner (already demoted to Pawn if it was a promoted piece). None if the
    /// move captured nothing. Reset on undo.
    last_passable: Option<PieceKind>,
}

impl ChessGame {
    /// New game with no clock.
    #[frb(sync)]
    pub fn new_game() -> ChessGame {
        ChessGame::with_clock(Game::new(), Clock::new(TimeControl::Infinite))
    }

    /// New game with a Fischer time control (`base_minutes` + `increment_seconds`).
    #[frb(sync)]
    pub fn new_timed(base_minutes: u32, increment_seconds: u32) -> ChessGame {
        let increment_ms = increment_seconds as u64 * 1_000;
        let mut base_ms = base_minutes as u64 * 60_000;
        if base_ms == 0 {
            // A zero base flags instantly; start with the increment so "0+n"
            // is playable. ("0+0" is blocked by the setup UI.)
            base_ms = increment_ms;
        }
        let tc = TimeControl::Fischer { base_ms, increment_ms };
        ChessGame::with_clock(Game::new(), Clock::new(tc))
    }

    /// New game of `variant`. Standard start position, except Chess960 which is
    /// built from `chess960_index` (mod 960). `base_minutes`/`increment_seconds`
    /// of 0/0 means no clock.
    #[frb(sync)]
    pub fn new_variant(
        variant: GameVariant,
        base_minutes: u32,
        increment_seconds: u32,
        chess960_index: u32,
    ) -> ChessGame {
        let mut game = if variant == GameVariant::Chess960 {
            Game::from_position(Position::chess960(chess960_index as u16))
        } else {
            Game::new()
        };
        game.pos.variant = to_variant(variant);
        let clock = if base_minutes == 0 && increment_seconds == 0 {
            Clock::new(TimeControl::Infinite)
        } else {
            let increment_ms = increment_seconds as u64 * 1_000;
            let mut base_ms = base_minutes as u64 * 60_000;
            if base_ms == 0 {
                base_ms = increment_ms;
            }
            Clock::new(TimeControl::Fischer { base_ms, increment_ms })
        };
        ChessGame::with_clock(game, clock)
    }

    #[frb(sync)]
    pub fn from_fen(fen: String) -> Result<ChessGame, String> {
        let game = Game::from_fen(&fen).map_err(|e| e.to_string())?;
        Ok(ChessGame::with_clock(game, Clock::new(TimeControl::Infinite)))
    }

    fn with_clock(mut game: Game, clock: Clock) -> ChessGame {
        let status = game.status();
        ChessGame {
            game,
            san_history: Vec::new(),
            uci_history: Vec::new(),
            moves: Vec::new(),
            clock,
            clock_undo: Vec::new(),
            clock_start: clock,
            timeout: None,
            status,
            last_explosion: false,
            last_passable: None,
        }
    }

    #[inline]
    fn is_over(&self) -> bool {
        self.status != GameStatus::Ongoing || self.timeout.is_some()
    }

    /// Destination squares of every legal move starting from `from` (for hints).
    #[frb(sync)]
    pub fn legal_targets(&mut self, from: u32) -> Vec<u32> {
        if self.is_over() {
            return Vec::new();
        }
        let from = from as u8;
        let list = self.game.pos.generate_legal();
        let mut out = Vec::new();
        for i in 0..list.len() {
            let m = list[i];
            if m.from() == from && !out.contains(&(m.to() as u32)) {
                out.push(m.to() as u32);
            }
        }
        out
    }

    /// Geometric destination squares for the piece on `from`, ignoring whose
    /// turn it is (for premove candidate highlighting). Approximate: validity is
    /// re-checked when the premove is actually executed.
    #[frb(sync)]
    pub fn premove_targets(&self, from: u32) -> Vec<u32> {
        premove_targets_on(&self.game.pos, from as u8)
    }

    /// Premove targets for `from` AFTER the queued premoves are applied as raw
    /// relocations (flattened from,to pairs: [f0,t0,f1,t1,…]). Lets a premove
    /// *chain* target the board the earlier premoves would produce. Each
    /// premove's real legality is still re-checked when it executes.
    #[frb(sync)]
    pub fn premove_targets_after(&self, premoves: Vec<u32>, from: u32) -> Vec<u32> {
        let mut pos = self.game.pos.clone();
        let mut i = 0;
        while i + 1 < premoves.len() {
            relocate(&mut pos, premoves[i] as u8, premoves[i + 1] as u8);
            i += 2;
        }
        premove_targets_on(&pos, from as u8)
    }

    /// Try to play from→to (with optional promotion piece).
    #[frb(sync)]
    pub fn play(&mut self, from: u32, to: u32, promotion: Option<PieceKind>) -> MoveOutcome {
        if self.is_over() {
            return MoveOutcome::Illegal;
        }
        let (from, to) = (from as u8, to as u8);
        let list = self.game.pos.generate_legal();
        let mut chosen = None;
        let mut needs_promo = false;
        for i in 0..list.len() {
            let m = list[i];
            if m.from() == from && m.to() == to {
                match (m.promotion(), promotion) {
                    (Some(p), Some(req)) if p == from_kind(req) => {
                        chosen = Some(m);
                        break;
                    }
                    (Some(_), None) => needs_promo = true,
                    (None, _) => {
                        chosen = Some(m);
                        break;
                    }
                    _ => {}
                }
            }
        }
        match chosen {
            Some(m) => {
                self.apply(m);
                MoveOutcome::Played
            }
            None if needs_promo => MoveOutcome::NeedsPromotion,
            None => MoveOutcome::Illegal,
        }
    }

    /// Apply a move given in UCI/coordinate form (e.g. `e2e4`, `e7e8q`), used
    /// to apply the AI's chosen move. Returns false if illegal/over.
    #[frb(sync)]
    pub fn play_uci(&mut self, uci: String) -> bool {
        if self.is_over() {
            return false;
        }
        match self.game.pos.parse_uci(&uci) {
            Ok(m) => {
                self.apply(m);
                true
            }
            Err(_) => false,
        }
    }

    /// Crazyhouse: legal squares to drop the reserve piece `piece` (0=Pawn ..
    /// 4=Queen) onto.
    #[frb(sync)]
    pub fn drop_targets(&mut self, piece: u32) -> Vec<u32> {
        if self.is_over() {
            return Vec::new();
        }
        let list = self.game.pos.generate_legal();
        let mut out = Vec::new();
        for i in 0..list.len() {
            let m = list[i];
            if m.is_drop() && m.dropped_piece().index() == piece as usize {
                out.push(m.to() as u32);
            }
        }
        out
    }

    /// Crazyhouse: drop reserve `piece` (0=Pawn .. 4=Queen) onto square `to`.
    #[frb(sync)]
    pub fn play_drop(&mut self, piece: u32, to: u32) -> MoveOutcome {
        if self.is_over() {
            return MoveOutcome::Illegal;
        }
        let (piece, to) = (piece as usize, to as u8);
        let list = self.game.pos.generate_legal();
        for i in 0..list.len() {
            let m = list[i];
            if m.is_drop() && m.dropped_piece().index() == piece && m.to() == to {
                self.apply(m);
                return MoveOutcome::Played;
            }
        }
        MoveOutcome::Illegal
    }

    /// Bughouse: the piece the last applied move made available to pass to the
    /// partner (already demoted to a pawn if it was a promoted piece).
    #[frb(sync)]
    pub fn last_passable_capture(&self) -> Option<PieceKind> {
        self.last_passable
    }

    /// Bughouse: receive a piece passed from the partner's board into `color`'s
    /// reserve. Refreshes status (a fed piece can create a drop-mate escape).
    #[frb(sync)]
    pub fn give_to_hand(&mut self, color: PieceColor, piece: PieceKind) {
        self.game.pos.add_to_hand(from_color(color), from_kind(piece));
        self.status = self.game.status();
    }

    /// Fog of War: the squares `viewer` can see (own pieces + observed squares).
    #[frb(sync)]
    pub fn visible_squares(&self, viewer: PieceColor) -> Vec<u32> {
        let mut bb = self.game.pos.visible_mask(from_color(viewer));
        let mut out = Vec::new();
        while bb != 0 {
            out.push(bb.trailing_zeros());
            bb &= bb - 1;
        }
        out
    }

    /// Record + apply a legal move, updating clock and cached status.
    fn apply(&mut self, m: Move) {
        let mover = self.game.pos.side;
        self.last_explosion =
            self.game.pos.variant == Variant::Atomic && m.is_capture();
        // Bughouse: which piece this move makes available to pass to the partner
        // (computed before the move; a promoted piece is demoted to a pawn).
        self.last_passable = passable_capture(&self.game.pos, m);
        let san = self.game.pos.san_of(m);
        self.san_history.push(san);
        self.uci_history.push(m.to_uci());
        // A drop has no source square; highlight the drop square itself.
        let hl_from = if m.is_drop() { m.to() } else { m.from() };
        self.moves.push((hl_from as u32, m.to() as u32));
        self.clock_undo.push(self.clock);
        self.game.make_move(m);
        self.clock.on_move(mover);
        self.status = self.game.status();
    }

    /// Advance the running side's clock by `elapsed_ms`. Latches a timeout when
    /// the side to move flags.
    #[frb(sync)]
    pub fn tick(&mut self, elapsed_ms: u32) {
        if self.is_over() || self.clock.is_infinite() {
            return;
        }
        if self.clock.elapse(elapsed_ms as i64) {
            self.timeout = Some(self.clock.running());
        }
    }

    /// Position-hash history (for the AI's repetition avoidance).
    #[frb(sync)]
    pub fn hash_history(&self) -> Vec<u64> {
        self.game.hash_history()
    }

    /// Reconcile the clock from a LAN peer's move message.
    #[frb(sync)]
    pub fn set_clock_ms(&mut self, white_ms: i64, black_ms: i64) {
        self.clock.set(white_ms, black_ms);
    }

    /// The moves played so far in UCI form (for saving a game).
    #[frb(sync)]
    pub fn move_history_uci(&self) -> Vec<String> {
        self.uci_history.clone()
    }

    /// Cheap clock-only snapshot (no board build).
    #[frb(sync)]
    pub fn clock_snapshot(&self) -> ClockSnapshot {
        ClockSnapshot {
            infinite: self.clock.is_infinite(),
            white_ms: self.clock.remaining(Color::White),
            black_ms: self.clock.remaining(Color::Black),
            running: to_color(self.clock.running()),
            over: self.is_over(),
        }
    }

    /// Take back the last move (and restore the clock).
    #[frb(sync)]
    pub fn undo(&mut self) -> bool {
        self.last_explosion = false; // don't replay a blast on takeback
        self.last_passable = None;
        if self.game.undo() {
            self.san_history.pop();
            self.uci_history.pop();
            self.moves.pop();
            if let Some(c) = self.clock_undo.pop() {
                self.clock = c;
            }
            self.timeout = None;
            self.status = self.game.status();
            true
        } else if self.timeout.is_some() {
            // Recover from a timeout latched before any move was made.
            self.clock = self.clock_start;
            self.timeout = None;
            self.status = self.game.status();
            true
        } else {
            false
        }
    }

    #[frb(sync)]
    pub fn view(&mut self) -> GameView {
        let pos = &self.game.pos;
        let mut board = Vec::with_capacity(64);
        for sq in 0..64u8 {
            board.push(pos.piece_at(sq).map(|(c, p)| SquarePiece {
                color: to_color(c),
                kind: to_kind(p),
            }));
        }
        let (last_from, last_to) = match self.moves.last() {
            Some(&(f, t)) => (Some(f), Some(t)),
            None => (None, None),
        };
        let side = pos.side;
        let in_check = pos.in_check(side);
        let (cap_w, cap_b) = captured(pos);

        let outcome = match self.timeout {
            Some(flagger) => {
                if insufficient_to_mate(pos, flagger.opp()) {
                    GameOutcome::DrawInsufficientMaterial
                } else if flagger == Color::White {
                    GameOutcome::BlackWinsOnTime
                } else {
                    GameOutcome::WhiteWinsOnTime
                }
            }
            None => to_outcome(self.status),
        };

        GameView {
            board,
            side_to_move: to_color(side),
            in_check,
            status: outcome,
            last_from,
            last_to,
            san_moves: self.san_history.clone(),
            captured_by_white: cap_w,
            captured_by_black: cap_b,
            halfmove: self.game.pos.halfmove as u32,
            fullmove: self.game.pos.fullmove,
            fen: chess_core::to_fen(&self.game.pos),
            variant: from_variant(self.game.pos.variant),
            white_checks: self.game.pos.checks[0] as u32,
            black_checks: self.game.pos.checks[1] as u32,
            last_explosion: self.last_explosion,
            white_hand: self.game.pos.hand[0].iter().map(|&n| n as u32).collect(),
            black_hand: self.game.pos.hand[1].iter().map(|&n| n as u32).collect(),
            promoted: self.game.pos.promoted,
            clock_infinite: self.clock.is_infinite(),
            clock_white_ms: self.clock.remaining(Color::White),
            clock_black_ms: self.clock.remaining(Color::Black),
            clock_running: to_color(self.clock.running()),
        }
    }
}

/// Geometric pawn premove squares: both capture diagonals + single/double push.
/// Geometric premove destinations for the piece on `from` in `pos`, ignoring
/// whose turn it is. Includes the castling king-destinations (g/c file on the
/// king's home rank) when the side still holds the right, so castling can be
/// premoved. All targets are re-validated when the premove actually executes.
fn premove_targets_on(pos: &Position, from: u8) -> Vec<u32> {
    let Some((color, piece)) = pos.piece_at(from) else {
        return Vec::new();
    };
    let mut bb = match piece {
        Piece::Knight => knight_attacks(from),
        Piece::Bishop => bishop_attacks(from, pos.all),
        Piece::Rook => rook_attacks(from, pos.all),
        Piece::Queen => queen_attacks(from, pos.all),
        Piece::King => king_attacks(from),
        Piece::Pawn => pawn_premove(color, from),
    } & !pos.occ[color.index()];
    let mut out = Vec::new();
    while bb != 0 {
        out.push(pop_lsb(&mut bb) as u32);
    }
    if piece == Piece::King && from == pos.castle_king_home[color.index()] {
        use chess_core::types::CastlingRights as CR;
        // Standard castling is encoded king → g/c file; Chess960 as king-takes-
        // rook (target = the rook's home square), so offer the right one.
        let is960 = pos.variant == Variant::Chess960;
        let rank8 = (from / 8) * 8;
        let ci = color.index();
        let (kr, qr) = match color {
            Color::White => (CR::WK, CR::WQ),
            Color::Black => (CR::BK, CR::BQ),
        };
        let mut offer = |has: bool, dest: u8, out: &mut Vec<u32>| {
            if has && !out.contains(&(dest as u32)) {
                out.push(dest as u32);
            }
        };
        offer(
            pos.castling.has(kr),
            if is960 { pos.castle_rook_sq[ci][0] } else { rank8 + 6 },
            &mut out,
        );
        offer(
            pos.castling.has(qr),
            if is960 { pos.castle_rook_sq[ci][1] } else { rank8 + 2 },
            &mut out,
        );
    }
    out
}

/// Raw piece relocation (no legality / turn / castle-rook / en-passant / promo
/// handling) — used only to build a premove-preview board for chained premoves.
fn relocate(pos: &mut Position, from: u8, to: u8) {
    if let Some((c, p)) = pos.piece_at(from) {
        if let Some((cc, pp)) = pos.piece_at(to) {
            pos.remove_piece(cc, pp, to);
        }
        pos.remove_piece(c, p, from);
        pos.put_piece(c, p, to);
    }
}

fn pawn_premove(color: Color, from: u8) -> Bitboard {
    let mut m = pawn_attacks(color, from);
    let rank = rank_of(from);
    match color {
        Color::White => {
            m |= 1u64 << (from + 8);
            if rank == 1 {
                m |= 1u64 << (from + 16);
            }
        }
        Color::Black => {
            m |= 1u64 << (from - 8);
            if rank == 6 {
                m |= 1u64 << (from - 16);
            }
        }
    }
    m
}

fn to_color(c: Color) -> PieceColor {
    match c {
        Color::White => PieceColor::White,
        Color::Black => PieceColor::Black,
    }
}

fn from_color(c: PieceColor) -> Color {
    match c {
        PieceColor::White => Color::White,
        PieceColor::Black => Color::Black,
    }
}

/// Bughouse: the piece a move makes available to pass to the partner — the piece
/// it captures, demoted to a pawn if that piece was promoted. Computed against
/// the pre-move position (side to move = the mover). None if no capture.
fn passable_capture(pos: &Position, m: Move) -> Option<PieceKind> {
    if m.is_drop() {
        return None;
    }
    let cap_sq = if m.is_ep() {
        if pos.side == Color::White {
            m.to() - 8
        } else {
            m.to() + 8
        }
    } else if m.is_capture() {
        m.to()
    } else {
        return None;
    };
    let (_, cp) = pos.piece_at(cap_sq)?;
    let demoted = if pos.promoted & (1u64 << cap_sq) != 0 {
        Piece::Pawn
    } else {
        cp
    };
    Some(to_kind(demoted))
}

fn to_kind(p: Piece) -> PieceKind {
    match p {
        Piece::Pawn => PieceKind::Pawn,
        Piece::Knight => PieceKind::Knight,
        Piece::Bishop => PieceKind::Bishop,
        Piece::Rook => PieceKind::Rook,
        Piece::Queen => PieceKind::Queen,
        Piece::King => PieceKind::King,
    }
}

fn from_kind(k: PieceKind) -> Piece {
    match k {
        PieceKind::Pawn => Piece::Pawn,
        PieceKind::Knight => Piece::Knight,
        PieceKind::Bishop => Piece::Bishop,
        PieceKind::Rook => Piece::Rook,
        PieceKind::Queen => Piece::Queen,
        PieceKind::King => Piece::King,
    }
}

fn to_outcome(s: GameStatus) -> GameOutcome {
    match s {
        GameStatus::Ongoing => GameOutcome::Ongoing,
        GameStatus::Checkmate { winner: Color::White } => GameOutcome::WhiteWins,
        GameStatus::Checkmate { winner: Color::Black } => GameOutcome::BlackWins,
        GameStatus::VariantWin { winner: Color::White } => GameOutcome::WhiteWins,
        GameStatus::VariantWin { winner: Color::Black } => GameOutcome::BlackWins,
        GameStatus::Stalemate => GameOutcome::Stalemate,
        GameStatus::DrawFiftyMove => GameOutcome::DrawFiftyMove,
        GameStatus::DrawThreefold => GameOutcome::DrawThreefold,
        GameStatus::DrawInsufficientMaterial => GameOutcome::DrawInsufficientMaterial,
    }
}

/// Whether `side` has insufficient material to deliver checkmate by any legal
/// sequence (lone king, K+N, K+B, or only same-coloured bishops) — used for the
/// flag-fall-vs-insufficient-material draw rule.
fn insufficient_to_mate(pos: &Position, side: Color) -> bool {
    if pos.pieces(side, Piece::Pawn) != 0
        || pos.pieces(side, Piece::Rook) != 0
        || pos.pieces(side, Piece::Queen) != 0
    {
        return false;
    }
    let knights = pos.pieces(side, Piece::Knight).count_ones();
    let mut bb = pos.pieces(side, Piece::Bishop);
    let (mut light, mut dark) = (0u32, 0u32);
    while bb != 0 {
        let sq = bb.trailing_zeros() as usize;
        bb &= bb - 1;
        if (sq % 8 + sq / 8).is_multiple_of(2) {
            dark += 1;
        } else {
            light += 1;
        }
    }
    let bishops = light + dark;
    if knights + bishops == 0 {
        return true; // lone king
    }
    if knights + bishops == 1 {
        return true; // K + single minor
    }
    if knights == 0 && (light == 0 || dark == 0) {
        return true; // only same-coloured bishops
    }
    false
}

/// Pieces captured by each side, derived from the start material minus what
/// remains (approximate once promotions occur).
fn captured(pos: &Position) -> (Vec<PieceKind>, Vec<PieceKind>) {
    const START: [(Piece, usize); 5] = [
        (Piece::Pawn, 8),
        (Piece::Knight, 2),
        (Piece::Bishop, 2),
        (Piece::Rook, 2),
        (Piece::Queen, 1),
    ];
    let mut cap_w = Vec::new(); // white captured = black's missing
    let mut cap_b = Vec::new();
    for (piece, start) in START {
        let white_left = pos.pieces(Color::White, piece).count_ones() as usize;
        let black_left = pos.pieces(Color::Black, piece).count_ones() as usize;
        for _ in 0..start.saturating_sub(black_left) {
            cap_w.push(to_kind(piece));
        }
        for _ in 0..start.saturating_sub(white_left) {
            cap_b.push(to_kind(piece));
        }
    }
    (cap_w, cap_b)
}
