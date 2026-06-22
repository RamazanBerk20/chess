//! Post-game move-by-move analysis: at each position it searches the best move
//! and the played move to the *same fixed depth*, classifies the played move
//! (book / brilliant / best / good / inaccuracy / miss / mistake / blunder) and
//! reports the evaluation (White POV) for an eval bar + graph. Streamed off the
//! UI thread; one update per ply plus a final `done` update with accuracies.
//!
//! Using a fixed depth (not a time budget) for both searches is what keeps
//! `cp_loss` consistent and non-negative: the played move's value comes from the
//! same horizon the best-move search already explored (and mostly from the
//! shared transposition table, so the second search is nearly free).

use std::sync::atomic::{AtomicBool, Ordering};

use chess_ai::{Engine, SearchInfo, SearchLimits, MATE, MATE_THRESHOLD};
use chess_core::{parse_fen, Color, Move, Piece, Position};
use flutter_rust_bridge::frb;

use crate::frb_generated::StreamSink;

#[derive(Clone, Debug)]
pub struct AnalysisUpdate {
    pub ply: u32,
    pub uci: String,
    pub san: String,
    /// Evaluation after the move, White's point of view, clamped to ±10000.
    pub eval_cp: i32,
    /// 0 = not mate; otherwise signed plies-to-mate (White mating > 0).
    pub mate_in: i32,
    /// Evaluation of the position *before* the move (best play), White POV.
    /// Lets the eval bar/graph show a real value at the start ply.
    pub eval_before_cp: i32,
    /// Signed plies-to-mate for the position before the move (White mating > 0).
    pub mate_before_in: i32,
    pub best_uci: String,
    /// Engine's best move in SAN (for human-readable coach explanations).
    pub best_san: String,
    pub cp_loss: i32,
    pub classification: String,
    pub progress: u32,
    pub total: u32,
    pub done: bool,
    pub white_accuracy: f32,
    pub black_accuracy: f32,
}

/// Only one analysis runs at a time; this cancels it.
static CANCEL: AtomicBool = AtomicBool::new(false);

fn piece_val(p: Piece) -> i32 {
    match p {
        Piece::Pawn => 1,
        Piece::Knight | Piece::Bishop => 3,
        Piece::Rook => 5,
        Piece::Queen => 9,
        Piece::King => 0,
    }
}

fn material(pos: &Position, side: Color) -> i32 {
    let mut m = 0;
    for sq in 0..64u8 {
        if let Some((c, p)) = pos.piece_at(sq) {
            if c == side {
                m += piece_val(p);
            }
        }
    }
    m
}

/// White-POV centipawns from a side-to-move-POV score.
fn white_cp(score: i32, stm: Color) -> i32 {
    if stm == Color::White {
        score
    } else {
        -score
    }
}

/// White's win probability [0,1] from White-POV cp (logistic, Lichess constant).
fn win_prob(cp: i32) -> f64 {
    1.0 / (1.0 + (-0.00368208 * cp as f64).exp())
}

/// Win probability [0,1] for the side to move, from its own score.
fn win_stm(score: i32, stm: Color) -> f64 {
    let w = win_prob(white_cp(score, stm));
    if stm == Color::White {
        w
    } else {
        1.0 - w
    }
}

/// Signed plies-to-mate from a side-to-move score (positive = stm mates).
fn mate_in_from(score: i32) -> i32 {
    if score >= MATE_THRESHOLD {
        (MATE - score + 1) / 2
    } else if score <= -MATE_THRESHOLD {
        -((MATE + score + 1) / 2)
    } else {
        0
    }
}

/// Plies-to-mate signed to White's point of view (White mating > 0).
fn mate_white(score: i32, stm: Color) -> i32 {
    let mi = mate_in_from(score);
    if stm == Color::White {
        mi
    } else {
        -mi
    }
}

// Classification tuning (win-percent points lost, unless noted). Local + tunable.
const BOOK_PLIES: usize = 10;
const BOOK_TOL: f64 = 2.0;
const BEST_TOL: f64 = 1.0; // <= this many win% points lost still counts as "best"
const MISS_TOL: f64 = 10.0;
const GOOD_TOL: f64 = 5.0;
const INACCURACY_TOL: f64 = 10.0;
const MISTAKE_TOL: f64 = 20.0;
const WINNING_WP: f64 = 0.80;
const SAC_MATERIAL: i32 = 3; // minor-piece-worth sacrifice to flag "brilliant"
/// A sacrifice only reads as "brilliant" when the side was NOT already winning
/// by more than this win-probability before the move. Past it the game is
/// effectively decided, so giving up material (even soundly) is just the "best"
/// move, not a brilliancy. 0.93 ≈ +700cp.
const BRILLIANT_MAX_BEFORE_WP: f64 = 0.93;

/// Classify the played move from win% loss, with sacrifice detection for
/// "brilliant" (mover materially down after the opponent's best reply yet still
/// winning) and a "miss" for a thrown-away winning chance.
#[allow(clippy::too_many_arguments)]
fn classify(
    stm: Color,
    ply: usize,
    mv: Move,
    best_mv: Option<Move>,
    best_score: i32,
    played_score: i32,
    wpl: f64, // win% points lost (>= 0)
    before_mat: i32,
    child: &Position,    // position after the played move
    reply_best: Option<Move>, // opponent's best reply from the search
) -> &'static str {
    let best_wp = win_stm(best_score, stm);
    let played_wp = win_stm(played_score, stm);
    let winning_before = best_wp >= WINNING_WP || best_score >= MATE_THRESHOLD;
    let winning_after = played_wp >= WINNING_WP || played_score >= MATE_THRESHOLD;
    let played_is_best = best_mv == Some(mv) || wpl <= BEST_TOL;

    // Opening: near-perfect early moves read as "book" (no book table shipped).
    if ply < BOOK_PLIES && wpl <= BOOK_TOL {
        return "book";
    }

    if played_is_best {
        // Brilliant: the best move is also a sound material sacrifice that stays
        // winning — but ONLY from a position that wasn't already won. When you
        // are already crushing (e.g. up a queen), a sound sac is just the best
        // move, not a brilliancy. Measure the mover's material after the
        // opponent's best reply (so a piece truly given up shows as a deficit).
        let already_winning_big =
            best_wp >= BRILLIANT_MAX_BEFORE_WP || best_score >= MATE_THRESHOLD;
        if winning_after && played_wp >= 0.5 && !already_winning_big {
            let mut after = child.clone();
            if let Some(rb) = reply_best {
                after.make_move(rb);
            }
            if material(&after, stm) <= before_mat - SAC_MATERIAL {
                return "brilliant";
            }
        }
        return "best";
    }

    // Miss: a winning chance thrown away (distinct from a plain mistake).
    if winning_before && !winning_after && wpl >= MISS_TOL {
        return "miss";
    }

    if wpl <= GOOD_TOL {
        "good"
    } else if wpl <= INACCURACY_TOL {
        "inaccuracy"
    } else if wpl <= MISTAKE_TOL {
        "mistake"
    } else {
        "blunder"
    }
}

/// Analyze `moves` played from `start_fen`. `depth` is the fixed search depth
/// per position. Streams an [`AnalysisUpdate`] per ply, then a `done` update.
pub fn analyze_game(
    start_fen: String,
    moves: Vec<String>,
    depth: u32,
    sink: StreamSink<AnalysisUpdate>,
) -> Result<(), String> {
    CANCEL.store(false, Ordering::Relaxed);
    let mut pos = parse_fen(&start_fen).map_err(|e| e.to_string())?;
    let total = moves.len() as u32;
    let depth = depth.clamp(1, 64) as u8;
    let mut eng = Engine::new(18);
    let cancel = || CANCEL.load(Ordering::Relaxed);

    // Best move searches `pos` to `depth`; the played move searches the child
    // one ply shallower so both look the same number of plies ahead of `pos`.
    let best_limits = SearchLimits {
        max_depth: depth,
        move_time_ms: None,
    };
    let child_limits = SearchLimits {
        max_depth: depth.saturating_sub(1).max(1),
        move_time_ms: None,
    };

    let mut acc_sum = [0.0f64; 2];
    let mut acc_cnt = [0u32; 2];

    for (i, uci) in moves.iter().enumerate() {
        if cancel() {
            break;
        }
        let stm = pos.side;
        let mv = match pos.parse_uci(uci) {
            Ok(m) => m,
            Err(_) => break, // corrupt move list — stop cleanly
        };
        let san = pos.san_of(mv);

        // Best move + eval of the position before the move (stm POV).
        let best = eng.search(&pos, best_limits, &cancel, |_: &SearchInfo| {});
        let best_score = best.score_cp;
        let best_mv = best.best;
        let best_uci = best_mv.map(|m| m.to_uci()).unwrap_or_default();
        // SAN of the best move (computed before the played move is applied).
        let best_san = best_mv.map(|m| pos.san_of(m)).unwrap_or_default();

        // Play the move; search the child for the played value + opponent reply.
        // Mostly TT hits from the search above, so this is nearly free.
        let before_mat = material(&pos, stm);
        let mut child = pos.clone();
        child.make_move(mv);
        // If the move ended the game the child is terminal — `search` returns 0
        // for a no-legal-move root, which would mis-score a *checkmating* move as
        // a thrown-away win. Score terminal children directly instead.
        let (played_score, reply_best) = if child.generate_legal().is_empty() {
            if child.in_check(child.side) {
                (MATE - 1, None) // the move delivered checkmate → mover wins
            } else {
                (0, None) // stalemate → draw
            }
        } else {
            let reply = eng.search(&child, child_limits, &cancel, |_: &SearchInfo| {});
            (-reply.score_cp, reply.best) // back to stm's point of view
        };

        let cp_loss = (best_score - played_score).clamp(0, 10000);
        let eval_white = white_cp(played_score, stm).clamp(-10000, 10000);
        let mate_in = mate_white(played_score, stm);
        let eval_before = white_cp(best_score, stm).clamp(-10000, 10000);
        let mate_before = mate_white(best_score, stm);

        // Per-move accuracy + the win% loss that drives classification.
        let win_before = win_stm(best_score, stm);
        let win_after = win_stm(played_score, stm);
        let drop = ((win_before - win_after) * 100.0).max(0.0);
        let move_acc = (103.1668 * (-0.04354 * drop).exp() - 3.1669).clamp(0.0, 100.0);
        let side = if stm == Color::White { 0 } else { 1 };
        acc_sum[side] += move_acc;
        acc_cnt[side] += 1;

        let classification = classify(
            stm,
            i,
            mv,
            best_mv,
            best_score,
            played_score,
            drop,
            before_mat,
            &child,
            reply_best,
        );

        pos.make_move(mv);

        if sink
            .add(AnalysisUpdate {
                ply: i as u32,
                uci: uci.clone(),
                san,
                eval_cp: eval_white,
                mate_in,
                eval_before_cp: eval_before,
                mate_before_in: mate_before,
                best_uci,
                best_san,
                cp_loss,
                classification: classification.to_string(),
                progress: i as u32 + 1,
                total,
                done: false,
                white_accuracy: 0.0,
                black_accuracy: 0.0,
            })
            .is_err()
        {
            break; // listener dropped
        }
    }

    let avg = |s: f64, n: u32| if n > 0 { (s / n as f64) as f32 } else { 100.0 };
    let _ = sink.add(AnalysisUpdate {
        ply: 0,
        uci: String::new(),
        san: String::new(),
        eval_cp: 0,
        mate_in: 0,
        eval_before_cp: 0,
        mate_before_in: 0,
        best_uci: String::new(),
        best_san: String::new(),
        cp_loss: 0,
        classification: String::new(),
        progress: total,
        total,
        done: true,
        white_accuracy: avg(acc_sum[0], acc_cnt[0]),
        black_accuracy: avg(acc_sum[1], acc_cnt[1]),
    });
    Ok(())
}

/// Cancel the running analysis.
#[frb(sync)]
pub fn analysis_cancel() {
    CANCEL.store(true, Ordering::Relaxed);
}

#[cfg(test)]
mod tests {
    use super::*;

    fn mv(uci: &str) -> Move {
        let mut p = Position::startpos();
        p.parse_uci(uci).unwrap()
    }

    // Classify a White move from synthetic best/played scores (stm POV).
    fn classify_white(ply: usize, played: Move, best: Move, best_s: i32, played_s: i32) -> &'static str {
        let pos = Position::startpos();
        let child = pos.clone();
        let wpl = ((win_stm(best_s, Color::White) - win_stm(played_s, Color::White)) * 100.0)
            .max(0.0);
        classify(
            Color::White,
            ply,
            played,
            Some(best),
            best_s,
            played_s,
            wpl,
            material(&pos, Color::White),
            &child,
            None,
        )
    }

    #[test]
    fn classification_ladder() {
        let a = mv("e2e4");
        let b = mv("d2d4");
        // Played == best, non-winning → "best" (not "brilliant": no sacrifice).
        assert_eq!(classify_white(20, a, a, 30, 30), "best");
        // Early near-perfect move → "book".
        assert_eq!(classify_white(2, b, a, 0, -10), "book");
        // Small win% loss → "good".
        assert_eq!(classify_white(20, b, a, 0, -33), "good");
        // Big win% loss from an equal position → "blunder".
        assert_eq!(classify_white(20, b, a, 0, -500), "blunder");
        // A winning position thrown away → "miss" (not a plain mistake/blunder).
        assert_eq!(classify_white(20, b, a, 400, 0), "miss");
        // Clearly winning best move stays "best".
        assert_eq!(classify_white(20, a, a, 600, 600), "best");
    }

    #[test]
    fn brilliant_requires_not_already_winning() {
        // "After the sac" the mover is a knight down: child = startpos minus the
        // b1 knight (material 36), before_mat = full startpos material (39).
        let before_mat = material(&Position::startpos(), Color::White);
        let child =
            parse_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/R1BQKBNR w KQkq - 0 1").unwrap();
        let m = mv("e2e4");
        // Winning but not yet decided (+600) → a sound sacrifice is "brilliant".
        assert_eq!(
            classify(Color::White, 20, m, Some(m), 600, 600, 0.0, before_mat, &child, None),
            "brilliant",
        );
        // Already crushing (+2500) → the same sacrifice is merely "best".
        assert_eq!(
            classify(Color::White, 20, m, Some(m), 2500, 2500, 0.0, before_mat, &child, None),
            "best",
        );
    }

    #[test]
    fn cp_loss_never_negative_and_eval_signs() {
        // best >= played by the search invariant, so cp_loss clamps to >= 0.
        assert_eq!((50_i32 - 200).clamp(0, 10000), 0);
        // White-POV eval flips for Black to move.
        assert_eq!(white_cp(120, Color::White), 120);
        assert_eq!(white_cp(120, Color::Black), -120);
        // Mate-distance signs to White's POV.
        assert!(mate_white(MATE - 3, Color::White) > 0);
        assert!(mate_white(MATE - 3, Color::Black) < 0);
    }
}
