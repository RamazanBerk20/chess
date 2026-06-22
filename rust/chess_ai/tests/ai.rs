//! AI sanity tests: finds forced mates, never returns an illegal move,
//! respects the time budget and cancellation.

use std::time::Instant;

use chess_ai::{evaluate, AiConfig, Engine, SearchInfo, SearchLimits, MATE_THRESHOLD};
use chess_core::{parse_fen, Position};

fn no_cancel() -> bool {
    false
}

fn search_fen(fen: &str, depth: u8) -> SearchInfo {
    let pos = parse_fen(fen).unwrap();
    let mut eng = Engine::new(16);
    let cancel: &dyn Fn() -> bool = &no_cancel;
    eng.search(
        &pos,
        SearchLimits {
            max_depth: depth,
            move_time_ms: None,
        },
        cancel,
        |_: &SearchInfo| {},
    )
}

#[test]
fn finds_mate_in_one() {
    // Ra8# — Black king boxed in by its own f7/g7/h7 pawns.
    let info = search_fen("6k1/5ppp/8/8/8/8/8/R6K w - - 0 1", 3);
    assert_eq!(info.best.unwrap().to_uci(), "a1a8");
    assert!(info.score_cp >= MATE_THRESHOLD, "score {}", info.score_cp);
}

#[test]
fn finds_mate_in_two_smothered() {
    // 1.Qg8+!! Rxg8 2.Nf7# (Philidor's smothered mate, truncated to two moves).
    let info = search_fen("5r1k/6pp/7N/8/8/1Q6/8/6K1 w - - 0 1", 5);
    assert_eq!(info.best.unwrap().to_uci(), "b3g8");
    assert!(info.score_cp >= MATE_THRESHOLD, "score {}", info.score_cp);
}

#[test]
fn never_returns_illegal_move() {
    let mut pos = Position::startpos();
    let info = search_fen(&chess_core::to_fen(&pos), 4);
    let mv = info.best.unwrap();
    let legal = pos.generate_legal();
    assert!(
        (0..legal.len()).any(|i| legal[i] == mv),
        "engine returned illegal move {}",
        mv.to_uci()
    );
}

#[test]
fn respects_time_budget() {
    let pos = Position::startpos();
    let mut eng = Engine::new(18);
    let cancel: &dyn Fn() -> bool = &no_cancel;
    let t = Instant::now();
    let info = eng.search(
        &pos,
        SearchLimits {
            max_depth: 99,
            move_time_ms: Some(100),
        },
        cancel,
        |_: &SearchInfo| {},
    );
    let dt = t.elapsed();
    assert!(info.best.is_some());
    assert!(dt.as_millis() < 1500, "overran budget: {dt:?}");
}

#[test]
fn cancellation_returns_quickly_with_a_move() {
    let pos = Position::startpos();
    let mut eng = Engine::new(18);
    let always_cancel = || true;
    let cancel: &dyn Fn() -> bool = &always_cancel;
    let t = Instant::now();
    let info = eng.search(
        &pos,
        SearchLimits {
            max_depth: 99,
            move_time_ms: None,
        },
        cancel,
        |_: &SearchInfo| {},
    );
    assert!(info.best.is_some());
    assert!(t.elapsed().as_millis() < 1000);
}

fn search_with_hist(p0: &Position, hist: &[u64], depth: u8) -> SearchInfo {
    let mut eng = Engine::new(16);
    eng.set_game_history(hist);
    let cancel: &dyn Fn() -> bool = &no_cancel;
    eng.search(
        p0,
        SearchLimits {
            max_depth: depth,
            move_time_ms: None,
        },
        cancel,
        |_: &SearchInfo| {},
    )
}

#[test]
fn avoids_threefold_when_winning() {
    // White is up a rook. The position after Rh1-h2 has ALREADY occurred twice,
    // so reaching it again is a real threefold draw — the engine must avoid it.
    let p0 = parse_fen("k7/8/2K5/8/8/8/8/7R w - - 0 1").unwrap();
    let mut probe = p0.clone();
    let mv = probe.parse_uci("h1h2").unwrap();
    probe.make_move(mv);
    let rep_hash = probe.hash;

    let info = search_with_hist(&p0, &[rep_hash, rep_hash], 5);
    assert_ne!(info.best.unwrap().to_uci(), "h1h2");
    assert!(info.score_cp > 0, "should still see it is winning");
}

#[test]
fn single_prior_occurrence_is_not_a_draw() {
    // A position seen only ONCE before must NOT be scored as a draw (would
    // require a third occurrence). The engine should still see it is winning.
    let p0 = parse_fen("k7/8/2K5/8/8/8/8/7R w - - 0 1").unwrap();
    let mut probe = p0.clone();
    let mv = probe.parse_uci("h1h2").unwrap();
    probe.make_move(mv);
    let info = search_with_hist(&p0, &[probe.hash], 5);
    assert!(info.score_cp > 300, "winning, not a false draw: {}", info.score_cp);
}

#[test]
fn eval_startpos_is_balanced() {
    let pos = Position::startpos();
    assert!(evaluate(&pos).abs() < 60);
}

fn best_with_config(pos: &Position, cfg: AiConfig) -> String {
    let mut eng = Engine::new(16);
    let cancel: &dyn Fn() -> bool = &no_cancel;
    eng.search_with_config(pos, cfg, cancel, |_: &SearchInfo| {})
        .best
        .unwrap()
        .to_uci()
}

#[test]
fn weakening_is_reproducible_for_a_fixed_seed() {
    let pos = Position::startpos();
    let cfg = AiConfig {
        max_depth: 4,
        move_time_ms: None,
        eval_noise: 60,
        blunder_chance: 0.3,
        top_n_random: 4,
        contempt: 0,
        seed: 12345,
    };
    assert_eq!(best_with_config(&pos, cfg), best_with_config(&pos, cfg));
}

#[test]
fn contempt_sign_is_draw_averse_at_root() {
    // halfmove=99: every White move makes it 100 → a 50-move draw at ply 1 (an
    // odd ply, where a flat `-contempt` would invert). Positive contempt (draw
    // aversion) must score the forced draw as -contempt from the root's POV.
    let pos = parse_fen("k7/8/K7/8/8/8/8/Q7 w - - 99 100").unwrap();
    let run = |contempt: i32| {
        let mut eng = Engine::new(16);
        let cancel: &dyn Fn() -> bool = &no_cancel;
        let cfg = AiConfig {
            max_depth: 3,
            move_time_ms: None,
            eval_noise: 0,
            blunder_chance: 0.0,
            top_n_random: 1,
            contempt,
            seed: 0,
        };
        eng.search_with_config(&pos, cfg, cancel, |_: &SearchInfo| {}).score_cp
    };
    assert_eq!(run(100), -100);
    assert_eq!(run(-50), 50);
}

#[test]
fn full_strength_config_matches_plain_search() {
    let pos = Position::startpos();
    let cfg = AiConfig {
        max_depth: 5,
        move_time_ms: None,
        eval_noise: 0,
        blunder_chance: 0.0,
        top_n_random: 1,
        contempt: 0,
        seed: 0,
    };
    let weak = best_with_config(&pos, cfg);
    let plain = search_fen(&chess_core::to_fen(&pos), 5).best.unwrap().to_uci();
    assert_eq!(weak, plain);
}

#[test]
fn fog_of_war_search_does_not_panic() {
    // In Fog of War the search explores king captures (no check filter); the PV
    // walk and move generation must not panic on a king-captured node.
    let mut pos = parse_fen(chess_core::START_FEN).unwrap();
    pos.variant = chess_core::Variant::FogOfWar;
    let mut eng = Engine::new(16);
    let cancel: &dyn Fn() -> bool = &no_cancel;
    let info = eng.search(
        &pos,
        SearchLimits { max_depth: 6, move_time_ms: None },
        cancel,
        |_: &SearchInfo| {},
    );
    assert!(info.best.is_some());
}
