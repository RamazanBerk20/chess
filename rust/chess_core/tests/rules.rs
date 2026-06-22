//! Unit tests for FEN/SAN/UCI round-trips, special moves, Zobrist consistency
//! and termination/draw detection.

use chess_core::{parse_fen, to_fen, Color, Game, GameStatus, Position, START_FEN};

const KIWIPETE: &str = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1";
const POS3: &str = "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1";

#[test]
fn fen_roundtrip() {
    for fen in [START_FEN, KIWIPETE, POS3] {
        let p = parse_fen(fen).unwrap();
        assert_eq!(to_fen(&p), fen, "round-trip mismatch for {fen}");
    }
}

// Walk the legal-move tree, verifying SAN and UCI both round-trip to the same move.
fn notation_roundtrip(pos: &mut Position, depth: u32) {
    let list = pos.generate_legal();
    for i in 0..list.len() {
        let mv = list[i];
        let san = pos.san_of(mv);
        assert_eq!(pos.parse_san(&san).unwrap(), mv, "SAN `{san}`");
        let uci = mv.to_uci();
        assert_eq!(pos.parse_uci(&uci).unwrap(), mv, "UCI `{uci}`");
        if depth > 0 {
            let u = pos.make_move(mv);
            notation_roundtrip(pos, depth - 1);
            pos.unmake_move(mv, u);
        }
    }
}

#[test]
fn san_uci_roundtrip() {
    let mut p = Position::startpos();
    notation_roundtrip(&mut p, 2);
    let mut k = parse_fen(KIWIPETE).unwrap();
    notation_roundtrip(&mut k, 1);
}

// Verify incremental Zobrist hashing matches a from-scratch recompute everywhere.
fn hash_dfs(pos: &mut Position, depth: u32) {
    assert_eq!(pos.hash, pos.compute_hash());
    if depth == 0 {
        return;
    }
    let list = pos.generate_legal();
    for i in 0..list.len() {
        let mv = list[i];
        let u = pos.make_move(mv);
        hash_dfs(pos, depth - 1);
        pos.unmake_move(mv, u);
        assert_eq!(pos.hash, pos.compute_hash());
    }
}

#[test]
fn zobrist_consistency() {
    let mut p = Position::startpos();
    hash_dfs(&mut p, 3);
}

#[test]
fn en_passant() {
    let mut p =
        parse_fen("rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 3").unwrap();
    let mv = p.parse_uci("e5d6").unwrap();
    assert!(mv.is_ep());
    p.make_move(mv);
    assert_eq!(
        to_fen(&p),
        "rnbqkbnr/ppp1pppp/3P4/8/8/8/PPPP1PPP/RNBQKBNR b KQkq - 0 3"
    );
}

#[test]
fn castling_kingside() {
    let mut p = parse_fen("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1").unwrap();
    let mv = p.parse_uci("e1g1").unwrap();
    assert!(mv.is_castle());
    p.make_move(mv);
    assert_eq!(to_fen(&p), "r3k2r/8/8/8/8/8/8/R4RK1 b kq - 1 1");
}

#[test]
fn castling_queenside_and_unmake() {
    let mut p = parse_fen("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1").unwrap();
    let mv = p.parse_uci("e1c1").unwrap();
    let u = p.make_move(mv);
    assert_eq!(to_fen(&p), "r3k2r/8/8/8/8/8/8/2KR3R b kq - 1 1");
    p.unmake_move(mv, u);
    assert_eq!(to_fen(&p), "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1");
}

#[test]
fn promotion() {
    let mut p = parse_fen("8/P7/8/8/8/8/8/k6K w - - 0 1").unwrap();
    let mv = p.parse_uci("a7a8q").unwrap();
    assert!(mv.is_promotion());
    p.make_move(mv);
    assert_eq!(to_fen(&p), "Q7/8/8/8/8/8/8/k6K b - - 0 1");
}

#[test]
fn fools_mate() {
    let mut g = Game::new();
    for uci in ["f2f3", "e7e5", "g2g4", "d8h4"] {
        let mv = g.pos.parse_uci(uci).unwrap();
        g.make_move(mv);
    }
    assert_eq!(
        g.status(),
        GameStatus::Checkmate {
            winner: Color::Black
        }
    );
}

#[test]
fn stalemate() {
    let mut g = Game::from_fen("7k/5Q2/6K1/8/8/8/8/8 b - - 0 1").unwrap();
    assert_eq!(g.status(), GameStatus::Stalemate);
}

#[test]
fn insufficient_material() {
    assert!(Game::from_fen("8/8/8/4k3/8/8/4K3/8 w - - 0 1")
        .unwrap()
        .is_insufficient_material());
    assert!(Game::from_fen("8/8/8/4k3/8/8/4KB2/8 w - - 0 1")
        .unwrap()
        .is_insufficient_material());
    assert!(Game::from_fen("8/8/8/4k3/8/8/4KN2/8 w - - 0 1")
        .unwrap()
        .is_insufficient_material());
    assert!(!Game::from_fen("8/8/8/4k3/8/8/3QK3/8 w - - 0 1")
        .unwrap()
        .is_insufficient_material());
}

#[test]
fn threefold_repetition() {
    let mut g = Game::new();
    for uci in [
        "g1f3", "g8f6", "f3g1", "f6g8", "g1f3", "g8f6", "f3g1", "f6g8",
    ] {
        let mv = g.pos.parse_uci(uci).unwrap();
        g.make_move(mv);
    }
    assert_eq!(g.status(), GameStatus::DrawThreefold);
}

#[test]
fn fifty_move_rule() {
    // Halfmove clock already at 100 → claimable/auto draw.
    let mut g = Game::from_fen("8/8/8/3k4/8/3K4/8/6R1 w - - 100 80").unwrap();
    assert_eq!(g.status(), GameStatus::DrawFiftyMove);
}

#[test]
fn startpos_has_twenty_moves() {
    let mut p = Position::startpos();
    assert_eq!(p.generate_legal().len(), 20);
}

// --- Regression tests for the chess-core-verify workflow findings ---

#[test]
fn phantom_ep_not_recorded() {
    // a2a4 with no enemy pawn adjacent must NOT set an ep target.
    let mut p = Position::startpos();
    let mv = p.parse_uci("a2a4").unwrap();
    p.make_move(mv);
    assert!(p.ep.is_none());
    assert_eq!(
        to_fen(&p),
        "rnbqkbnr/pppppppp/8/8/P7/8/1PPPPPPP/RNBQKBNR b KQkq - 0 1"
    );
}

#[test]
fn real_ep_is_preserved() {
    // Black pawn on b4 can capture a3, so the ep target must be kept.
    let mut p = parse_fen("4k3/8/8/8/1p6/8/P7/4K3 w - - 0 1").unwrap();
    let mv = p.parse_uci("a2a4").unwrap();
    p.make_move(mv);
    assert!(to_fen(&p).contains(" a3 "), "fen: {}", to_fen(&p));
    let moves = p.generate_legal();
    assert!((0..moves.len()).any(|i| moves[i].is_ep()));
}

#[test]
fn phantom_ep_threefold_detected() {
    // Previously the phantom ep after a2a4 hashed differently and the threefold
    // was missed. Board T (white pawn a4, knights home, black to move) recurs 3x.
    let mut g = Game::new();
    for uci in [
        "a2a4", "g8f6", "g1f3", "f6g8", "f3g1", "g8f6", "g1f3", "f6g8", "f3g1",
    ] {
        let mv = g.pos.parse_uci(uci).unwrap();
        g.make_move(mv);
    }
    assert_eq!(g.status(), GameStatus::DrawThreefold);
}

#[test]
fn malformed_fen_rejected() {
    assert!(parse_fen("8/8/8/8/8/8/8/4K3 w - - 0 1").is_err()); // no black king
    assert!(parse_fen("4k3/8/8/8/8/8/8/RK2K3 w - - 0 1").is_err()); // two white kings
    assert!(parse_fen("4k3/8/8/8/8/8/4R3/4K3 w - - 0 1").is_err()); // side not to move in check
    assert!(parse_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQKQ - 0 1").is_err()); // dup castling
}

#[test]
fn castling_rights_require_pieces_home() {
    // King/rook absent or off its home square → those rights are stripped (the
    // FEN still parses, mirroring the ep normalisation) so movegen can't trust a
    // phantom right. WK=0b0001, WQ=0b0010, BK=0b0100, BQ=0b1000.
    assert_eq!(parse_fen("4k3/8/8/8/8/8/8/4K3 w KQkq - 0 1").unwrap().castling.0, 0); // no rooks
    assert_eq!(parse_fen("4k3/8/8/8/8/8/8/1R2KR2 w KQ - 0 1").unwrap().castling.0, 0); // off corners
    // White intact (e1 king, a1/h1 rooks); black has no rooks → black rights gone.
    assert_eq!(parse_fen("4k3/8/8/8/8/8/8/R3K2R w KQq - 0 1").unwrap().castling.0, 0b0011);
    // Fully valid setup keeps all four.
    assert_eq!(parse_fen("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1").unwrap().castling.0, 0b1111);
}

#[test]
fn impossible_ep_normalized() {
    // ep e4 with White to move and no capturing pawn → normalized to None, still parses.
    let p = parse_fen("4k3/8/8/8/8/8/8/4K3 w - e4 0 1").unwrap();
    assert!(p.ep.is_none());
}

#[test]
fn parse_uci_non_ascii_errs() {
    let mut p = Position::startpos();
    assert!(p.parse_uci("aée4").is_err()); // multibyte must Err, not panic
    assert!(p.parse_uci("𝕒2e4").is_err());
}

#[test]
fn parse_san_lenient() {
    let mut p = parse_fen("4k3/P7/8/8/8/8/8/4K3 w - - 0 1").unwrap();
    let canon = p.parse_uci("a7a8q").unwrap();
    for s in ["a8=Q", "a8=q", "a8Q", "a8q", "a8=Q+"] {
        assert_eq!(p.parse_san(s).unwrap(), canon, "san `{s}`");
    }
    let mut c = parse_fen("4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1").unwrap();
    let oo = c.parse_uci("e1g1").unwrap();
    assert_eq!(c.parse_san("O-O").unwrap(), oo);
    assert_eq!(c.parse_san("0-0").unwrap(), oo);
    let ooo = c.parse_uci("e1c1").unwrap();
    assert_eq!(c.parse_san("0-0-0").unwrap(), ooo);
}
