//! Negamax + alpha-beta search with iterative deepening, quiescence, a Zobrist
//! transposition table and move ordering (hash → MVV-LVA → killers → history).
//!
//! Pure: time is read via `std::time::Instant`, and cancellation is a caller
//! supplied `Fn() -> bool` predicate, so no bridge types leak in here.

use std::time::{Duration, Instant};

use rand::rngs::StdRng;
use rand::{Rng, SeedableRng};

use chess_core::types::Piece;
use chess_core::{Move, MoveList, Position};

use crate::eval::{evaluate, MATE, MATE_THRESHOLD};

const INF: i32 = 50_000;
const MAX_PLY: usize = 64;
const PVAL: [i32; 6] = [100, 320, 330, 500, 900, 20_000];

/// Depth cap for the post-search *weakening* re-score. Weakening only needs a
/// ranking of root moves (then noise/top-N/blunder selection), not deep
/// accuracy, so a shallow pass keeps it cheap — critical for Fog of War, whose
/// pseudo-legal movegen yields ~100 root moves to score.
const WEAKEN_MAX_DEPTH: u8 = 3;

const BOUND_EXACT: u8 = 0;
const BOUND_LOWER: u8 = 1;
const BOUND_UPPER: u8 = 2;

#[derive(Clone, Copy)]
struct TtEntry {
    key: u64,
    depth: i16,
    score: i32,
    flag: u8,
    best: Option<Move>,
}

impl Default for TtEntry {
    fn default() -> Self {
        TtEntry {
            key: 0,
            depth: -1,
            score: 0,
            flag: BOUND_EXACT,
            best: None,
        }
    }
}

/// Search bounds. `move_time_ms == None` means depth-limited only.
#[derive(Clone, Copy, Debug)]
pub struct SearchLimits {
    pub max_depth: u8,
    pub move_time_ms: Option<u64>,
}

/// Difficulty configuration: full-strength search plus *principled* weakening
/// (shallow search, top-N random selection, deliberate blunders, eval noise),
/// all reproducible from `seed`.
#[derive(Clone, Copy, Debug)]
pub struct AiConfig {
    pub max_depth: u8,
    pub move_time_ms: Option<u64>,
    /// Centipawn range of random noise added to each root move's score.
    pub eval_noise: i32,
    /// Probability (0..1) of deliberately choosing a weaker move.
    pub blunder_chance: f32,
    /// Pick randomly among the top-N moves (1 = always the best).
    pub top_n_random: u8,
    /// Draw aversion in centipawns (positive = avoid draws).
    pub contempt: i32,
    /// RNG seed for reproducible weakening.
    pub seed: u64,
}

impl Default for AiConfig {
    fn default() -> Self {
        AiConfig {
            max_depth: 8,
            move_time_ms: Some(1000),
            eval_noise: 0,
            blunder_chance: 0.0,
            top_n_random: 1,
            contempt: 0,
            seed: 0,
        }
    }
}

/// Result of (an iteration of) the search.
#[derive(Clone, Debug, Default)]
pub struct SearchInfo {
    pub depth: u8,
    pub score_cp: i32,
    pub nodes: u64,
    pub best: Option<Move>,
    pub pv: Vec<Move>,
}

pub struct Engine {
    tt: Vec<TtEntry>,
    mask: usize,
    killers: [[Option<Move>; 2]; MAX_PLY],
    history: [[i32; 64]; 64],
    nodes: u64,
    stop: bool,
    deadline: Option<Instant>,
    contempt: i32,
    /// Position hashes along the current search line (for repetition detection).
    path: Vec<u64>,
    /// Position hashes from the actual game before the root (for repetition).
    game_hist: Vec<u64>,
}

impl Engine {
    /// Create an engine with a transposition table of `2^bits` entries.
    pub fn new(tt_bits: u32) -> Engine {
        let size = 1usize << tt_bits;
        Engine {
            tt: vec![TtEntry::default(); size],
            mask: size - 1,
            killers: [[None; 2]; MAX_PLY],
            history: [[0; 64]; 64],
            nodes: 0,
            stop: false,
            deadline: None,
            contempt: 0,
            path: Vec::with_capacity(MAX_PLY),
            game_hist: Vec::new(),
        }
    }

    /// Provide the actual game's position-hash history so the search treats a
    /// return to an earlier game position as a draw (repetition avoidance).
    pub fn set_game_history(&mut self, history: &[u64]) {
        self.game_hist = history.to_vec();
    }

    fn is_draw_by_repetition(&self, hash: u64) -> bool {
        // A repeat within the current search line is a draw (the side can force
        // the third occurrence). Against the actual game history, require a true
        // threefold: the position must already have occurred twice, so this is
        // the third — otherwise a single earlier occurrence would be mis-scored
        // as a draw, dodging winning moves / over-valuing lost lines.
        if self.path.contains(&hash) {
            return true;
        }
        self.game_hist.iter().filter(|&&h| h == hash).count() >= 2
    }

    /// Draw score from the perspective of the side to move at `ply`, sized so
    /// the *root* side always sees a draw as `-contempt` (contempt > 0 = draw
    /// aversion) no matter the ply parity at which the draw is detected. A flat
    /// `-contempt` would invert at odd plies, making the engine seek draws.
    #[inline]
    fn draw_score(&self, ply: usize) -> i32 {
        if ply % 2 == 0 {
            -self.contempt
        } else {
            self.contempt
        }
    }

    /// Full-strength iterative-deepening search.
    pub fn search(
        &mut self,
        root: &Position,
        limits: SearchLimits,
        cancel: &dyn Fn() -> bool,
        on_info: impl FnMut(&SearchInfo),
    ) -> SearchInfo {
        self.contempt = 0;
        self.run(root, limits, cancel, on_info)
    }

    /// Search with difficulty config: full search, then *principled* weakening
    /// (eval noise → top-N / blunder selection), reproducible from `config.seed`.
    pub fn search_with_config(
        &mut self,
        root: &Position,
        config: AiConfig,
        cancel: &dyn Fn() -> bool,
        on_info: impl FnMut(&SearchInfo),
    ) -> SearchInfo {
        self.contempt = config.contempt;
        let limits = SearchLimits {
            max_depth: config.max_depth,
            move_time_ms: config.move_time_ms,
        };
        let info = self.run(root, limits, cancel, on_info);

        let needs_weakening =
            config.top_n_random > 1 || config.blunder_chance > 0.0 || config.eval_noise > 0;
        if !needs_weakening {
            return info;
        }

        // Weakening only needs a ranking of root moves, not deep accuracy.
        // Re-searching every root move at full depth with NO time budget hangs
        // in Fog of War (pseudo-legal movegen → ~100 root moves). Cap the depth
        // shallow and keep the move-time budget as a hard backstop; if the
        // deadline interrupts before any move scores, `scored` is empty and we
        // fall back to the main search's best move below.
        let depth = info.depth.min(WEAKEN_MAX_DEPTH).max(1);
        self.stop = false;
        self.deadline = limits
            .move_time_ms
            .map(|ms| Instant::now() + Duration::from_millis(ms));
        let mut scored = self.root_scores(root, depth, cancel);
        if scored.is_empty() {
            return info;
        }

        let mut rng = StdRng::seed_from_u64(config.seed);
        if config.eval_noise > 0 {
            let n = config.eval_noise;
            for s in scored.iter_mut() {
                s.1 += rng.random_range(-n..=n);
            }
            scored.sort_by_key(|x| std::cmp::Reverse(x.1));
        }
        let (mv, score) = select_move(&scored, &config, &mut rng);
        SearchInfo {
            depth,
            score_cp: score,
            nodes: info.nodes,
            best: Some(mv),
            pv: vec![mv],
        }
    }

    /// Score every root move at `depth` with a full window (for weakening).
    fn root_scores(
        &mut self,
        root: &Position,
        depth: u8,
        cancel: &dyn Fn() -> bool,
    ) -> Vec<(Move, i32)> {
        let mut pos = root.clone();
        let moves = pos.generate_legal();
        let mut out = Vec::new();
        self.path.clear();
        self.path.push(pos.hash);
        for i in 0..moves.len() {
            let mv = moves[i];
            let u = pos.make_move(mv);
            let score = -self.negamax(&mut pos, depth as i32 - 1, -INF, INF, 1, cancel);
            pos.unmake_move(mv, u);
            if self.stop {
                break;
            }
            out.push((mv, score));
        }
        out.sort_by_key(|x| std::cmp::Reverse(x.1));
        out
    }

    fn run(
        &mut self,
        root: &Position,
        limits: SearchLimits,
        cancel: &dyn Fn() -> bool,
        mut on_info: impl FnMut(&SearchInfo),
    ) -> SearchInfo {
        self.killers = [[None; 2]; MAX_PLY];
        self.history = [[0; 64]; 64];
        self.nodes = 0;
        self.stop = false;
        self.path.clear();
        self.deadline = limits
            .move_time_ms
            .map(|ms| Instant::now() + Duration::from_millis(ms));

        // Fallback so we always return a legal move.
        let mut work = root.clone();
        let legal = work.generate_legal();
        let mut result = SearchInfo {
            depth: 0,
            score_cp: 0,
            nodes: 0,
            best: if legal.is_empty() {
                None
            } else {
                Some(legal[0])
            },
            pv: Vec::new(),
        };
        if legal.is_empty() {
            return result;
        }

        let max_depth = limits.max_depth.max(1).min(MAX_PLY as u8 - 1);
        for depth in 1..=max_depth {
            let mut pos = root.clone();
            let score = self.negamax(&mut pos, depth as i32, -INF, INF, 0, cancel);
            if self.stop {
                break; // discard the incomplete iteration, keep the last result
            }
            let best = self.tt_probe(root.hash).and_then(|e| e.best).or(result.best);
            let pv = self.extract_pv(root, depth as usize);
            result = SearchInfo {
                depth,
                score_cp: score,
                nodes: self.nodes,
                best,
                pv,
            };
            on_info(&result);
            if score.abs() >= MATE_THRESHOLD {
                break; // forced mate found
            }
        }
        result
    }

    fn negamax(
        &mut self,
        pos: &mut Position,
        depth: i32,
        mut alpha: i32,
        beta: i32,
        ply: usize,
        cancel: &dyn Fn() -> bool,
    ) -> i32 {
        self.nodes += 1;
        if self.nodes & 2047 == 0 && self.timed_out(cancel) {
            self.stop = true;
        }
        if self.stop {
            return 0;
        }
        // Draw by repetition or fifty-move: score as a draw so a winning engine
        // makes progress instead of shuffling (contempt = draw aversion).
        if ply > 0 && (pos.halfmove >= 100 || self.is_draw_by_repetition(pos.hash)) {
            return self.draw_score(ply);
        }
        // Variant loss (opponent reached three checks / the hill / blew up our
        // king): the side to move has lost.
        if ply > 0 && pos.variant_terminal().is_some() {
            return -MATE + ply as i32;
        }
        if depth <= 0 {
            return self.quiescence(pos, alpha, beta, ply, cancel);
        }

        let key = pos.hash;
        let mut tt_best = None;
        if let Some(e) = self.tt_probe(key) {
            tt_best = e.best;
            if e.depth as i32 >= depth {
                let s = adjust_from_tt(e.score, ply);
                match e.flag {
                    BOUND_EXACT => return s,
                    BOUND_LOWER if s >= beta => return s,
                    BOUND_UPPER if s <= alpha => return s,
                    _ => {}
                }
            }
        }

        let mut moves = pos.generate_legal();
        if moves.is_empty() {
            return if pos.in_check(pos.side) {
                -MATE + ply as i32
            } else {
                self.draw_score(ply) // stalemate (draw); contempt = draw aversion
            };
        }
        self.order_moves(pos, &mut moves, tt_best, ply);

        let alpha_orig = alpha;
        let mut best_score = -INF;
        let mut best_move = None;
        self.path.push(pos.hash);
        for i in 0..moves.len() {
            let mv = moves[i];
            let u = pos.make_move(mv);
            let score = -self.negamax(pos, depth - 1, -beta, -alpha, ply + 1, cancel);
            pos.unmake_move(mv, u);
            if self.stop {
                self.path.pop();
                return 0;
            }
            if score > best_score {
                best_score = score;
                best_move = Some(mv);
            }
            if score > alpha {
                alpha = score;
            }
            if alpha >= beta {
                if !mv.is_capture() {
                    self.store_killer(ply, mv);
                    self.history[mv.from() as usize][mv.to() as usize] += depth * depth;
                }
                break;
            }
        }
        self.path.pop();

        let flag = if best_score <= alpha_orig {
            BOUND_UPPER
        } else if best_score >= beta {
            BOUND_LOWER
        } else {
            BOUND_EXACT
        };
        self.tt_store(key, depth, adjust_to_tt(best_score, ply), flag, best_move);
        best_score
    }

    fn quiescence(
        &mut self,
        pos: &mut Position,
        mut alpha: i32,
        beta: i32,
        ply: usize,
        cancel: &dyn Fn() -> bool,
    ) -> i32 {
        self.nodes += 1;
        if self.nodes & 2047 == 0 && self.timed_out(cancel) {
            self.stop = true;
        }
        if self.stop {
            return 0;
        }
        if ply > 0 && (pos.halfmove >= 100 || self.is_draw_by_repetition(pos.hash)) {
            return self.draw_score(ply);
        }
        if ply > 0 && pos.variant_terminal().is_some() {
            return -MATE + ply as i32;
        }

        // When in check we cannot "stand pat": search all evasions, else only
        // captures (with a stand-pat lower bound). This avoids the horizon
        // effect hiding a forced mate behind quiet check evasions.
        let in_check = pos.in_check(pos.side);
        if !in_check {
            let stand = evaluate(pos);
            if stand >= beta {
                return beta;
            }
            if stand > alpha {
                alpha = stand;
            }
        }
        if ply >= MAX_PLY - 1 {
            return evaluate(pos);
        }

        let mut moves = if in_check {
            pos.generate_legal()
        } else {
            capture_moves(pos)
        };
        if in_check && moves.is_empty() {
            return -MATE + ply as i32; // checkmate
        }
        self.order_captures(pos, &mut moves);
        for i in 0..moves.len() {
            let mv = moves[i];
            let u = pos.make_move(mv);
            let score = -self.quiescence(pos, -beta, -alpha, ply + 1, cancel);
            pos.unmake_move(mv, u);
            if self.stop {
                return 0;
            }
            if score >= beta {
                return beta;
            }
            if score > alpha {
                alpha = score;
            }
        }
        alpha
    }

    fn order_moves(
        &self,
        pos: &Position,
        moves: &mut MoveList,
        tt_best: Option<Move>,
        ply: usize,
    ) {
        let killers = self.killers[ply];
        let hist = &self.history;
        let score = |m: Move| -> i32 {
            if Some(m) == tt_best {
                return 2_000_000;
            }
            if m.is_capture() {
                return 1_000_000 + capture_value(pos, m) * 16 - mover_value(pos, m);
            }
            if Some(m) == killers[0] {
                return 900_000;
            }
            if Some(m) == killers[1] {
                return 800_000;
            }
            hist[m.from() as usize][m.to() as usize]
        };
        moves
            .as_mut_slice()
            .sort_by_key(|m| std::cmp::Reverse(score(*m)));
    }

    fn order_captures(&self, pos: &Position, moves: &mut MoveList) {
        let score = |m: Move| capture_value(pos, m) * 16 - mover_value(pos, m);
        moves
            .as_mut_slice()
            .sort_by_key(|m| std::cmp::Reverse(score(*m)));
    }

    fn store_killer(&mut self, ply: usize, mv: Move) {
        if self.killers[ply][0] != Some(mv) {
            self.killers[ply][1] = self.killers[ply][0];
            self.killers[ply][0] = Some(mv);
        }
    }

    #[inline]
    fn tt_probe(&self, key: u64) -> Option<TtEntry> {
        let e = self.tt[(key as usize) & self.mask];
        if e.key == key && e.depth >= 0 {
            Some(e)
        } else {
            None
        }
    }

    #[inline]
    fn tt_store(&mut self, key: u64, depth: i32, score: i32, flag: u8, best: Option<Move>) {
        let slot = (key as usize) & self.mask;
        let e = &mut self.tt[slot];
        // Depth-preferred replacement.
        if e.key != key || (depth as i16) >= e.depth {
            *e = TtEntry {
                key,
                depth: depth as i16,
                score,
                flag,
                best,
            };
        }
    }

    fn extract_pv(&self, root: &Position, max: usize) -> Vec<Move> {
        let mut pv = Vec::new();
        let mut pos = root.clone();
        for _ in 0..max {
            // Stop at a variant-terminal node (e.g. a king captured in Fog of
            // War / Atomic) — the game is over, don't walk past it.
            if pos.variant_terminal().is_some() {
                break;
            }
            let Some(e) = self.tt_probe(pos.hash) else {
                break;
            };
            let Some(mv) = e.best else { break };
            let legal = pos.generate_legal();
            if (0..legal.len()).any(|i| legal[i] == mv) {
                pv.push(mv);
                pos.make_move(mv);
            } else {
                break;
            }
        }
        pv
    }

    #[inline]
    fn timed_out(&self, cancel: &dyn Fn() -> bool) -> bool {
        cancel() || self.deadline.is_some_and(|d| Instant::now() >= d)
    }
}

/// Pick a move applying top-N randomness and deliberate blunders.
fn select_move(scored: &[(Move, i32)], config: &AiConfig, rng: &mut StdRng) -> (Move, i32) {
    let n = scored.len();
    // Deliberate blunder: choose from the weaker half of the move list.
    if n > 1 && config.blunder_chance > 0.0 && rng.random::<f32>() < config.blunder_chance {
        let lo = (n / 2).max(1);
        let idx = rng.random_range(lo..n);
        return scored[idx];
    }
    let top = (config.top_n_random.max(1) as usize).min(n);
    scored[rng.random_range(0..top)]
}

/// Convert a node-relative mate score into a TT-stored (root-relative) score.
#[inline]
fn adjust_to_tt(score: i32, ply: usize) -> i32 {
    if score >= MATE_THRESHOLD {
        score + ply as i32
    } else if score <= -MATE_THRESHOLD {
        score - ply as i32
    } else {
        score
    }
}

/// Convert a TT-stored mate score back to node-relative.
#[inline]
fn adjust_from_tt(score: i32, ply: usize) -> i32 {
    if score >= MATE_THRESHOLD {
        score - ply as i32
    } else if score <= -MATE_THRESHOLD {
        score + ply as i32
    } else {
        score
    }
}

fn capture_moves(pos: &mut Position) -> MoveList {
    let all = pos.generate_legal();
    let mut caps = MoveList::new();
    for i in 0..all.len() {
        if all[i].is_capture() {
            caps.push(all[i]);
        }
    }
    caps
}

#[inline]
fn capture_value(pos: &Position, m: Move) -> i32 {
    if m.is_ep() {
        PVAL[Piece::Pawn.index()]
    } else {
        match pos.piece_at(m.to()) {
            Some((_, p)) => PVAL[p.index()],
            None => 0,
        }
    }
}

#[inline]
fn mover_value(pos: &Position, m: Move) -> i32 {
    match pos.piece_at(m.from()) {
        Some((_, p)) => PVAL[p.index()],
        None => 0,
    }
}
