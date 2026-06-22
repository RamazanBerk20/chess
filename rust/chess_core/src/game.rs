//! Game wrapper: move history (for takeback), position-hash history (for
//! threefold repetition) and termination/draw detection.

use crate::error::Result;
use crate::fen::parse_fen;
use crate::position::{Position, Undo};
use crate::types::{file_of, rank_of, Color, Move, MoveList, Piece, Variant};

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum GameStatus {
    Ongoing,
    Checkmate { winner: Color },
    /// A variant-specific win (three checks, king on the hill, king exploded).
    VariantWin { winner: Color },
    Stalemate,
    DrawFiftyMove,
    DrawThreefold,
    DrawInsufficientMaterial,
}

#[derive(Clone)]
pub struct Game {
    pub pos: Position,
    history: Vec<(Move, Undo)>,
    /// Position hashes; index 0 is the start position, one entry per ply after.
    hashes: Vec<u64>,
}

impl Game {
    pub fn new() -> Game {
        Game::from_position(Position::startpos())
    }

    pub fn from_fen(fen: &str) -> Result<Game> {
        Ok(Game::from_position(parse_fen(fen)?))
    }

    pub fn from_position(pos: Position) -> Game {
        let h = pos.hash;
        Game {
            pos,
            history: Vec::new(),
            hashes: vec![h],
        }
    }

    pub fn legal_moves(&mut self) -> MoveList {
        self.pos.generate_legal()
    }

    /// Apply a legal move and record history.
    pub fn make_move(&mut self, mv: Move) {
        let u = self.pos.make_move(mv);
        self.history.push((mv, u));
        self.hashes.push(self.pos.hash);
    }

    /// Take back the last move, if any.
    pub fn undo(&mut self) -> bool {
        if let Some((mv, u)) = self.history.pop() {
            self.pos.unmake_move(mv, u);
            self.hashes.pop();
            true
        } else {
            false
        }
    }

    pub fn ply(&self) -> usize {
        self.history.len()
    }

    /// Position-hash history (one entry per ply, index 0 = start), for the AI's
    /// repetition detection.
    pub fn hash_history(&self) -> Vec<u64> {
        self.hashes.clone()
    }

    /// How many times the current position has occurred (>=3 means threefold).
    pub fn repetition_count(&self) -> usize {
        let cur = self.pos.hash;
        self.hashes.iter().filter(|&&h| h == cur).count()
    }

    pub fn status(&mut self) -> GameStatus {
        // Variant win conditions (three-check / king-of-the-hill / atomic king
        // explosion) take precedence over the normal terminal checks.
        if let Some(winner) = self.pos.variant_terminal() {
            return GameStatus::VariantWin { winner };
        }
        let side = self.pos.side;
        let legal = self.pos.generate_legal();
        if legal.is_empty() {
            // Fog of War has no check concept — a stuck side is just a draw.
            if self.pos.variant == Variant::FogOfWar {
                return GameStatus::Stalemate;
            }
            return if self.pos.in_check(side) {
                GameStatus::Checkmate {
                    winner: side.opp(),
                }
            } else {
                GameStatus::Stalemate
            };
        }
        // Crazyhouse/Bughouse never draw on material — pieces return via drops.
        if !matches!(self.pos.variant, Variant::Crazyhouse | Variant::Bughouse)
            && self.is_insufficient_material()
        {
            return GameStatus::DrawInsufficientMaterial;
        }
        if self.pos.halfmove >= 100 {
            return GameStatus::DrawFiftyMove;
        }
        if self.repetition_count() >= 3 {
            return GameStatus::DrawThreefold;
        }
        GameStatus::Ongoing
    }

    /// FIDE insufficient-material draws: KvK, KNvK, KBvK, and only-same-colour
    /// bishops remaining (covers KB vs KB same colour).
    pub fn is_insufficient_material(&self) -> bool {
        let p = &self.pos;
        for c in [Color::White, Color::Black] {
            if p.pieces(c, Piece::Pawn) != 0
                || p.pieces(c, Piece::Rook) != 0
                || p.pieces(c, Piece::Queen) != 0
            {
                return false;
            }
        }
        let knights =
            (p.pieces(Color::White, Piece::Knight) | p.pieces(Color::Black, Piece::Knight))
                .count_ones();
        let bishops_bb =
            p.pieces(Color::White, Piece::Bishop) | p.pieces(Color::Black, Piece::Bishop);
        let bishops = bishops_bb.count_ones();

        if knights == 0 && bishops == 0 {
            return true; // KvK
        }
        if knights == 1 && bishops == 0 {
            return true; // KNvK
        }
        if knights == 0 && bishops >= 1 {
            // All bishops on a single square colour cannot force mate.
            let mut bb = bishops_bb;
            let mut colors = 0u8;
            while bb != 0 {
                let sq = crate::bitboard::pop_lsb(&mut bb);
                colors |= 1 << ((file_of(sq) + rank_of(sq)) & 1);
            }
            return colors != 0b11; // only one square colour present
        }
        false
    }
}

impl Default for Game {
    fn default() -> Self {
        Game::new()
    }
}
