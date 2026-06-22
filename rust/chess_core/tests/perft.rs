//! Perft correctness gate. Run in release for speed: `cargo test -p chess_core --release`.

use chess_core::{parse_fen, perft, START_FEN};

const KIWIPETE: &str = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1";
const POS3: &str = "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1";
const POS4: &str = "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1";
const POS5: &str = "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8";
const POS6: &str = "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10";

fn run(fen: &str, expected: &[u64]) {
    let mut pos = parse_fen(fen).unwrap();
    for (i, &n) in expected.iter().enumerate() {
        let depth = i as u32 + 1;
        assert_eq!(perft(&mut pos, depth), n, "fen `{fen}` depth {depth}");
    }
}

#[test]
fn perft_startpos() {
    run(START_FEN, &[20, 400, 8902, 197281, 4865609]);
}

#[test]
fn perft_kiwipete() {
    run(KIWIPETE, &[48, 2039, 97862, 4085603]);
}

#[test]
fn perft_position3() {
    run(POS3, &[14, 191, 2812, 43238, 674624]);
}

#[test]
fn perft_position4() {
    run(POS4, &[6, 264, 9467, 422333]);
}

#[test]
fn perft_position5() {
    run(POS5, &[44, 1486, 62379, 2103487]);
}

#[test]
fn perft_position6() {
    run(POS6, &[46, 2079, 89890, 3894594]);
}

#[test]
fn perft5_startpos_timing() {
    // Timing is only meaningful in an optimised build.
    if cfg!(debug_assertions) {
        return;
    }
    let mut pos = parse_fen(START_FEN).unwrap();
    let t = std::time::Instant::now();
    let n = perft(&mut pos, 5);
    let dt = t.elapsed();
    assert_eq!(n, 4865609);
    assert!(dt.as_secs_f64() < 1.0, "perft(5) took {dt:?}, target < 1s");
}
