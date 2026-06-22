use chess4::board::{in_bounds, is_promo_square, Board, N, VALID};
use chess4::{Coord, Format, FourGame, FourResult, Move4, Piece, Player, PlayerStatus, Team};

fn at(g: &FourGame, c: i8, r: i8) -> Option<(Player, Piece)> {
    g.board.get(c, r)
}

#[test]
fn valid_mask_is_a_cross() {
    let valid = VALID.iter().filter(|&&v| v).count();
    assert_eq!(valid, 160);
    assert_eq!(N - valid, 36);
    assert!(!in_bounds(0, 0)); // cut corner
    assert!(!in_bounds(13, 13));
    assert!(in_bounds(7, 0)); // Red back rank
    assert!(in_bounds(0, 7)); // Blue back rank
}

#[test]
fn start_position_is_correct() {
    let b = Board::start();
    assert_eq!(b.cells.iter().filter(|c| c.is_some()).count(), 64);
    assert_eq!(b.get(7, 0), Some((Player::Red, Piece::King)));
    assert_eq!(b.get(6, 0), Some((Player::Red, Piece::Queen)));
    assert_eq!(b.get(0, 7), Some((Player::Blue, Piece::King)));
    assert_eq!(b.get(13, 6), Some((Player::Green, Piece::King))); // 180° swap
    assert_eq!(b.get(3, 1), Some((Player::Red, Piece::Pawn)));
    assert_eq!(b.get(1, 3), Some((Player::Blue, Piece::Pawn)));
}

#[test]
fn promo_zone_per_army() {
    assert!(is_promo_square(Player::Red, Coord::new(5, 10)));
    assert!(is_promo_square(Player::Yellow, Coord::new(5, 3)));
    assert!(is_promo_square(Player::Blue, Coord::new(10, 5)));
    assert!(is_promo_square(Player::Green, Coord::new(3, 5)));
    assert!(!is_promo_square(Player::Red, Coord::new(5, 9)));
}

#[test]
fn start_move_count_is_twenty() {
    let g = FourGame::new(Format::FreeForAll);
    // 8 pawns × 2 + 4 knight moves = 20.
    assert_eq!(g.legal_moves().len(), 20);
}

#[test]
fn pawns_advance_toward_centre() {
    let g = FourGame::new(Format::FreeForAll);
    let has = |ms: &[Move4], f: (i8, i8), t: (i8, i8)| {
        ms.iter()
            .any(|m| (m.from.col, m.from.row) == f && (m.to.col, m.to.row) == t)
    };
    let red = g.legal_moves_for(Player::Red);
    assert!(has(&red, (3, 1), (3, 2))); // Red up
    assert!(has(&red, (3, 1), (3, 3))); // double
    let blue = g.legal_moves_for(Player::Blue);
    assert!(has(&blue, (1, 3), (2, 3))); // Blue right
}

#[test]
fn capture_scores_in_ffa() {
    let mut g = FourGame::new(Format::FreeForAll);
    g.board.put(4, 2, Player::Blue, Piece::Pawn); // hanging foe for Red
    assert!(g.make_move(Move4::plain(Coord::new(3, 1), Coord::new(4, 2))));
    assert_eq!(g.scores[Player::Red.index()], 1);
    assert_eq!(at(&g, 4, 2), Some((Player::Red, Piece::Pawn)));
}

#[test]
fn cannot_capture_partner_in_teams() {
    let mut g = FourGame::new(Format::Teams);
    g.board.put(4, 2, Player::Yellow, Piece::Pawn); // Red's partner
    assert!(!g.make_move(Move4::plain(Coord::new(3, 1), Coord::new(4, 2))));
}

#[test]
fn bot_takes_a_hanging_queen() {
    let mut g = FourGame::new(Format::FreeForAll);
    g.board.put(4, 2, Player::Blue, Piece::Queen);
    let m = chess4::bot::greedy_move(&g, 7).unwrap();
    assert_eq!((m.to.col, m.to.row), (4, 2));
}

#[test]
fn slider_stops_at_a_cut_corner() {
    // A rook in the left arm sliding up the a-file must stop before the cut
    // top-left corner (rows 11..13 at col 0 are invalid).
    let mut g = FourGame::new(Format::FreeForAll);
    // Clear Blue's back rank so its a8-ish rook can roam; place a lone rook.
    g.board = Board::empty();
    g.board.put(7, 0, Player::Red, Piece::King); // kings so checks are well-defined
    g.board.put(7, 13, Player::Yellow, Piece::King);
    g.board.put(0, 5, Player::Red, Piece::Rook);
    let moves = g.legal_moves_for(Player::Red);
    // Rook at (0,5) going up the col-0 file: (0,6)..(0,10) valid, (0,11) is a cut
    // corner → not reachable.
    assert!(moves
        .iter()
        .any(|m| (m.to.col, m.to.row) == (0, 10)));
    assert!(!moves
        .iter()
        .any(|m| (m.to.col, m.to.row) == (0, 11)));
}

#[test]
fn turn_rotates_red_to_blue() {
    let mut g = FourGame::new(Format::FreeForAll);
    g.make_move(Move4::plain(Coord::new(3, 1), Coord::new(3, 2)));
    assert_eq!(g.turn, Player::Blue);
}

#[test]
fn teams_win_when_both_opponents_dead() {
    let mut g = FourGame::new(Format::Teams);
    g.status[Player::Blue.index()] = PlayerStatus::Checkmated;
    g.status[Player::Green.index()] = PlayerStatus::Checkmated;
    assert!(matches!(g.result(), FourResult::TeamWin(Team::RedYellow)));
}

#[test]
fn red_castles_kingside() {
    let mut g = FourGame::new(Format::FreeForAll);
    g.board.clear(8, 0); // bishop
    g.board.clear(9, 0); // knight
    let moves = g.legal_moves();
    let cm = moves
        .iter()
        .find(|m| m.castle && m.from == Coord::new(7, 0) && m.to == Coord::new(9, 0))
        .copied();
    assert!(cm.is_some(), "kingside castle should be legal");
    g.make_move(cm.unwrap());
    assert_eq!(at(&g, 9, 0), Some((Player::Red, Piece::King)));
    assert_eq!(at(&g, 8, 0), Some((Player::Red, Piece::Rook)));
}

#[test]
fn castling_revoked_after_king_moves() {
    let mut g = FourGame::new(Format::FreeForAll);
    g.board.clear(8, 0);
    g.board.clear(9, 0);
    g.make_move(Move4::plain(Coord::new(7, 0), Coord::new(8, 0))); // Ke1-ish move
    assert_eq!(g.castling[Player::Red.index()], [false, false]);
}
