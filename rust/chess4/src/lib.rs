//! `chess4` — a 4-player chess engine (chess.com style) on a 14×14 cross board.
//! A separate mailbox engine (the 8×8 bitboard `chess_core` cannot represent it).

pub mod board;
pub mod bot;
pub mod game;
pub mod movegen;
pub mod serial;
pub mod types;

pub use board::Board;
pub use game::{FourGame, FourResult};
pub use movegen::Move4;
pub use types::{Coord, Format, Piece, Player, PlayerStatus, Team};
