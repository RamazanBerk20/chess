//! Bitboard type alias and bit-manipulation helpers.
//!
//! A `u64` where bit `i` corresponds to [`crate::types::Square`] `i` (a1 = bit 0).

use crate::types::Square;

pub type Bitboard = u64;

pub const FILE_A: Bitboard = 0x0101_0101_0101_0101;
pub const FILE_H: Bitboard = FILE_A << 7;
pub const RANK_1: Bitboard = 0xff;
pub const RANK_2: Bitboard = RANK_1 << 8;
pub const RANK_4: Bitboard = RANK_1 << 24;
pub const RANK_5: Bitboard = RANK_1 << 32;
pub const RANK_7: Bitboard = RANK_1 << 48;
pub const RANK_8: Bitboard = RANK_1 << 56;

#[inline]
pub const fn bit(sq: Square) -> Bitboard {
    1u64 << sq
}

/// Index of the least significant set bit (square). Caller ensures `b != 0`.
#[inline]
pub fn lsb(b: Bitboard) -> Square {
    b.trailing_zeros() as Square
}

/// Index of the most significant set bit (square). Caller ensures `b != 0`.
#[inline]
pub fn msb(b: Bitboard) -> Square {
    (63 - b.leading_zeros()) as Square
}

/// Pop and return the least significant set bit's square.
#[inline]
pub fn pop_lsb(b: &mut Bitboard) -> Square {
    let s = lsb(*b);
    *b &= *b - 1;
    s
}

#[inline]
pub fn count(b: Bitboard) -> u32 {
    b.count_ones()
}
