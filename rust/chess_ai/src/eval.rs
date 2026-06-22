//! Hand-written static evaluation: tapered material + piece-square tables
//! (PeSTO middlegame/endgame sets), plus bishop pair, pawn structure
//! (doubled/isolated/passed), mobility and a king pawn-shield term.
//!
//! Returns centipawns from the side-to-move's perspective (negamax convention).

use chess_core::attacks::{bishop_attacks, knight_attacks, queen_attacks, rook_attacks};
use chess_core::bitboard::{pop_lsb, Bitboard, FILE_A};
use chess_core::types::{file_of, rank_of, Color, Piece, Variant};
use chess_core::Position;

pub const MATE: i32 = 30_000;
pub const MATE_THRESHOLD: i32 = MATE - 1000;

const MG_VALUE: [i32; 6] = [82, 337, 365, 477, 1025, 0];
const EG_VALUE: [i32; 6] = [94, 281, 297, 512, 936, 0];
const PHASE_W: [i32; 6] = [0, 1, 1, 2, 4, 0];
const TOTAL_PHASE: i32 = 24;

#[rustfmt::skip]
const MG_PAWN: [i32; 64] = [
      0,   0,   0,   0,   0,   0,   0,   0,
     98, 134,  61,  95,  68, 126,  34, -11,
     -6,   7,  26,  31,  65,  56,  25, -20,
    -14,  13,   6,  21,  23,  12,  17, -23,
    -27,  -2,  -5,  12,  17,   6,  10, -25,
    -26,  -4,  -4, -10,   3,   3,  33, -12,
    -35,  -1, -20, -23, -15,  24,  38, -22,
      0,   0,   0,   0,   0,   0,   0,   0,
];
#[rustfmt::skip]
const EG_PAWN: [i32; 64] = [
      0,   0,   0,   0,   0,   0,   0,   0,
    178, 173, 158, 134, 147, 132, 165, 187,
     94, 100,  85,  67,  56,  53,  82,  84,
     32,  24,  13,   5,  -2,   4,  17,  17,
     13,   9,  -3,  -7,  -7,  -8,   3,  -1,
      4,   7,  -6,   1,   0,  -5,  -1,  -8,
     13,   8,   8,  10,  13,   0,   2,  -7,
      0,   0,   0,   0,   0,   0,   0,   0,
];
#[rustfmt::skip]
const MG_KNIGHT: [i32; 64] = [
   -167, -89, -34, -49,  61, -97, -15,-107,
    -73, -41,  72,  36,  23,  62,   7, -17,
    -47,  60,  37,  65,  84, 129,  73,  44,
     -9,  17,  19,  53,  37,  69,  18,  22,
    -13,   4,  16,  13,  28,  19,  21,  -8,
    -23,  -9,  12,  10,  19,  17,  25, -16,
    -29, -53, -12,  -3,  -1,  18, -14, -19,
   -105, -21, -58, -33, -17, -28, -19, -23,
];
#[rustfmt::skip]
const EG_KNIGHT: [i32; 64] = [
    -58, -38, -13, -28, -31, -27, -63, -99,
    -25,  -8, -25,  -2,  -9, -25, -24, -52,
    -24, -20,  10,   9,  -1,  -9, -19, -41,
    -17,   3,  22,  22,  22,  11,   8, -18,
    -18,  -6,  16,  25,  16,  17,   4, -18,
    -23,  -3,  -1,  15,  10,  -3, -20, -22,
    -42, -20, -10,  -5,  -2, -20, -23, -44,
    -29, -51, -23, -15, -22, -18, -50, -64,
];
#[rustfmt::skip]
const MG_BISHOP: [i32; 64] = [
    -29,   4, -82, -37, -25, -42,   7,  -8,
    -26,  16, -18, -13,  30,  59,  18, -47,
    -16,  37,  43,  40,  35,  50,  37,  -2,
     -4,   5,  19,  50,  37,  37,   7,  -2,
     -6,  13,  13,  26,  34,  12,  10,   4,
      0,  15,  15,  15,  14,  27,  18,  10,
      4,  15,  16,   0,   7,  21,  33,   1,
    -33,  -3, -14, -21, -13, -12, -39, -21,
];
#[rustfmt::skip]
const EG_BISHOP: [i32; 64] = [
    -14, -21, -11,  -8,  -7,  -9, -17, -24,
     -8,  -4,   7, -12,  -3, -13,  -4, -14,
      2,  -8,   0,  -1,  -2,   6,   0,   4,
     -3,   9,  12,   9,  14,  10,   3,   2,
     -6,   3,  13,  19,   7,  10,  -3,  -9,
    -12,  -3,   8,  10,  13,   3,  -7, -15,
    -14, -18,  -7,  -1,   4,  -9, -15, -27,
    -23,  -9, -23,  -5,  -9, -16,  -5, -17,
];
#[rustfmt::skip]
const MG_ROOK: [i32; 64] = [
     32,  42,  32,  51,  63,   9,  31,  43,
     27,  32,  58,  62,  80,  67,  26,  44,
     -5,  19,  26,  36,  17,  45,  61,  16,
    -24, -11,   7,  26,  24,  35,  -8, -20,
    -36, -26, -12,  -1,   9,  -7,   6, -23,
    -45, -25, -16, -17,   3,   0,  -5, -33,
    -44, -16, -20,  -9,  -1,  11,  -6, -71,
    -19, -13,   1,  17,  16,   7, -37, -26,
];
#[rustfmt::skip]
const EG_ROOK: [i32; 64] = [
     13,  10,  18,  15,  12,  12,   8,   5,
     11,  13,  13,  11,  -3,   3,   8,   3,
      7,   7,   7,   5,   4,  -3,  -5,  -3,
      4,   3,  13,   1,   2,   1,  -1,   2,
      3,   5,   8,   4,  -5,  -6,  -8, -11,
     -4,   0,  -5,  -1,  -7, -12,  -8, -16,
     -6,  -6,   0,   2,  -9,  -9, -11,  -3,
     -9,   2,   3,  -1,  -5, -13,   4, -20,
];
#[rustfmt::skip]
const MG_QUEEN: [i32; 64] = [
    -28,   0,  29,  12,  59,  44,  43,  45,
    -24, -39,  -5,   1, -16,  57,  28,  54,
    -13, -17,   7,   8,  29,  56,  47,  57,
    -27, -27, -16, -16,  -1,  17,  -2,   1,
     -9, -26,  -9, -10,  -2,  -4,   3,  -3,
    -14,   2, -11,  -2,  -5,   2,  14,   5,
    -35,  -8,  11,   2,   8,  15,  -3,   1,
     -1, -18,  -9,  10, -15, -25, -31, -50,
];
#[rustfmt::skip]
const EG_QUEEN: [i32; 64] = [
     -9,  22,  22,  27,  27,  19,  10,  20,
    -17,  20,  32,  41,  58,  25,  30,   0,
    -20,   6,   9,  49,  47,  35,  19,   9,
      3,  22,  24,  45,  57,  40,  57,  36,
    -18,  28,  19,  47,  31,  34,  39,  23,
    -16, -27,  15,   6,   9,  17,  10,   5,
    -22, -23, -30, -16, -16, -23, -36, -32,
    -33, -28, -22, -43,  -5, -32, -20, -41,
];
#[rustfmt::skip]
const MG_KING: [i32; 64] = [
    -65,  23,  16, -15, -56, -34,   2,  13,
     29,  -1, -20,  -7,  -8,  -4, -38, -29,
     -9,  24,   2, -16, -20,   6,  22, -22,
    -17, -20, -12, -27, -30, -25, -14, -36,
    -49,  -1, -27, -39, -46, -44, -33, -51,
    -14, -14, -22, -46, -44, -30, -15, -27,
      1,   7,  -8, -64, -43, -16,   9,   8,
    -15,  36,  12, -54,   8, -28,  24,  14,
];
#[rustfmt::skip]
const EG_KING: [i32; 64] = [
    -74, -35, -18, -18, -11,  15,   4, -17,
    -12,  17,  14,  17,  17,  38,  23,  11,
     10,  17,  23,  15,  20,  45,  44,  13,
     -8,  22,  24,  27,  26,  33,  26,   3,
    -18,  -4,  21,  24,  27,  23,   9, -11,
    -19,  -3,  11,  21,  23,  16,   7,  -9,
    -27, -11,   4,  13,  14,   4,  -5, -17,
    -53, -34, -21, -11, -28, -14, -24, -43,
];

const MG_PST: [[i32; 64]; 6] =
    [MG_PAWN, MG_KNIGHT, MG_BISHOP, MG_ROOK, MG_QUEEN, MG_KING];
const EG_PST: [[i32; 64]; 6] =
    [EG_PAWN, EG_KNIGHT, EG_BISHOP, EG_ROOK, EG_QUEEN, EG_KING];

#[inline]
fn file_mask(file: u8) -> Bitboard {
    FILE_A << file
}

#[inline]
fn adjacent_files(file: u8) -> Bitboard {
    let mut m = 0;
    if file > 0 {
        m |= file_mask(file - 1);
    }
    if file < 7 {
        m |= file_mask(file + 1);
    }
    m
}

/// All squares strictly in front of `sq` for `color` on the same + adjacent
/// files (used for passed-pawn detection).
fn passed_mask(color: Color, sq: u8) -> Bitboard {
    let file = file_of(sq);
    let files = file_mask(file) | adjacent_files(file);
    let rank = rank_of(sq);
    let mut ahead = 0u64;
    match color {
        Color::White => {
            for r in (rank + 1)..8 {
                ahead |= 0xffu64 << (r * 8);
            }
        }
        Color::Black => {
            for r in 0..rank {
                ahead |= 0xffu64 << (r * 8);
            }
        }
    }
    files & ahead
}

pub fn evaluate(pos: &Position) -> i32 {
    let mut mg = 0i32;
    let mut eg = 0i32;
    let mut phase = 0i32;

    for &color in &[Color::White, Color::Black] {
        let sign = if color == Color::White { 1 } else { -1 };
        for piece in Piece::ALL {
            let bb = pos.pieces(color, piece);
            phase += PHASE_W[piece.index()] * bb.count_ones() as i32;
            let mut bbm = bb;
            while bbm != 0 {
                let sq = pop_lsb(&mut bbm) as usize;
                let idx = if color == Color::White { sq ^ 56 } else { sq };
                mg += sign * (MG_VALUE[piece.index()] + MG_PST[piece.index()][idx]);
                eg += sign * (EG_VALUE[piece.index()] + EG_PST[piece.index()][idx]);
            }
        }
    }

    // Crazyhouse / Bughouse: pieces in hand are real, droppable material. The
    // eval ignored them, so a side fed a big reserve (e.g. a Bughouse partner)
    // looked equal and the bot squandered it. Count them a touch under on-board
    // value so dropping (hand → board) is still favoured.
    if matches!(pos.variant, Variant::Crazyhouse | Variant::Bughouse) {
        for &color in &[Color::White, Color::Black] {
            let sign = if color == Color::White { 1 } else { -1 };
            for pi in 0..5usize {
                let n = pos.hand[color.index()][pi] as i32;
                if n != 0 {
                    mg += sign * n * (MG_VALUE[pi] * 9 / 10);
                    eg += sign * n * (EG_VALUE[pi] * 9 / 10);
                }
            }
        }
    }

    let (emg, eeg) = extra_terms(pos);
    mg += emg;
    eg += eeg;

    let phase = phase.min(TOTAL_PHASE);
    let score = (mg * phase + eg * (TOTAL_PHASE - phase)) / TOTAL_PHASE;
    if pos.side == Color::White {
        score
    } else {
        -score
    }
}

/// White-minus-black extra terms (bishop pair, pawn structure, mobility, king
/// shield), returned as (middlegame, endgame).
fn extra_terms(pos: &Position) -> (i32, i32) {
    let mut mg = 0;
    let mut eg = 0;
    for &color in &[Color::White, Color::Black] {
        let sign = if color == Color::White { 1 } else { -1 };
        let them = color.opp();
        let own = pos.occ[color.index()];
        let pawns = pos.pieces(color, Piece::Pawn);
        let enemy_pawns = pos.pieces(them, Piece::Pawn);

        // Bishop pair.
        if pos.pieces(color, Piece::Bishop).count_ones() >= 2 {
            mg += sign * 22;
            eg += sign * 40;
        }

        // Pawn structure.
        for file in 0..8u8 {
            let cnt = (pawns & file_mask(file)).count_ones() as i32;
            if cnt > 1 {
                mg += sign * -10 * (cnt - 1);
                eg += sign * -18 * (cnt - 1);
            }
        }
        let mut pb = pawns;
        while pb != 0 {
            let sq = pop_lsb(&mut pb);
            let file = file_of(sq);
            if pawns & adjacent_files(file) == 0 {
                mg += sign * -12;
                eg += sign * -8;
            }
            if enemy_pawns & passed_mask(color, sq) == 0 {
                let rel = if color == Color::White {
                    rank_of(sq)
                } else {
                    7 - rank_of(sq)
                } as i32;
                mg += sign * (5 * rel);
                eg += sign * (12 * rel);
            }
        }

        // Mobility (pseudo): reachable non-own squares for each piece.
        let mut score_mob = 0i32;
        let mut nb = pos.pieces(color, Piece::Knight);
        while nb != 0 {
            let sq = pop_lsb(&mut nb);
            score_mob += 4 * (knight_attacks(sq) & !own).count_ones() as i32;
        }
        let mut bb = pos.pieces(color, Piece::Bishop);
        while bb != 0 {
            let sq = pop_lsb(&mut bb);
            score_mob += 4 * (bishop_attacks(sq, pos.all) & !own).count_ones() as i32;
        }
        let mut rb = pos.pieces(color, Piece::Rook);
        while rb != 0 {
            let sq = pop_lsb(&mut rb);
            score_mob += 2 * (rook_attacks(sq, pos.all) & !own).count_ones() as i32;
        }
        let mut qb = pos.pieces(color, Piece::Queen);
        while qb != 0 {
            let sq = pop_lsb(&mut qb);
            score_mob += (queen_attacks(sq, pos.all) & !own).count_ones() as i32;
        }
        mg += sign * score_mob;
        eg += sign * (score_mob / 2);

        // King pawn shield (middlegame only): friendly pawns on the king's file
        // and adjacent files, on the two ranks in front of the king.
        // A kingless board only arises mid-search after a king capture (Atomic /
        // Fog of War); such nodes are variant-terminal and return before eval,
        // but guard anyway so king_sq()'s lsb(0)=a1 fallback can't skew the score.
        if pos.pieces(color, Piece::King) == 0 {
            continue;
        }
        let ksq = pos.king_sq(color);
        let kfiles = file_mask(file_of(ksq)) | adjacent_files(file_of(ksq));
        let krank = rank_of(ksq);
        let shield_ranks = match color {
            Color::White => {
                let r1 = (krank + 1).min(7);
                let r2 = (krank + 2).min(7);
                (0xffu64 << (r1 * 8)) | (0xffu64 << (r2 * 8))
            }
            Color::Black => {
                let r1 = krank.saturating_sub(1);
                let r2 = krank.saturating_sub(2);
                (0xffu64 << (r1 * 8)) | (0xffu64 << (r2 * 8))
            }
        };
        let shield = (pawns & kfiles & shield_ranks).count_ones() as i32;
        mg += sign * (10 * shield);
    }
    (mg, eg)
}
