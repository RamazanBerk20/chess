//! A simple greedy bot (not a search engine): take the highest-value capture,
//! else a pseudo-random legal move.

use crate::game::FourGame;
use crate::movegen::Move4;

pub fn greedy_move(game: &FourGame, seed: u64) -> Option<Move4> {
    let moves = game.legal_moves();
    if moves.is_empty() {
        return None;
    }
    let mut best_score = -1i64;
    let mut best: Vec<Move4> = Vec::new();
    for &m in &moves {
        let mut s = 0i64;
        if let Some((_, cp)) = game.board.get(m.to.col, m.to.row) {
            s += cp.value() as i64 * 10;
        }
        if m.promo.is_some() {
            s += 80;
        }
        if s > best_score {
            best_score = s;
            best.clear();
            best.push(m);
        } else if s == best_score {
            best.push(m);
        }
    }
    // Pick among the equally-best moves with a tiny LCG seeded by `seed`.
    let r = seed
        .wrapping_mul(6364136223846793005)
        .wrapping_add(1442695040888963407);
    Some(best[(r >> 33) as usize % best.len()])
}
