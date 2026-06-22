//! Offset/ray move generation for 4-player chess (no bitboards). v1 omits
//! castling and en passant.
//!
//! `allies[p]` = true when player `p` is the mover or the mover's partner; an
//! ally piece blocks but cannot be captured. A foe piece can be captured.

use crate::board::{coord, in_bounds, is_promo_square, Board, N};
use crate::types::{Coord, Piece, Player};

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct Move4 {
    pub from: Coord,
    pub to: Coord,
    pub promo: Option<Piece>,
    /// A castling move (the king's from→to; the rook is moved by `apply`).
    pub castle: bool,
}

impl Move4 {
    pub fn plain(from: Coord, to: Coord) -> Move4 {
        Move4 { from, to, promo: None, castle: false }
    }
    pub fn castling(from: Coord, to: Coord) -> Move4 {
        Move4 { from, to, promo: None, castle: true }
    }
}

const KNIGHT: [(i8, i8); 8] = [
    (1, 2),
    (2, 1),
    (2, -1),
    (1, -2),
    (-1, -2),
    (-2, -1),
    (-2, 1),
    (-1, 2),
];
const KING: [(i8, i8); 8] = [
    (1, 0),
    (1, 1),
    (0, 1),
    (-1, 1),
    (-1, 0),
    (-1, -1),
    (0, -1),
    (1, -1),
];
const ROOK_DIRS: [(i8, i8); 4] = [(1, 0), (-1, 0), (0, 1), (0, -1)];
const BISHOP_DIRS: [(i8, i8); 4] = [(1, 1), (1, -1), (-1, 1), (-1, -1)];

const PROMOS: [Piece; 4] = [Piece::Queen, Piece::Rook, Piece::Bishop, Piece::Knight];

type Allies = [bool; 4];

/// All pseudo-legal moves for `player`.
pub fn pseudo_moves(board: &Board, player: Player, allies: &Allies, out: &mut Vec<Move4>) {
    for i in 0..N {
        let Some((p, piece)) = board.cells[i] else {
            continue;
        };
        if p != player {
            continue;
        }
        let from = coord(i);
        match piece {
            Piece::Pawn => gen_pawn(board, player, from, allies, out),
            Piece::Knight => gen_steps(board, from, allies, &KNIGHT, out),
            Piece::King => gen_steps(board, from, allies, &KING, out),
            Piece::Bishop => gen_slider(board, from, allies, &BISHOP_DIRS, out),
            Piece::Rook => gen_slider(board, from, allies, &ROOK_DIRS, out),
            Piece::Queen => {
                gen_slider(board, from, allies, &ROOK_DIRS, out);
                gen_slider(board, from, allies, &BISHOP_DIRS, out);
            }
        }
    }
}

/// A capturable foe sits on `c` (occupied by a non-ally).
fn is_foe(board: &Board, c: Coord, allies: &Allies) -> bool {
    matches!(board.get(c.col, c.row), Some((p, _)) if !allies[p.index()])
}

fn gen_steps(board: &Board, from: Coord, allies: &Allies, offsets: &[(i8, i8)], out: &mut Vec<Move4>) {
    for &(dc, dr) in offsets {
        let to = Coord::new(from.col + dc, from.row + dr);
        if !in_bounds(to.col, to.row) {
            continue;
        }
        match board.get(to.col, to.row) {
            None => out.push(Move4::plain(from, to)),
            Some((p, _)) if !allies[p.index()] => out.push(Move4::plain(from, to)),
            _ => {} // ally — blocked
        }
    }
}

fn gen_slider(board: &Board, from: Coord, allies: &Allies, dirs: &[(i8, i8)], out: &mut Vec<Move4>) {
    for &(dc, dr) in dirs {
        let (mut c, mut r) = (from.col + dc, from.row + dr);
        while in_bounds(c, r) {
            match board.get(c, r) {
                None => out.push(Move4::plain(from, Coord::new(c, r))),
                Some((p, _)) => {
                    if !allies[p.index()] {
                        out.push(Move4::plain(from, Coord::new(c, r)));
                    }
                    break; // any piece blocks
                }
            }
            c += dc;
            r += dr;
        }
    }
}

fn pawn_start(player: Player, from: Coord) -> bool {
    match player {
        Player::Red => from.row == 1,
        Player::Yellow => from.row == 12,
        Player::Blue => from.col == 1,
        Player::Green => from.col == 12,
    }
}

fn push_pawn(player: Player, from: Coord, to: Coord, out: &mut Vec<Move4>) {
    if is_promo_square(player, to) {
        for pr in PROMOS {
            out.push(Move4 { from, to, promo: Some(pr), castle: false });
        }
    } else {
        out.push(Move4::plain(from, to));
    }
}

fn gen_pawn(board: &Board, player: Player, from: Coord, allies: &Allies, out: &mut Vec<Move4>) {
    let (fc, fr) = player.forward();
    let one = Coord::new(from.col + fc, from.row + fr);
    if in_bounds(one.col, one.row) && board.get(one.col, one.row).is_none() {
        push_pawn(player, from, one, out);
        if pawn_start(player, from) {
            let two = Coord::new(from.col + 2 * fc, from.row + 2 * fr);
            if in_bounds(two.col, two.row) && board.get(two.col, two.row).is_none() {
                out.push(Move4::plain(from, two));
            }
        }
    }
    for (dc, dr) in player.pawn_captures() {
        let to = Coord::new(from.col + dc, from.row + dr);
        if in_bounds(to.col, to.row) && is_foe(board, to, allies) {
            push_pawn(player, from, to, out);
        }
    }
}

/// Does `by` attack `target` (regardless of `by`'s active status)?
pub fn attacks_square(board: &Board, by: Player, target: Coord) -> bool {
    for (dc, dr) in by.pawn_captures() {
        let src = Coord::new(target.col - dc, target.row - dr);
        if board.get(src.col, src.row) == Some((by, Piece::Pawn)) {
            return true;
        }
    }
    for &(dc, dr) in &KNIGHT {
        let src = Coord::new(target.col + dc, target.row + dr);
        if board.get(src.col, src.row) == Some((by, Piece::Knight)) {
            return true;
        }
    }
    for &(dc, dr) in &KING {
        let src = Coord::new(target.col + dc, target.row + dr);
        if board.get(src.col, src.row) == Some((by, Piece::King)) {
            return true;
        }
    }
    ray_hits(board, by, target, &BISHOP_DIRS, Piece::Bishop)
        || ray_hits(board, by, target, &ROOK_DIRS, Piece::Rook)
}

fn ray_hits(board: &Board, by: Player, target: Coord, dirs: &[(i8, i8)], slider: Piece) -> bool {
    for &(dc, dr) in dirs {
        let (mut c, mut r) = (target.col + dc, target.row + dr);
        while in_bounds(c, r) {
            if let Some((p, piece)) = board.get(c, r) {
                if p == by && (piece == slider || piece == Piece::Queen) {
                    return true;
                }
                break;
            }
            c += dc;
            r += dr;
        }
    }
    false
}
