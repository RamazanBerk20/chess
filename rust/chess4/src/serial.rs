//! 14×14 coordinate notation (files a..n, ranks 1..14) + UCI-like moves.

use crate::movegen::Move4;
use crate::types::{Coord, Piece};

pub fn coord_to_str(c: Coord) -> String {
    let file = (b'a' + c.col as u8) as char;
    format!("{}{}", file, c.row + 1)
}

fn read_coord(b: &[u8], i: &mut usize) -> Option<Coord> {
    if *i >= b.len() || !(b[*i] as char).is_ascii_lowercase() {
        return None;
    }
    let col = b[*i] as i8 - b'a' as i8;
    *i += 1;
    let start = *i;
    while *i < b.len() && (b[*i] as char).is_ascii_digit() {
        *i += 1;
    }
    if *i == start {
        return None;
    }
    let row: i8 = std::str::from_utf8(&b[start..*i]).ok()?.parse::<i8>().ok()? - 1;
    if (0..14).contains(&col) && (0..14).contains(&row) {
        Some(Coord::new(col, row))
    } else {
        None
    }
}

pub fn move_to_uci(m: Move4) -> String {
    let mut s = coord_to_str(m.from);
    s.push_str(&coord_to_str(m.to));
    if let Some(p) = m.promo {
        s.push(p.to_char());
    }
    s
}

/// Parse a UCI-like move, e.g. "d1d2", "d2d3q". Returns (from, to, promo).
pub fn parse_uci(s: &str) -> Option<(Coord, Coord, Option<Piece>)> {
    let b = s.as_bytes();
    let mut i = 0usize;
    let from = read_coord(b, &mut i)?;
    let to = read_coord(b, &mut i)?;
    let promo = if i < b.len() {
        match b[i] as char {
            'n' => Some(Piece::Knight),
            'b' => Some(Piece::Bishop),
            'r' => Some(Piece::Rook),
            'q' => Some(Piece::Queen),
            _ => None,
        }
    } else {
        None
    };
    Some((from, to, promo))
}
