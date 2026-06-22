//! Variant rule tests: Three-check, King of the Hill, Atomic, Chess960.

use chess_core::{Color, Game, GameStatus, Piece, Position, Variant};

#[test]
fn three_check_wins_on_third_check() {
    let mut g = Game::from_fen("4k3/8/8/8/8/8/8/4KR2 w - - 0 1").unwrap();
    g.pos.variant = Variant::ThreeCheck;
    g.pos.checks = [2, 0]; // White has already delivered two checks
    let mv = g.pos.parse_uci("f1f8").unwrap(); // Rf8+ — the third check
    g.make_move(mv);
    assert_eq!(g.pos.checks, [3, 0]);
    assert_eq!(g.pos.variant_terminal(), Some(Color::White));
    assert_eq!(g.status(), GameStatus::VariantWin { winner: Color::White });
}

#[test]
fn three_check_counts_only_real_checks() {
    let mut g = Game::from_fen("4k3/8/8/8/8/8/8/4KR2 w - - 0 1").unwrap();
    g.pos.variant = Variant::ThreeCheck;
    let mv = g.pos.parse_uci("f1f2").unwrap(); // a quiet rook move — no check
    g.make_move(mv);
    assert_eq!(g.pos.checks, [0, 0]);
    assert_eq!(g.pos.variant_terminal(), None);
}

#[test]
fn koth_wins_when_king_reaches_centre() {
    let mut g = Game::from_fen("4k3/8/8/8/8/4K3/8/8 w - - 0 1").unwrap();
    g.pos.variant = Variant::KingOfTheHill;
    let mv = g.pos.parse_uci("e3e4").unwrap(); // Ke4 — onto the hill
    g.make_move(mv);
    assert_eq!(g.pos.variant_terminal(), Some(Color::White));
    assert_eq!(g.status(), GameStatus::VariantWin { winner: Color::White });
}

#[test]
fn koth_off_centre_is_ongoing() {
    let mut g = Game::from_fen("4k3/8/8/8/8/4K3/8/8 w - - 0 1").unwrap();
    g.pos.variant = Variant::KingOfTheHill;
    let mv = g.pos.parse_uci("e3f3").unwrap();
    g.make_move(mv);
    assert_eq!(g.pos.variant_terminal(), None);
}

#[test]
fn atomic_capture_explodes_adjacent_king() {
    // Rxd7 detonates: the captured rook, the capturing rook and the adjacent
    // black king (e8) are all removed → White wins.
    let mut g = Game::from_fen("4k3/3r4/8/8/8/8/8/3RK3 w - - 0 1").unwrap();
    g.pos.variant = Variant::Atomic;
    let mv = g.pos.parse_uci("d1d7").unwrap();
    g.make_move(mv);
    assert_eq!(g.pos.pieces(Color::Black, chess_core::Piece::King), 0);
    assert_eq!(g.pos.variant_terminal(), Some(Color::White));
    // Querying check for the side whose king is gone must not panic (this was
    // the source of the post-win UI freeze).
    assert!(!g.pos.in_check(Color::Black));
    assert_eq!(g.status(), GameStatus::VariantWin { winner: Color::White });
}

#[test]
fn atomic_unmake_restores_explosion() {
    let mut g = Game::from_fen("4k3/3r4/8/8/8/8/8/3RK3 w - - 0 1").unwrap();
    g.pos.variant = Variant::Atomic;
    let before = g.pos.clone();
    let mv = g.pos.parse_uci("d1d7").unwrap();
    let u = g.pos.make_move(mv);
    g.pos.unmake_move(mv, u);
    // Board fully restored (mailbox + occupancy) after the explosion is reversed.
    assert_eq!(g.pos.mailbox, before.mailbox);
    assert_eq!(g.pos.all, before.all);
    assert_eq!(g.pos.hash, before.hash);
}

#[test]
fn atomic_king_cannot_capture() {
    // White king on d1 beside a black rook on d2; in Atomic it may not capture
    // it (that would explode the king), so Kxd2 is not a legal move.
    let mut g = Game::from_fen("4k3/8/8/8/8/8/3r4/3K4 w - - 0 1").unwrap();
    g.pos.variant = Variant::Atomic;
    let legal = g.pos.generate_legal();
    // No legal move goes king d1 (3) → d2 (11) — capturing would explode the king.
    assert!(
        !(0..legal.len()).any(|i| legal[i].from() == 3 && legal[i].to() == 11),
        "king capture should be illegal in Atomic"
    );
    // The king can still step aside out of check.
    assert!(!legal.is_empty());
}

#[test]
fn chess960_index_518_is_standard() {
    let pos = Position::chess960(518); // Scharnagl index of the standard setup
    let expect = [
        Piece::Rook,
        Piece::Knight,
        Piece::Bishop,
        Piece::Queen,
        Piece::King,
        Piece::Bishop,
        Piece::Knight,
        Piece::Rook,
    ];
    for f in 0..8u8 {
        assert_eq!(pos.piece_at(f), Some((Color::White, expect[f as usize])));
        assert_eq!(pos.piece_at(56 + f), Some((Color::Black, expect[f as usize])));
    }
}

#[test]
fn chess960_castling_kingside() {
    // King e1, rooks a1/h1, flagged Chess960 via Shredder-FEN rook files.
    let mut g = Game::from_fen("4k3/8/8/8/8/8/8/R3K2R w HAha - 0 1").unwrap();
    assert_eq!(g.pos.variant, Variant::Chess960);
    let mv = g.pos.parse_uci("e1h1").unwrap(); // king-takes-rook encoding
    g.make_move(mv);
    assert_eq!(g.pos.piece_at(6), Some((Color::White, Piece::King))); // g1
    assert_eq!(g.pos.piece_at(5), Some((Color::White, Piece::Rook))); // f1
    assert_eq!(g.pos.piece_at(4), None);
    assert_eq!(g.pos.piece_at(7), None);
}

#[test]
fn chess960_castle_unmake_roundtrips() {
    let mut g = Game::from_fen("4k3/8/8/8/8/8/8/R3K2R w HAha - 0 1").unwrap();
    let before = g.pos.clone();
    let mv = g.pos.parse_uci("e1a1").unwrap(); // queenside king-takes-rook
    let u = g.pos.make_move(mv);
    assert_eq!(g.pos.piece_at(2), Some((Color::White, Piece::King))); // c1
    assert_eq!(g.pos.piece_at(3), Some((Color::White, Piece::Rook))); // d1
    g.pos.unmake_move(mv, u);
    assert_eq!(g.pos.mailbox, before.mailbox);
    assert_eq!(g.pos.hash, before.hash);
}

#[test]
fn chess960_xfen_roundtrips() {
    let pos = Position::chess960(350);
    let fen = chess_core::to_fen(&pos);
    let back = chess_core::parse_fen(&fen).unwrap();
    assert_eq!(back.variant, Variant::Chess960);
    assert_eq!(back.mailbox, pos.mailbox);
    assert_eq!(back.castle_rook_sq, pos.castle_rook_sq);
    assert_eq!(back.hash, pos.hash);
}

#[test]
fn crazyhouse_capture_fills_hand() {
    let mut g = Game::from_fen("4k3/8/8/3n4/8/4N3/8/4K3 w - - 0 1").unwrap();
    g.pos.variant = Variant::Crazyhouse;
    let m = g.pos.parse_uci("e3d5").unwrap(); // Nxd5
    g.make_move(m);
    assert_eq!(g.pos.hand[Color::White.index()][Piece::Knight.index()], 1);
}

#[test]
fn crazyhouse_drop_places_and_decrements() {
    let mut g = Game::from_fen("4k3/8/8/8/8/8/8/4K3 w - - 0 1").unwrap();
    g.pos.variant = Variant::Crazyhouse;
    g.pos.hand[Color::White.index()][Piece::Queen.index()] = 1;
    let m = g.pos.parse_uci("Q@e4").unwrap();
    g.make_move(m);
    assert_eq!(g.pos.piece_at(28), Some((Color::White, Piece::Queen))); // e4
    assert_eq!(g.pos.hand[Color::White.index()][Piece::Queen.index()], 0);
}

#[test]
fn crazyhouse_promoted_piece_reverts_to_pawn_when_taken() {
    // White promotes b7→b8=Q+ (marked promoted); Black's rook takes it and gains
    // a PAWN in hand, not a queen.
    let mut g = Game::from_fen("r3k3/1P6/8/8/8/8/8/4K3 w - - 0 1").unwrap();
    g.pos.variant = Variant::Crazyhouse;
    let promo = g.pos.parse_uci("b7b8q").unwrap();
    g.make_move(promo);
    assert!(g.pos.promoted & (1u64 << 57) != 0); // b8 marked promoted
    let take = g.pos.parse_uci("a8b8").unwrap(); // Rxb8
    g.make_move(take);
    assert_eq!(g.pos.hand[Color::Black.index()][Piece::Pawn.index()], 1);
    assert_eq!(g.pos.hand[Color::Black.index()][Piece::Queen.index()], 0);
}

#[test]
fn crazyhouse_no_pawn_drop_on_back_rank() {
    let mut g = Game::from_fen("4k3/8/8/8/8/8/8/4K3 w - - 0 1").unwrap();
    g.pos.variant = Variant::Crazyhouse;
    g.pos.hand[Color::White.index()][Piece::Pawn.index()] = 1;
    let legal = g.pos.generate_legal();
    // No drop targets a 1st- or 8th-rank square.
    for i in 0..legal.len() {
        let m = legal[i];
        if m.is_drop() {
            let r = m.to() / 8;
            assert!(r != 0 && r != 7, "pawn dropped on back rank");
        }
    }
}

#[test]
fn crazyhouse_drop_unmake_roundtrips() {
    let mut g = Game::from_fen("4k3/8/8/8/8/8/8/4K3 w - - 0 1").unwrap();
    g.pos.variant = Variant::Crazyhouse;
    g.pos.hand[Color::White.index()][Piece::Knight.index()] = 1;
    g.pos.hash = g.pos.compute_hash();
    let snap = g.pos.clone();
    let m = g.pos.parse_uci("N@e4").unwrap();
    let u = g.pos.make_move(m);
    assert_eq!(g.pos.piece_at(28), Some((Color::White, Piece::Knight)));
    g.pos.unmake_move(m, u);
    assert_eq!(g.pos.mailbox, snap.mailbox);
    assert_eq!(g.pos.hand, snap.hand);
    assert_eq!(g.pos.hash, snap.hash);
}

#[test]
fn crazyhouse_capture_unmake_roundtrips() {
    let mut g = Game::from_fen("4k3/8/8/3n4/8/4N3/8/4K3 w - - 0 1").unwrap();
    g.pos.variant = Variant::Crazyhouse;
    let before = g.pos.clone();
    let m = g.pos.parse_uci("e3d5").unwrap();
    let u = g.pos.make_move(m);
    g.pos.unmake_move(m, u);
    assert_eq!(g.pos.mailbox, before.mailbox);
    assert_eq!(g.pos.hand, before.hand);
    assert_eq!(g.pos.hash, before.hash);
}

#[test]
fn bughouse_capture_does_not_fill_own_hand() {
    // Unlike Crazyhouse, a Bughouse capture does NOT enter the capturer's hand —
    // the match layer passes it to the partner board.
    let mut g = Game::from_fen("4k3/8/8/3n4/8/4N3/8/4K3 w - - 0 1").unwrap();
    g.pos.variant = Variant::Bughouse;
    let m = g.pos.parse_uci("e3d5").unwrap(); // Nxd5
    g.make_move(m);
    assert_eq!(g.pos.hand, [[0; 5]; 2]);
}

#[test]
fn bughouse_give_to_hand_enables_drop_and_keeps_hash() {
    let mut g = Game::from_fen("4k3/8/8/8/8/8/8/4K3 w - - 0 1").unwrap();
    g.pos.variant = Variant::Bughouse;
    g.pos.add_to_hand(Color::White, Piece::Queen); // a piece passed from partner
    assert_eq!(g.pos.hand[Color::White.index()][Piece::Queen.index()], 1);
    assert_eq!(g.pos.hash, g.pos.compute_hash());
    let legal = g.pos.generate_legal();
    assert!((0..legal.len())
        .any(|i| legal[i].is_drop() && legal[i].dropped_piece() == Piece::Queen));
}

#[test]
fn bughouse_add_then_take_from_hand_roundtrips_hash() {
    let mut g = Game::from_fen("4k3/8/8/8/8/8/8/4K3 w - - 0 1").unwrap();
    g.pos.variant = Variant::Bughouse;
    let h0 = g.pos.hash;
    g.pos.add_to_hand(Color::Black, Piece::Rook);
    g.pos.take_from_hand(Color::Black, Piece::Rook);
    assert_eq!(g.pos.hash, h0);
    assert_eq!(g.pos.hand, [[0; 5]; 2]);
}

#[test]
fn bughouse_has_no_insufficient_material_draw() {
    let mut g = Game::from_fen("4k3/8/8/8/8/8/8/4K3 w - - 0 1").unwrap();
    g.pos.variant = Variant::Bughouse;
    assert_ne!(g.status(), GameStatus::DrawInsufficientMaterial);
}

#[test]
fn fog_moves_are_pseudo_legal() {
    // A pinned rook (e-file) may NOT leave the file in standard chess, but MAY in
    // Fog of War (no check concept).
    let mut g = Game::from_fen("4r2k/8/8/8/8/8/4R3/4K3 w - - 0 1").unwrap();
    let can_unpin = |g: &mut Game| {
        let legal = g.pos.generate_legal();
        (0..legal.len()).any(|i| legal[i].from() == 12 && legal[i].to() == 11) // e2→d2
    };
    assert!(!can_unpin(&mut g)); // standard: pinned
    g.pos.variant = Variant::FogOfWar;
    assert!(can_unpin(&mut g)); // fog: pseudo-legal
}

#[test]
fn fog_win_by_king_capture() {
    // White is "in check" but Fog of War has no check — it pushes a pawn; Black
    // then captures the white king and wins.
    let mut g = Game::from_fen("4k3/8/8/8/8/8/3Pr3/4K3 w - - 0 1").unwrap();
    g.pos.variant = Variant::FogOfWar;
    let m1 = g.pos.parse_uci("d2d3").unwrap();
    g.make_move(m1);
    assert_eq!(g.pos.variant_terminal(), None);
    let m2 = g.pos.parse_uci("e2e1").unwrap(); // Rxe1 captures the king
    g.make_move(m2);
    assert_eq!(g.pos.pieces(Color::White, Piece::King), 0);
    assert_eq!(g.pos.variant_terminal(), Some(Color::Black));
    assert_eq!(g.status(), GameStatus::VariantWin { winner: Color::Black });
}

#[test]
fn fog_generate_legal_after_king_capture_does_not_panic() {
    let mut g = Game::from_fen("4k3/8/8/8/8/8/3Pr3/4K3 w - - 0 1").unwrap();
    g.pos.variant = Variant::FogOfWar;
    let m1 = g.pos.parse_uci("d2d3").unwrap();
    g.make_move(m1);
    let m2 = g.pos.parse_uci("e2e1").unwrap();
    g.make_move(m2); // white king captured → white to move with no king
    let _ = g.pos.generate_legal(); // must not panic (gen_castling guards)
}

#[test]
fn fog_visibility_hides_distant_squares() {
    let g = Game::from_fen("4k3/8/8/8/8/8/8/4K3 w - - 0 1").unwrap();
    let vis = g.pos.visible_mask(Color::White);
    assert!(vis & (1u64 << 4) != 0); // e1 (own king)
    assert!(vis & (1u64 << 12) != 0); // e2 (a king move away)
    assert!(vis & (1u64 << 60) == 0); // e8 (the enemy king) — hidden
}
