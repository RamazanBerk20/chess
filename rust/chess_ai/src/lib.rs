//! `chess_ai` — hand-written search + evaluation.
//!
//! Negamax + alpha-beta with iterative deepening, quiescence, a Zobrist
//! transposition table, move ordering and a tapered (PeSTO) evaluation.
//! Pure: no bridge dependency. Cancellation is a caller-supplied
//! `Fn() -> bool`; time is read internally via `std::time::Instant`.

pub mod eval;
pub mod search;

pub use eval::{evaluate, MATE, MATE_THRESHOLD};
pub use search::{AiConfig, Engine, SearchInfo, SearchLimits};
