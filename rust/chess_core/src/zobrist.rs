//! Zobrist hashing keys, generated once from a fixed seed so hashes are stable
//! across runs (needed for repetition detection and the AI transposition table).

use rand::rngs::StdRng;
use rand::{RngCore, SeedableRng};
use std::sync::OnceLock;

use crate::types::{Color, Piece, Square};

pub struct Zobrist {
    /// [color][piece][square]
    piece: [[[u64; 64]; 6]; 2],
    /// XORed in when it is Black's turn.
    side: u64,
    /// Indexed by the 4-bit castling-rights mask (0..16).
    castle: [u64; 16],
    /// Indexed by the file of the en-passant square.
    ep_file: [u64; 8],
}

impl Zobrist {
    fn new() -> Zobrist {
        let mut rng = StdRng::seed_from_u64(0x00C0_FFEE_C0DE_F00D);
        let mut piece = [[[0u64; 64]; 6]; 2];
        for color in piece.iter_mut() {
            for pc in color.iter_mut() {
                for sq in pc.iter_mut() {
                    *sq = rng.next_u64();
                }
            }
        }
        let side = rng.next_u64();
        let mut castle = [0u64; 16];
        for c in castle.iter_mut() {
            *c = rng.next_u64();
        }
        let mut ep_file = [0u64; 8];
        for e in ep_file.iter_mut() {
            *e = rng.next_u64();
        }
        Zobrist {
            piece,
            side,
            castle,
            ep_file,
        }
    }

    #[inline]
    pub fn piece(&self, c: Color, p: Piece, sq: Square) -> u64 {
        self.piece[c.index()][p.index()][sq as usize]
    }
    #[inline]
    pub fn side(&self) -> u64 {
        self.side
    }
    #[inline]
    pub fn castle(&self, mask: u8) -> u64 {
        self.castle[mask as usize]
    }
    #[inline]
    pub fn ep_file(&self, file: u8) -> u64 {
        self.ep_file[file as usize]
    }
}

static ZOBRIST: OnceLock<Zobrist> = OnceLock::new();

#[inline]
pub fn zobrist() -> &'static Zobrist {
    ZOBRIST.get_or_init(Zobrist::new)
}
