//! Precomputed attack tables (knight/king/pawn) and classical ray-based
//! sliding-piece attacks.
//!
//! Tables are built at compile time via `const fn`, so there is zero runtime
//! initialisation. Sliding attacks use the classical ray method: take the full
//! ray, find the first blocker with a bitscan, and mask off everything beyond it.

use crate::bitboard::{bit, lsb, msb, Bitboard};
use crate::types::{Color, Square};

// Direction indices into RAYS.
const N: usize = 0;
const S: usize = 1;
const E: usize = 2;
const W: usize = 3;
const NE: usize = 4;
const NW: usize = 5;
const SE: usize = 6;
const SW: usize = 7;

// (file_delta, rank_delta) per direction.
const DELTAS: [(i32, i32); 8] = [
    (0, 1),   // N
    (0, -1),  // S
    (1, 0),   // E
    (-1, 0),  // W
    (1, 1),   // NE
    (-1, 1),  // NW
    (1, -1),  // SE
    (-1, -1), // SW
];

// Positive rays (square index increases) use lsb of blockers; negatives use msb.
const fn is_positive(dir: usize) -> bool {
    matches!(dir, N | E | NE | NW)
}

const fn build_rays() -> [[Bitboard; 64]; 8] {
    let mut rays = [[0u64; 64]; 8];
    let mut dir = 0;
    while dir < 8 {
        let (df, dr) = DELTAS[dir];
        let mut sq = 0i32;
        while sq < 64 {
            let mut f = sq % 8 + df;
            let mut r = sq / 8 + dr;
            let mut mask = 0u64;
            while f >= 0 && f < 8 && r >= 0 && r < 8 {
                mask |= 1u64 << (r * 8 + f);
                f += df;
                r += dr;
            }
            rays[dir][sq as usize] = mask;
            sq += 1;
        }
        dir += 1;
    }
    rays
}

const fn build_knight() -> [Bitboard; 64] {
    const JUMPS: [(i32, i32); 8] = [
        (1, 2),
        (2, 1),
        (2, -1),
        (1, -2),
        (-1, -2),
        (-2, -1),
        (-2, 1),
        (-1, 2),
    ];
    let mut t = [0u64; 64];
    let mut sq = 0i32;
    while sq < 64 {
        let f0 = sq % 8;
        let r0 = sq / 8;
        let mut mask = 0u64;
        let mut i = 0;
        while i < 8 {
            let f = f0 + JUMPS[i].0;
            let r = r0 + JUMPS[i].1;
            if f >= 0 && f < 8 && r >= 0 && r < 8 {
                mask |= 1u64 << (r * 8 + f);
            }
            i += 1;
        }
        t[sq as usize] = mask;
        sq += 1;
    }
    t
}

const fn build_king() -> [Bitboard; 64] {
    const STEPS: [(i32, i32); 8] = [
        (0, 1),
        (0, -1),
        (1, 0),
        (-1, 0),
        (1, 1),
        (1, -1),
        (-1, 1),
        (-1, -1),
    ];
    let mut t = [0u64; 64];
    let mut sq = 0i32;
    while sq < 64 {
        let f0 = sq % 8;
        let r0 = sq / 8;
        let mut mask = 0u64;
        let mut i = 0;
        while i < 8 {
            let f = f0 + STEPS[i].0;
            let r = r0 + STEPS[i].1;
            if f >= 0 && f < 8 && r >= 0 && r < 8 {
                mask |= 1u64 << (r * 8 + f);
            }
            i += 1;
        }
        t[sq as usize] = mask;
        sq += 1;
    }
    t
}

const fn build_pawn() -> [[Bitboard; 64]; 2] {
    let mut t = [[0u64; 64]; 2];
    let mut sq = 0i32;
    while sq < 64 {
        let f = sq % 8;
        let r = sq / 8;
        let mut white = 0u64;
        let mut black = 0u64;
        // White captures up the board.
        if f > 0 && r < 7 {
            white |= 1u64 << (sq + 7);
        }
        if f < 7 && r < 7 {
            white |= 1u64 << (sq + 9);
        }
        // Black captures down the board.
        if f < 7 && r > 0 {
            black |= 1u64 << (sq - 7);
        }
        if f > 0 && r > 0 {
            black |= 1u64 << (sq - 9);
        }
        t[0][sq as usize] = white;
        t[1][sq as usize] = black;
        sq += 1;
    }
    t
}

static RAYS: [[Bitboard; 64]; 8] = build_rays();
pub static KNIGHT_ATTACKS: [Bitboard; 64] = build_knight();
pub static KING_ATTACKS: [Bitboard; 64] = build_king();
pub static PAWN_ATTACKS: [[Bitboard; 64]; 2] = build_pawn();

#[inline]
fn ray_attack(dir: usize, sq: Square, occ: Bitboard) -> Bitboard {
    let mut attacks = RAYS[dir][sq as usize];
    let blockers = attacks & occ;
    if blockers != 0 {
        let blocker_sq = if is_positive(dir) {
            lsb(blockers)
        } else {
            msb(blockers)
        };
        attacks ^= RAYS[dir][blocker_sq as usize];
    }
    attacks
}

#[inline]
pub fn bishop_attacks(sq: Square, occ: Bitboard) -> Bitboard {
    ray_attack(NE, sq, occ)
        | ray_attack(NW, sq, occ)
        | ray_attack(SE, sq, occ)
        | ray_attack(SW, sq, occ)
}

#[inline]
pub fn rook_attacks(sq: Square, occ: Bitboard) -> Bitboard {
    ray_attack(N, sq, occ)
        | ray_attack(S, sq, occ)
        | ray_attack(E, sq, occ)
        | ray_attack(W, sq, occ)
}

#[inline]
pub fn queen_attacks(sq: Square, occ: Bitboard) -> Bitboard {
    bishop_attacks(sq, occ) | rook_attacks(sq, occ)
}

#[inline]
pub fn knight_attacks(sq: Square) -> Bitboard {
    KNIGHT_ATTACKS[sq as usize]
}

#[inline]
pub fn king_attacks(sq: Square) -> Bitboard {
    KING_ATTACKS[sq as usize]
}

#[inline]
pub fn pawn_attacks(c: Color, sq: Square) -> Bitboard {
    PAWN_ATTACKS[c.index()][sq as usize]
}

#[allow(dead_code)]
#[inline]
pub fn bit_of(sq: Square) -> Bitboard {
    bit(sq)
}
