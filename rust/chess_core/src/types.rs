//! Core value types: colors, pieces, squares, castling rights, moves.

use std::fmt;

/// Side to move / piece owner.
#[derive(Clone, Copy, PartialEq, Eq, Debug, Hash)]
pub enum Color {
    White,
    Black,
}

impl Color {
    #[inline]
    pub const fn opp(self) -> Color {
        match self {
            Color::White => Color::Black,
            Color::Black => Color::White,
        }
    }
    #[inline]
    pub const fn index(self) -> usize {
        self as usize
    }
}

/// Game variant. `Standard` is normal chess; the others change win conditions
/// and/or movement rules.
#[derive(Clone, Copy, PartialEq, Eq, Debug, Default, Hash)]
pub enum Variant {
    #[default]
    Standard,
    ThreeCheck,
    KingOfTheHill,
    Chess960,
    Atomic,
    Crazyhouse,
    /// Like Crazyhouse, but captured pieces are NOT added to the capturer's own
    /// hand — the match layer routes them to the partner's board.
    Bughouse,
    /// Dark chess: you see only squares your pieces observe; there is no check
    /// (it's hidden) — you win by capturing the enemy king.
    FogOfWar,
}

/// The four central squares (d4, e4, d5, e5) — the "hill" in King of the Hill.
pub const HILL: [Square; 4] = [27, 28, 35, 36];

/// Piece kind, ordered to match bitboard/zobrist indexing.
#[derive(Clone, Copy, PartialEq, Eq, Debug, Hash)]
pub enum Piece {
    Pawn,
    Knight,
    Bishop,
    Rook,
    Queen,
    King,
}

impl Piece {
    pub const ALL: [Piece; 6] = [
        Piece::Pawn,
        Piece::Knight,
        Piece::Bishop,
        Piece::Rook,
        Piece::Queen,
        Piece::King,
    ];

    #[inline]
    pub const fn index(self) -> usize {
        self as usize
    }

    #[inline]
    pub const fn from_index(i: usize) -> Piece {
        Piece::ALL[i]
    }

    /// Lowercase letter used in FEN/SAN (uppercase applied by caller for White).
    pub const fn to_char(self) -> char {
        match self {
            Piece::Pawn => 'p',
            Piece::Knight => 'n',
            Piece::Bishop => 'b',
            Piece::Rook => 'r',
            Piece::Queen => 'q',
            Piece::King => 'k',
        }
    }

    pub const fn from_char(c: char) -> Option<Piece> {
        match c.to_ascii_lowercase() {
            'p' => Some(Piece::Pawn),
            'n' => Some(Piece::Knight),
            'b' => Some(Piece::Bishop),
            'r' => Some(Piece::Rook),
            'q' => Some(Piece::Queen),
            'k' => Some(Piece::King),
            _ => None,
        }
    }
}

/// A board square, 0..=63 with a1=0, b1=1, ..., h8=63 (LSB = a1).
pub type Square = u8;

#[inline]
pub const fn file_of(sq: Square) -> u8 {
    sq & 7
}
#[inline]
pub const fn rank_of(sq: Square) -> u8 {
    sq >> 3
}
#[inline]
pub const fn make_square(file: u8, rank: u8) -> Square {
    rank * 8 + file
}

/// Parse an algebraic square name like "e4" into a [`Square`].
pub fn parse_square(s: &str) -> Option<Square> {
    let b = s.as_bytes();
    if b.len() != 2 {
        return None;
    }
    let file = b[0].wrapping_sub(b'a');
    let rank = b[1].wrapping_sub(b'1');
    if file > 7 || rank > 7 {
        return None;
    }
    Some(make_square(file, rank))
}

/// Render a square as algebraic notation, e.g. `e4`.
pub fn square_name(sq: Square) -> String {
    let f = (b'a' + file_of(sq)) as char;
    let r = (b'1' + rank_of(sq)) as char;
    format!("{f}{r}")
}

/// Castling availability, packed into 4 bits.
#[derive(Clone, Copy, PartialEq, Eq, Debug, Hash, Default)]
pub struct CastlingRights(pub u8);

impl CastlingRights {
    pub const WK: u8 = 0b0001;
    pub const WQ: u8 = 0b0010;
    pub const BK: u8 = 0b0100;
    pub const BQ: u8 = 0b1000;

    #[inline]
    pub const fn has(self, flag: u8) -> bool {
        self.0 & flag != 0
    }
    #[inline]
    pub fn add(&mut self, flag: u8) {
        self.0 |= flag;
    }
}

/// Move encoding kinds (4-bit), following the common chessprogramming layout.
pub mod kind {
    pub const QUIET: u8 = 0;
    pub const DOUBLE_PUSH: u8 = 1;
    pub const KING_CASTLE: u8 = 2;
    pub const QUEEN_CASTLE: u8 = 3;
    pub const CAPTURE: u8 = 4;
    pub const EP_CAPTURE: u8 = 5;
    /// Crazyhouse drop: `from` holds the dropped piece's index (Pawn..Queen),
    /// `to` is the destination. (Bit 2 is set, but `is_drop` masks it off the
    /// capture predicate.)
    pub const DROP: u8 = 6;
    pub const KNIGHT_PROMO: u8 = 8;
    pub const BISHOP_PROMO: u8 = 9;
    pub const ROOK_PROMO: u8 = 10;
    pub const QUEEN_PROMO: u8 = 11;
    pub const KNIGHT_PROMO_CAP: u8 = 12;
    pub const BISHOP_PROMO_CAP: u8 = 13;
    pub const ROOK_PROMO_CAP: u8 = 14;
    pub const QUEEN_PROMO_CAP: u8 = 15;
}

/// A move packed into 16 bits: from(6) | to(6) | kind(4).
#[derive(Clone, Copy, PartialEq, Eq, Hash)]
pub struct Move(u16);

impl Move {
    #[inline]
    pub const fn new(from: Square, to: Square, k: u8) -> Move {
        Move((from as u16) | ((to as u16) << 6) | ((k as u16) << 12))
    }
    #[inline]
    pub const fn from(self) -> Square {
        (self.0 & 0x3f) as u8
    }
    #[inline]
    pub const fn to(self) -> Square {
        ((self.0 >> 6) & 0x3f) as u8
    }
    #[inline]
    pub const fn kind(self) -> u8 {
        (self.0 >> 12) as u8
    }
    #[inline]
    pub const fn is_capture(self) -> bool {
        self.kind() & kind::CAPTURE != 0 && !self.is_drop()
    }
    #[inline]
    pub const fn is_drop(self) -> bool {
        self.kind() == kind::DROP
    }
    /// The piece placed by a Crazyhouse drop (`from` field holds its index).
    #[inline]
    pub const fn dropped_piece(self) -> Piece {
        Piece::ALL[self.from() as usize]
    }
    #[inline]
    pub const fn is_ep(self) -> bool {
        self.kind() == kind::EP_CAPTURE
    }
    #[inline]
    pub const fn is_castle(self) -> bool {
        matches!(self.kind(), kind::KING_CASTLE | kind::QUEEN_CASTLE)
    }
    #[inline]
    pub const fn is_double_push(self) -> bool {
        self.kind() == kind::DOUBLE_PUSH
    }
    #[inline]
    pub const fn is_promotion(self) -> bool {
        self.kind() >= kind::KNIGHT_PROMO
    }
    /// Promoted-to piece, if this is a promotion.
    #[inline]
    pub const fn promotion(self) -> Option<Piece> {
        if self.is_promotion() {
            Some(Piece::ALL[1 + (self.kind() & 3) as usize]) // knight..queen
        } else {
            None
        }
    }
    /// Long algebraic / UCI form, e.g. `e2e4`, `e7e8q`, or a drop `N@f3`.
    pub fn to_uci(self) -> String {
        if self.is_drop() {
            let mut s = String::new();
            s.push(self.dropped_piece().to_char().to_ascii_uppercase());
            s.push('@');
            s.push_str(&square_name(self.to()));
            return s;
        }
        let mut s = square_name(self.from());
        s.push_str(&square_name(self.to()));
        if let Some(p) = self.promotion() {
            s.push(p.to_char());
        }
        s
    }
}

impl fmt::Debug for Move {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.to_uci())
    }
}

/// A fixed-capacity, zero-allocation move list (max legal moves in any position < 256).
pub struct MoveList {
    moves: [Move; 256],
    len: usize,
}

impl MoveList {
    #[inline]
    pub fn new() -> MoveList {
        MoveList {
            moves: [Move(0); 256],
            len: 0,
        }
    }
    #[inline]
    pub fn push(&mut self, m: Move) {
        self.moves[self.len] = m;
        self.len += 1;
    }
    #[inline]
    pub fn len(&self) -> usize {
        self.len
    }
    #[inline]
    pub fn is_empty(&self) -> bool {
        self.len == 0
    }
    #[inline]
    pub fn as_slice(&self) -> &[Move] {
        &self.moves[..self.len]
    }
    /// Mutable view of the active moves (used by the AI to order them in place).
    #[inline]
    pub fn as_mut_slice(&mut self) -> &mut [Move] {
        &mut self.moves[..self.len]
    }
}

impl Default for MoveList {
    fn default() -> Self {
        Self::new()
    }
}

impl std::ops::Index<usize> for MoveList {
    type Output = Move;
    #[inline]
    fn index(&self, i: usize) -> &Move {
        &self.moves[i]
    }
}
