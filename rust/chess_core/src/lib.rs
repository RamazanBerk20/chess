//! `chess_core` — hand-written chess rules engine.
//!
//! Pure Rust, no bridge/Flutter dependency, so it stays unit-testable in
//! isolation. Bitboards, fully-legal move generation, FEN/SAN, Zobrist hashing
//! and termination/draw detection. Clock logic (M4) and the rest of PGN land in
//! later milestones.

pub mod attacks;
pub mod bitboard;
pub mod clock;
pub mod error;
pub mod fen;
pub mod game;
pub mod movegen;
pub mod perft;
pub mod position;
pub mod san;
pub mod types;
pub mod zobrist;

pub use clock::{Clock, TimeControl};
pub use error::{ChessError, Result};
pub use fen::{parse_fen, to_fen};
pub use game::{Game, GameStatus};
pub use perft::{perft, perft_divide};
pub use position::Position;
pub use types::{Color, Move, MoveList, Piece, Square, Variant};

/// Standard chess starting position in FEN.
pub const START_FEN: &str = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

/// Short engine identity string.
pub fn engine_info() -> String {
    format!("chess_core {} (movegen ready)", env!("CARGO_PKG_VERSION"))
}
