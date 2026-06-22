//! Typed errors for the rules engine (surfaced across the bridge as messages).

use thiserror::Error;

#[derive(Error, Debug, Clone, PartialEq, Eq)]
pub enum ChessError {
    #[error("invalid FEN: {0}")]
    InvalidFen(String),
    #[error("illegal move: {0}")]
    IllegalMove(String),
    #[error("invalid move string: {0}")]
    InvalidMove(String),
    #[error("invalid SAN: {0}")]
    InvalidSan(String),
}

pub type Result<T> = std::result::Result<T, ChessError>;
