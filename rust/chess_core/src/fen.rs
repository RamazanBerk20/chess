//! FEN parsing and generation.

use crate::attacks::pawn_attacks;
use crate::error::{ChessError, Result};
use crate::position::Position;
use crate::types::{
    file_of, make_square, parse_square, square_name, CastlingRights, Color, Piece, Variant,
};
use crate::zobrist::zobrist;

pub fn parse_fen(fen: &str) -> Result<Position> {
    let err = || ChessError::InvalidFen(fen.to_string());
    let parts: Vec<&str> = fen.split_whitespace().collect();
    if parts.len() < 4 {
        return Err(err());
    }

    let mut pos = Position::empty();

    // Piece placement (rank 8 first).
    let rows: Vec<&str> = parts[0].split('/').collect();
    if rows.len() != 8 {
        return Err(err());
    }
    for (i, row) in rows.iter().enumerate() {
        let rank = 7 - i as u8;
        let mut file = 0u8;
        for ch in row.chars() {
            if let Some(d) = ch.to_digit(10) {
                file += d as u8;
            } else {
                let color = if ch.is_ascii_uppercase() {
                    Color::White
                } else {
                    Color::Black
                };
                let piece = Piece::from_char(ch).ok_or_else(err)?;
                if file > 7 {
                    return Err(err());
                }
                pos.put_piece(color, piece, make_square(file, rank));
                file += 1;
            }
        }
        if file != 8 {
            return Err(err());
        }
    }

    // Exactly one king per side, or the position is illegal (and would later
    // panic in king_sq via lsb(0)).
    if pos.pieces(Color::White, Piece::King).count_ones() != 1
        || pos.pieces(Color::Black, Piece::King).count_ones() != 1
    {
        return Err(err());
    }

    // Side to move.
    pos.side = match parts[1] {
        "w" => Color::White,
        "b" => Color::Black,
        _ => return Err(err()),
    };

    // The side NOT to move must not be in check, else the position is illegal.
    if pos.in_check(pos.side.opp()) {
        return Err(err());
    }

    // Castling rights — standard "KQkq" or Shredder-FEN file letters (A-H/a-h)
    // for Chess960 (rook on that file; kingside/queenside by the king's file).
    let mut cr = CastlingRights(0);
    let mut is_960 = false;
    let mut rook_sq = [[7u8, 0u8], [63u8, 56u8]]; // [colour][kingside, queenside]
    let king_file = [
        file_of(pos.king_sq(Color::White)),
        file_of(pos.king_sq(Color::Black)),
    ];
    if parts[2] != "-" {
        for ch in parts[2].chars() {
            match ch {
                'K' | 'Q' | 'k' | 'q' => {
                    let flag = match ch {
                        'K' => CastlingRights::WK,
                        'Q' => CastlingRights::WQ,
                        'k' => CastlingRights::BK,
                        _ => CastlingRights::BQ,
                    };
                    if cr.has(flag) {
                        return Err(err()); // duplicate castling character
                    }
                    cr.add(flag);
                }
                'A'..='H' => {
                    is_960 = true;
                    let f = ch as u8 - b'A';
                    if f > king_file[0] {
                        cr.add(CastlingRights::WK);
                        rook_sq[0][0] = f;
                    } else {
                        cr.add(CastlingRights::WQ);
                        rook_sq[0][1] = f;
                    }
                }
                'a'..='h' => {
                    is_960 = true;
                    let f = ch as u8 - b'a';
                    if f > king_file[1] {
                        cr.add(CastlingRights::BK);
                        rook_sq[1][0] = 56 + f;
                    } else {
                        cr.add(CastlingRights::BQ);
                        rook_sq[1][1] = 56 + f;
                    }
                }
                _ => return Err(err()),
            }
        }
    }
    pos.castle_king_home = [pos.king_sq(Color::White), pos.king_sq(Color::Black)];
    pos.castle_rook_sq = rook_sq;
    if is_960 {
        pos.variant = Variant::Chess960;
        pos.castling = cr; // 960: trust the explicit rook files
    } else {
        // FIDE semantics: drop a right whose king/rook isn't on its home square.
        let home = |c: Color, ksq: u8, rsq: u8| {
            pos.piece_at(ksq) == Some((c, Piece::King))
                && pos.piece_at(rsq) == Some((c, Piece::Rook))
        };
        let mut valid = CastlingRights(0);
        if cr.has(CastlingRights::WK) && home(Color::White, make_square(4, 0), make_square(7, 0)) {
            valid.add(CastlingRights::WK);
        }
        if cr.has(CastlingRights::WQ) && home(Color::White, make_square(4, 0), make_square(0, 0)) {
            valid.add(CastlingRights::WQ);
        }
        if cr.has(CastlingRights::BK) && home(Color::Black, make_square(4, 7), make_square(7, 7)) {
            valid.add(CastlingRights::BK);
        }
        if cr.has(CastlingRights::BQ) && home(Color::Black, make_square(4, 7), make_square(0, 7)) {
            valid.add(CastlingRights::BQ);
        }
        pos.castling = valid;
    }

    // En passant target.
    pos.ep = if parts[3] == "-" {
        None
    } else {
        Some(parse_square(parts[3]).ok_or_else(err)?)
    };

    // Normalise the ep target: keep it only if the side to move can actually
    // capture en passant (keeps the hash/FEN strict and matches make_move).
    if let Some(ep_sq) = pos.ep {
        let capturer = pos.side;
        if pawn_attacks(capturer.opp(), ep_sq) & pos.pieces(capturer, Piece::Pawn) == 0 {
            pos.ep = None;
        }
    }

    // Halfmove / fullmove (optional).
    pos.halfmove = parts.get(4).and_then(|s| s.parse().ok()).unwrap_or(0);
    pos.fullmove = parts.get(5).and_then(|s| s.parse().ok()).unwrap_or(1);

    // Finalise hash (put_piece already mixed in piece keys).
    let z = zobrist();
    pos.hash ^= z.castle(pos.castling.0);
    if let Some(epsq) = pos.ep {
        pos.hash ^= z.ep_file(file_of(epsq));
    }
    if pos.side == Color::Black {
        pos.hash ^= z.side();
    }

    Ok(pos)
}

pub fn to_fen(pos: &Position) -> String {
    let mut s = String::new();
    for rank in (0..8).rev() {
        let mut empty = 0;
        for file in 0..8 {
            let sq = make_square(file, rank);
            match pos.piece_at(sq) {
                Some((c, p)) => {
                    if empty > 0 {
                        s.push_str(&empty.to_string());
                        empty = 0;
                    }
                    let ch = p.to_char();
                    s.push(if c == Color::White {
                        ch.to_ascii_uppercase()
                    } else {
                        ch
                    });
                }
                None => empty += 1,
            }
        }
        if empty > 0 {
            s.push_str(&empty.to_string());
        }
        if rank > 0 {
            s.push('/');
        }
    }

    s.push(' ');
    s.push(if pos.side == Color::White { 'w' } else { 'b' });

    s.push(' ');
    if pos.castling.0 == 0 {
        s.push('-');
    } else if pos.variant == Variant::Chess960 {
        // Shredder-FEN: the castling rook's file letter (upper = white).
        if pos.castling.has(CastlingRights::WK) {
            s.push((b'A' + file_of(pos.castle_rook_sq[0][0])) as char);
        }
        if pos.castling.has(CastlingRights::WQ) {
            s.push((b'A' + file_of(pos.castle_rook_sq[0][1])) as char);
        }
        if pos.castling.has(CastlingRights::BK) {
            s.push((b'a' + file_of(pos.castle_rook_sq[1][0])) as char);
        }
        if pos.castling.has(CastlingRights::BQ) {
            s.push((b'a' + file_of(pos.castle_rook_sq[1][1])) as char);
        }
    } else {
        if pos.castling.has(CastlingRights::WK) {
            s.push('K');
        }
        if pos.castling.has(CastlingRights::WQ) {
            s.push('Q');
        }
        if pos.castling.has(CastlingRights::BK) {
            s.push('k');
        }
        if pos.castling.has(CastlingRights::BQ) {
            s.push('q');
        }
    }

    s.push(' ');
    match pos.ep {
        Some(sq) => s.push_str(&square_name(sq)),
        None => s.push('-'),
    }

    s.push_str(&format!(" {} {}", pos.halfmove, pos.fullmove));
    s
}
