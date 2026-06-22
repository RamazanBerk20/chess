//! The 14×14 cross board (the four 3×3 corners are cut → 160 playable cells).

use crate::types::{Coord, Piece, Player};

pub const W: i8 = 14;
pub const N: usize = 196;

/// Validity mask: a cell is invalid (a cut corner) when it is in a corner 3×3.
const fn build_valid() -> [bool; N] {
    let mut v = [true; N];
    let mut row = 0usize;
    while row < 14 {
        let mut col = 0usize;
        while col < 14 {
            let corner = (col < 3 || col > 10) && (row < 3 || row > 10);
            if corner {
                v[row * 14 + col] = false;
            }
            col += 1;
        }
        row += 1;
    }
    v
}
pub static VALID: [bool; N] = build_valid();

#[inline]
pub fn idx(col: i8, row: i8) -> usize {
    row as usize * 14 + col as usize
}

#[inline]
pub fn coord(i: usize) -> Coord {
    Coord::new((i % 14) as i8, (i / 14) as i8)
}

/// On the board and not a cut corner.
#[inline]
pub fn in_bounds(col: i8, row: i8) -> bool {
    col >= 0 && col < W && row >= 0 && row < W && VALID[idx(col, row)]
}

#[derive(Clone)]
pub struct Board {
    pub cells: [Option<(Player, Piece)>; N],
}

const BACK: [Piece; 8] = [
    Piece::Rook,
    Piece::Knight,
    Piece::Bishop,
    Piece::Queen,
    Piece::King,
    Piece::Bishop,
    Piece::Knight,
    Piece::Rook,
];
// 180°-rotated armies (Yellow, Green) swap king/queen so the start has point
// symmetry.
const BACK_KQ: [Piece; 8] = [
    Piece::Rook,
    Piece::Knight,
    Piece::Bishop,
    Piece::King,
    Piece::Queen,
    Piece::Bishop,
    Piece::Knight,
    Piece::Rook,
];

impl Board {
    pub fn empty() -> Board {
        Board { cells: [None; N] }
    }

    pub fn start() -> Board {
        let mut b = Board::empty();
        // Red — bottom edge (row 0 back rank, row 1 pawns); cols 3..10.
        // Yellow — top edge (row 13 back rank, row 12 pawns).
        // Blue — left edge (col 0 back rank, col 1 pawns); rows 3..10.
        // Green — right edge (col 13 back rank, col 12 pawns).
        for i in 0..8i8 {
            let c = 3 + i;
            b.put(c, 0, Player::Red, BACK[i as usize]);
            b.put(c, 1, Player::Red, Piece::Pawn);
            b.put(c, 13, Player::Yellow, BACK_KQ[i as usize]);
            b.put(c, 12, Player::Yellow, Piece::Pawn);

            let r = 3 + i;
            b.put(0, r, Player::Blue, BACK[i as usize]);
            b.put(1, r, Player::Blue, Piece::Pawn);
            b.put(13, r, Player::Green, BACK_KQ[i as usize]);
            b.put(12, r, Player::Green, Piece::Pawn);
        }
        b
    }

    #[inline]
    pub fn get(&self, col: i8, row: i8) -> Option<(Player, Piece)> {
        if !in_bounds(col, row) {
            return None;
        }
        self.cells[idx(col, row)]
    }

    #[inline]
    pub fn put(&mut self, col: i8, row: i8, player: Player, piece: Piece) {
        self.cells[idx(col, row)] = Some((player, piece));
    }

    #[inline]
    pub fn clear(&mut self, col: i8, row: i8) {
        self.cells[idx(col, row)] = None;
    }

    pub fn king_of(&self, player: Player) -> Option<Coord> {
        for i in 0..N {
            if let Some((p, Piece::King)) = self.cells[i] {
                if p == player {
                    return Some(coord(i));
                }
            }
        }
        None
    }
}

/// A pawn of `player` reaching this square promotes — the far edge of the
/// central 8×8 for that army. (Tunable in one place.)
pub fn is_promo_square(player: Player, c: Coord) -> bool {
    match player {
        Player::Red => c.row == 10,
        Player::Yellow => c.row == 3,
        Player::Blue => c.col == 10,
        Player::Green => c.col == 3,
    }
}
