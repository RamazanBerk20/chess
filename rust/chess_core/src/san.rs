//! Conversions between [`Move`] and human notations: UCI/coordinate (`e2e4`,
//! `e7e8q`) and SAN (`Nf3`, `exd5`, `O-O`, `e8=Q+`).
//!
//! SAN parsing is done by generating SAN for every legal move and matching, so
//! the parser is always exactly consistent with the generator.

use crate::error::{ChessError, Result};
use crate::position::Position;
use crate::types::{file_of, parse_square, rank_of, square_name, Move, Piece};

impl Position {
    /// Parse a UCI/coordinate move string against the current position.
    pub fn parse_uci(&mut self, s: &str) -> Result<Move> {
        if s.len() < 4 || !s.is_ascii() {
            return Err(ChessError::InvalidMove(s.to_string()));
        }
        // Crazyhouse drop: "<P>@<sq>", e.g. "N@f3".
        if let Some(at) = s.find('@') {
            let pc = s
                .as_bytes()
                .first()
                .and_then(|&b| Piece::from_char((b as char).to_ascii_lowercase()))
                .ok_or_else(|| ChessError::InvalidMove(s.to_string()))?;
            let sq = parse_square(s.get(at + 1..at + 3).unwrap_or(""))
                .ok_or_else(|| ChessError::InvalidMove(s.to_string()))?;
            let legal = self.generate_legal();
            for i in 0..legal.len() {
                let m = legal[i];
                if m.is_drop() && m.dropped_piece() == pc && m.to() == sq {
                    return Ok(m);
                }
            }
            return Err(ChessError::IllegalMove(s.to_string()));
        }
        let from = parse_square(&s[0..2]).ok_or_else(|| ChessError::InvalidMove(s.to_string()))?;
        let to = parse_square(&s[2..4]).ok_or_else(|| ChessError::InvalidMove(s.to_string()))?;
        let promo = s.as_bytes().get(4).and_then(|&b| Piece::from_char(b as char));

        let legal = self.generate_legal();
        for i in 0..legal.len() {
            let m = legal[i];
            if m.from() == from && m.to() == to {
                match (m.promotion(), promo) {
                    (Some(p), Some(pp)) if p == pp => return Ok(m),
                    (None, None) => return Ok(m),
                    _ => continue,
                }
            }
        }
        Err(ChessError::IllegalMove(s.to_string()))
    }

    /// Parse a SAN move string against the current position. Lenient about
    /// common spellings: digit-zero castling (`0-0`), lowercase/`=`-less
    /// promotions (`e8q`, `e8=q`) and `!`/`?` annotation suffixes.
    pub fn parse_san(&mut self, s: &str) -> Result<Move> {
        let target = normalize_san(s);
        let legal = self.generate_legal();
        for i in 0..legal.len() {
            let m = legal[i];
            let san = self.san_of(m);
            if san.trim_end_matches(['+', '#']) == target {
                return Ok(m);
            }
        }
        Err(ChessError::InvalidSan(s.to_string()))
    }

    /// Render `mv` as SAN (assumes `mv` is legal in this position).
    pub fn san_of(&mut self, mv: Move) -> String {
        if mv.is_drop() {
            // Crazyhouse: "P@e4", "N@f3".
            let p = mv.dropped_piece();
            let mut s = String::new();
            s.push(p.to_char().to_ascii_uppercase());
            s.push('@');
            s.push_str(&square_name(mv.to()));
            s.push_str(self.check_suffix(mv));
            return s;
        }
        if mv.is_castle() {
            let base = if mv.kind() == crate::types::kind::KING_CASTLE {
                "O-O"
            } else {
                "O-O-O"
            };
            return format!("{base}{}", self.check_suffix(mv));
        }

        let (_, piece) = self.piece_at(mv.from()).expect("san: from empty");
        let mut s = String::new();

        if piece == Piece::Pawn {
            if mv.is_capture() {
                s.push((b'a' + file_of(mv.from())) as char);
                s.push('x');
            }
            s.push_str(&square_name(mv.to()));
            if let Some(p) = mv.promotion() {
                s.push('=');
                s.push(p.to_char().to_ascii_uppercase());
            }
        } else {
            s.push(piece.to_char().to_ascii_uppercase());
            s.push_str(&self.disambiguation(mv, piece));
            if mv.is_capture() {
                s.push('x');
            }
            s.push_str(&square_name(mv.to()));
        }

        s.push_str(self.check_suffix(mv));
        s
    }

    /// Minimal disambiguation (file, rank, or both) for a piece move.
    fn disambiguation(&mut self, mv: Move, piece: Piece) -> String {
        let from = mv.from();
        let legal = self.generate_legal();
        let mut others = Vec::new();
        for i in 0..legal.len() {
            let m = legal[i];
            if m.to() == mv.to() && m.from() != from {
                if let Some((_, pp)) = self.piece_at(m.from()) {
                    if pp == piece {
                        others.push(m.from());
                    }
                }
            }
        }
        if others.is_empty() {
            return String::new();
        }
        let same_file = others.iter().any(|&sq| file_of(sq) == file_of(from));
        let same_rank = others.iter().any(|&sq| rank_of(sq) == rank_of(from));
        let file_ch = (b'a' + file_of(from)) as char;
        let rank_ch = (b'1' + rank_of(from)) as char;
        if !same_file {
            file_ch.to_string()
        } else if !same_rank {
            rank_ch.to_string()
        } else {
            format!("{file_ch}{rank_ch}")
        }
    }

    /// `"+"` if the move gives check, `"#"` if checkmate, else `""`.
    fn check_suffix(&mut self, mv: Move) -> &'static str {
        let u = self.make_move(mv);
        let them = self.side;
        let suffix = if self.in_check(them) {
            if self.generate_legal().is_empty() {
                "#"
            } else {
                "+"
            }
        } else {
            ""
        };
        self.unmake_move(mv, u);
        suffix
    }
}

/// Normalise a SAN string to the engine's canonical spelling for matching:
/// strip check/annotation suffixes, map digit-zero castling to `O`, and
/// canonicalise promotions to `=<UPPER>` (e.g. `e8q`, `e8=q` -> `e8=Q`).
fn normalize_san(s: &str) -> String {
    let mut t: String = s.trim_end_matches(['+', '#', '!', '?']).replace('0', "O");
    if let Some(last) = t.chars().last() {
        if matches!(last.to_ascii_lowercase(), 'n' | 'b' | 'r' | 'q') {
            let mut core = t.clone();
            core.pop();
            if core.ends_with('=') {
                core.pop();
            }
            if core.ends_with('8') || core.ends_with('1') {
                core.push('=');
                core.push(last.to_ascii_uppercase());
                t = core;
            }
        }
    }
    t
}
