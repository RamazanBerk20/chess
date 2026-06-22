//! Perft (performance test): counts the number of legal move sequences to a
//! given depth. This is the correctness gate for move generation.

use crate::position::Position;

/// Count leaf nodes at `depth` from `pos`.
pub fn perft(pos: &mut Position, depth: u32) -> u64 {
    if depth == 0 {
        return 1;
    }
    let list = pos.generate_legal();
    if depth == 1 {
        return list.len() as u64;
    }
    let mut nodes = 0;
    for i in 0..list.len() {
        let mv = list[i];
        let u = pos.make_move(mv);
        nodes += perft(pos, depth - 1);
        pos.unmake_move(mv, u);
    }
    nodes
}

/// Per-root-move breakdown (useful for debugging movegen against references).
pub fn perft_divide(pos: &mut Position, depth: u32) -> Vec<(String, u64)> {
    let mut out = Vec::new();
    let list = pos.generate_legal();
    for i in 0..list.len() {
        let mv = list[i];
        let u = pos.make_move(mv);
        let n = if depth <= 1 { 1 } else { perft(pos, depth - 1) };
        pos.unmake_move(mv, u);
        out.push((mv.to_uci(), n));
    }
    out
}
