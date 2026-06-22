//! The 4-player game: turn rotation, check/mate, dead-player handling, scoring
//! and win detection for both Teams and Free-for-all.

use crate::board::Board;
use crate::movegen::{attacks_square, pseudo_moves, Move4};
use crate::types::{Coord, Format, Piece, Player, PlayerStatus, Team};

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum FourResult {
    InProgress,
    TeamWin(Team),
    FfaWin(Player),
}

#[derive(Clone)]
pub struct FourGame {
    pub board: Board,
    pub turn: Player,
    pub format: Format,
    pub status: [PlayerStatus; 4],
    pub scores: [u32; 4],
    pub last: Option<(crate::types::Coord, crate::types::Coord)>,
    pub ended: bool,
    /// Castling rights per player: [high-coord side, low-coord side].
    pub castling: [[bool; 2]; 4],
}

/// Castling geometry for one army (king home + the two sides' rook/king/rook
/// destination squares). Side 0 = toward the higher-coordinate rook.
struct CastleInfo {
    king: Coord,
    sides: [CastleSide; 2],
}
struct CastleSide {
    rook: Coord,
    king_to: Coord,
    rook_to: Coord,
}

fn castle_info(player: Player) -> CastleInfo {
    let c = |col, row| Coord::new(col, row);
    match player {
        Player::Red => CastleInfo {
            king: c(7, 0),
            sides: [
                CastleSide { rook: c(10, 0), king_to: c(9, 0), rook_to: c(8, 0) },
                CastleSide { rook: c(3, 0), king_to: c(5, 0), rook_to: c(6, 0) },
            ],
        },
        Player::Yellow => CastleInfo {
            king: c(6, 13),
            sides: [
                CastleSide { rook: c(10, 13), king_to: c(8, 13), rook_to: c(7, 13) },
                CastleSide { rook: c(3, 13), king_to: c(4, 13), rook_to: c(5, 13) },
            ],
        },
        Player::Blue => CastleInfo {
            king: c(0, 7),
            sides: [
                CastleSide { rook: c(0, 10), king_to: c(0, 9), rook_to: c(0, 8) },
                CastleSide { rook: c(0, 3), king_to: c(0, 5), rook_to: c(0, 6) },
            ],
        },
        Player::Green => CastleInfo {
            king: c(13, 6),
            sides: [
                CastleSide { rook: c(13, 10), king_to: c(13, 8), rook_to: c(13, 7) },
                CastleSide { rook: c(13, 3), king_to: c(13, 4), rook_to: c(13, 5) },
            ],
        },
    }
}

impl FourGame {
    pub fn new(format: Format) -> FourGame {
        FourGame {
            board: Board::start(),
            turn: Player::Red,
            format,
            status: [PlayerStatus::Active; 4],
            scores: [0; 4],
            last: None,
            ended: false,
            castling: [[true; 2]; 4],
        }
    }

    fn is_foe(&self, a: Player, b: Player) -> bool {
        a != b && (self.format == Format::FreeForAll || a.team() != b.team())
    }

    /// Allies (self + partner in Teams; only self in FFA), as a mover-relative
    /// mask — ally pieces block but can't be captured.
    fn allies_of(&self, player: Player) -> [bool; 4] {
        let mut a = [false; 4];
        for p in Player::ALL {
            a[p.index()] = !self.is_foe(player, p);
        }
        a
    }

    /// Geometric premove destinations for the piece on `from`, ignoring whose
    /// turn it is (the piece's owner sets direction/allies). Approximate — the
    /// premove is re-validated when it executes.
    pub fn premove_targets(&self, from: Coord) -> Vec<Coord> {
        self.premove_targets_on(&self.board, from)
    }

    /// Premove targets after the queued premoves are applied as raw relocations,
    /// so a premove chain can target the board the earlier premoves produce.
    pub fn premove_targets_after(&self, premoves: &[(Coord, Coord)], from: Coord) -> Vec<Coord> {
        let mut board = self.board.clone();
        for &(f, t) in premoves {
            if let Some((p, pc)) = board.get(f.col, f.row) {
                board.clear(f.col, f.row);
                board.put(t.col, t.row, p, pc);
            }
        }
        self.premove_targets_on(&board, from)
    }

    fn premove_targets_on(&self, board: &Board, from: Coord) -> Vec<Coord> {
        let Some((owner, _)) = board.get(from.col, from.row) else {
            return Vec::new();
        };
        let allies = self.allies_of(owner);
        let mut pseudo = Vec::new();
        pseudo_moves(board, owner, &allies, &mut pseudo);
        let mut out = Vec::new();
        for m in pseudo {
            if m.from == from && !out.contains(&m.to) {
                out.push(m.to);
            }
        }
        out
    }

    pub fn is_active(&self, player: Player) -> bool {
        self.status[player.index()].is_active()
    }

    /// King of `player` attacked by any ACTIVE foe (dead pieces are inert).
    pub fn in_check(&self, player: Player) -> bool {
        self.king_attacked_on(&self.board, player)
    }

    fn king_attacked_on(&self, board: &Board, player: Player) -> bool {
        let Some(k) = board.king_of(player) else {
            return false;
        };
        for enemy in Player::ALL {
            if !self.is_foe(player, enemy) || !self.is_active(enemy) {
                continue;
            }
            if attacks_square(board, enemy, k) {
                return true;
            }
        }
        false
    }

    fn move_is_safe(&self, m: Move4, player: Player) -> bool {
        let mut b = self.board.clone();
        let Some((_, piece)) = b.get(m.from.col, m.from.row) else {
            return false;
        };
        b.clear(m.from.col, m.from.row);
        b.put(m.to.col, m.to.row, player, m.promo.unwrap_or(piece));
        !self.king_attacked_on(&b, player)
    }

    pub fn legal_moves_for(&self, player: Player) -> Vec<Move4> {
        if !self.is_active(player) {
            return Vec::new();
        }
        let allies = self.allies_of(player);
        let mut pseudo = Vec::new();
        pseudo_moves(&self.board, player, &allies, &mut pseudo);
        let mut out: Vec<Move4> = pseudo
            .into_iter()
            .filter(|m| self.move_is_safe(*m, player))
            .collect();
        out.extend(self.gen_castling(player));
        out
    }

    /// Whether any ACTIVE foe attacks `sq`.
    fn square_attacked(&self, sq: Coord, player: Player) -> bool {
        for enemy in Player::ALL {
            if !self.is_foe(player, enemy) || !self.is_active(enemy) {
                continue;
            }
            if attacks_square(&self.board, enemy, sq) {
                return true;
            }
        }
        false
    }

    fn between_empty(&self, a: Coord, b: Coord) -> bool {
        let dc = (b.col - a.col).signum();
        let dr = (b.row - a.row).signum();
        let (mut c, mut r) = (a.col + dc, a.row + dr);
        while (c, r) != (b.col, b.row) {
            if self.board.get(c, r).is_some() {
                return false;
            }
            c += dc;
            r += dr;
        }
        true
    }

    fn king_path_safe(&self, player: Player, from: Coord, to: Coord) -> bool {
        let dc = (to.col - from.col).signum();
        let dr = (to.row - from.row).signum();
        let (mut c, mut r) = (from.col, from.row);
        loop {
            if self.square_attacked(Coord::new(c, r), player) {
                return false;
            }
            if (c, r) == (to.col, to.row) {
                return true;
            }
            c += dc;
            r += dr;
        }
    }

    fn gen_castling(&self, player: Player) -> Vec<Move4> {
        let mut out = Vec::new();
        if self.in_check(player) {
            return out; // can't castle out of check
        }
        let info = castle_info(player);
        if self.board.get(info.king.col, info.king.row) != Some((player, Piece::King)) {
            return out;
        }
        for side in 0..2 {
            if !self.castling[player.index()][side] {
                continue;
            }
            let s = &info.sides[side];
            if self.board.get(s.rook.col, s.rook.row) != Some((player, Piece::Rook)) {
                continue;
            }
            if !self.between_empty(info.king, s.rook) {
                continue;
            }
            if !self.king_path_safe(player, info.king, s.king_to) {
                continue;
            }
            out.push(Move4::castling(info.king, s.king_to));
        }
        out
    }

    /// Revoke castling rights touched (king/rook moving, or a rook captured).
    fn revoke_castling(&mut self, from: Coord, to: Coord) {
        for p in Player::ALL {
            let info = castle_info(p);
            if from == info.king {
                self.castling[p.index()] = [false, false];
            }
            for side in 0..2 {
                let rook = info.sides[side].rook;
                if from == rook || to == rook {
                    self.castling[p.index()][side] = false;
                }
            }
        }
    }

    pub fn legal_moves(&self) -> Vec<Move4> {
        self.legal_moves_for(self.turn)
    }

    /// Apply a legal move for the side to move. Returns false if illegal/over.
    pub fn make_move(&mut self, m: Move4) -> bool {
        if self.ended || !self.is_active(self.turn) {
            return false;
        }
        if !self.legal_moves().iter().any(|x| *x == m) {
            return false;
        }
        self.apply(m);
        true
    }

    fn apply(&mut self, m: Move4) {
        let mover = self.turn;
        let (_, piece) = self.board.get(m.from.col, m.from.row).unwrap();
        let captured = self.board.get(m.to.col, m.to.row);
        self.board.clear(m.from.col, m.from.row);
        self.board
            .put(m.to.col, m.to.row, mover, m.promo.unwrap_or(piece));
        if let Some((_, cp)) = captured {
            self.scores[mover.index()] += cp.value();
        }
        if m.castle {
            let info = castle_info(mover);
            let side = if m.to == info.sides[0].king_to { 0 } else { 1 };
            let s = &info.sides[side];
            self.board.clear(s.rook.col, s.rook.row);
            self.board.put(s.rook_to.col, s.rook_to.row, mover, Piece::Rook);
        }
        self.revoke_castling(m.from, m.to);
        self.last = Some((m.from, m.to));
        self.mark_mates(mover);
        self.advance_turn();
    }

    /// Mate any active foe this move has just checkmated; award FFA points.
    fn mark_mates(&mut self, mover: Player) {
        for foe in Player::ALL {
            if !self.is_foe(mover, foe) || !self.is_active(foe) {
                continue;
            }
            if self.in_check(foe) && self.legal_moves_for(foe).is_empty() {
                self.status[foe.index()] = PlayerStatus::Checkmated;
                if self.format == Format::FreeForAll {
                    self.scores[mover.index()] += 20;
                }
                self.update_end();
            }
        }
    }

    /// Rotate to the next player able to move, marking any stalemated/self-mated
    /// players passed along the way.
    fn advance_turn(&mut self) {
        for _ in 0..8 {
            self.turn = self.turn.next();
            if !self.is_active(self.turn) {
                continue; // skip dead players
            }
            if self.legal_moves_for(self.turn).is_empty() {
                self.status[self.turn.index()] = if self.in_check(self.turn) {
                    PlayerStatus::Checkmated
                } else {
                    PlayerStatus::Stalemated
                };
                self.update_end();
                if self.ended {
                    return;
                }
                continue;
            }
            self.update_end();
            return;
        }
        self.update_end();
    }

    fn update_end(&mut self) {
        if !matches!(self.result(), FourResult::InProgress) {
            self.ended = true;
        }
    }

    pub fn result(&self) -> FourResult {
        let active: Vec<Player> = Player::ALL
            .into_iter()
            .filter(|&p| self.is_active(p))
            .collect();
        match self.format {
            Format::Teams => {
                let t1 = active.iter().any(|p| p.team() == 1);
                let t2 = active.iter().any(|p| p.team() == 2);
                if !t1 {
                    FourResult::TeamWin(Team::BlueGreen)
                } else if !t2 {
                    FourResult::TeamWin(Team::RedYellow)
                } else {
                    FourResult::InProgress
                }
            }
            Format::FreeForAll => {
                if active.len() <= 1 {
                    let w = active.first().copied().unwrap_or_else(|| self.top_scorer());
                    FourResult::FfaWin(w)
                } else {
                    FourResult::InProgress
                }
            }
        }
    }

    fn top_scorer(&self) -> Player {
        let mut best = Player::Red;
        for p in Player::ALL {
            if self.scores[p.index()] > self.scores[best.index()] {
                best = p;
            }
        }
        best
    }
}
