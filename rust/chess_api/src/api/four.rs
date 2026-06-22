//! flutter_rust_bridge surface for 4-player chess (the `chess4` engine).

use chess4::board::{coord, idx, VALID};
use chess4::{Format, FourGame as Engine4, FourResult, Piece, Player, PlayerStatus};
use flutter_rust_bridge::frb;

use crate::api::game::MoveOutcome;

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum FourPlayer {
    Red,
    Blue,
    Yellow,
    Green,
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum FourPieceKind {
    Pawn,
    Knight,
    Bishop,
    Rook,
    Queen,
    King,
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum FourFormat {
    Teams,
    FreeForAll,
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum FourPlayerStatus {
    Active,
    Checkmated,
    Stalemated,
    Resigned,
}

pub struct FourSquarePiece {
    pub player: FourPlayer,
    pub kind: FourPieceKind,
}

pub struct FourPlayerPanel {
    pub player: FourPlayer,
    pub status: FourPlayerStatus,
    pub score: u32,
    pub in_check: bool,
}

pub struct FourView {
    /// 196 cells, index = row*14 + col. Cut corners + empty squares are None.
    pub board: Vec<Option<FourSquarePiece>>,
    /// 196 validity flags (false = cut corner → painted as a hole).
    pub valid: Vec<bool>,
    pub turn: FourPlayer,
    pub players: Vec<FourPlayerPanel>,
    pub last_from: Option<u32>,
    pub last_to: Option<u32>,
    pub format: FourFormat,
    /// "ongoing" | "team:red_yellow" | "team:blue_green" | "ffa:red" | ...
    pub result: String,
}

#[frb(opaque)]
pub struct FourGame {
    inner: Engine4,
}

impl FourGame {
    #[frb(sync)]
    pub fn new_game(format: FourFormat) -> FourGame {
        FourGame {
            inner: Engine4::new(to_format(format)),
        }
    }

    /// Geometric premove destinations for the piece on `from`, ignoring whose
    /// turn it is (for premove highlighting). Re-validated when it executes.
    #[frb(sync)]
    pub fn premove_targets(&self, from: u32) -> Vec<u32> {
        self.inner
            .premove_targets(coord(from as usize))
            .iter()
            .map(|p| idx(p.col, p.row) as u32)
            .collect()
    }

    /// Premove targets for `from` after the queued premoves (flattened
    /// [f0,t0,f1,t1,…]) are applied as raw relocations — for premove chains.
    #[frb(sync)]
    pub fn premove_targets_after(&self, premoves: Vec<u32>, from: u32) -> Vec<u32> {
        let mut pairs = Vec::new();
        let mut i = 0;
        while i + 1 < premoves.len() {
            pairs.push((coord(premoves[i] as usize), coord(premoves[i + 1] as usize)));
            i += 2;
        }
        self.inner
            .premove_targets_after(&pairs, coord(from as usize))
            .iter()
            .map(|p| idx(p.col, p.row) as u32)
            .collect()
    }

    /// Destination squares (row*14+col) of every legal move from `from`.
    #[frb(sync)]
    pub fn legal_targets(&self, from: u32) -> Vec<u32> {
        let c = coord(from as usize);
        let mut out = Vec::new();
        for m in self.inner.legal_moves() {
            if m.from == c {
                let t = idx(m.to.col, m.to.row) as u32;
                if !out.contains(&t) {
                    out.push(t);
                }
            }
        }
        out
    }

    #[frb(sync)]
    pub fn play(&mut self, from: u32, to: u32, promotion: Option<FourPieceKind>) -> MoveOutcome {
        if self.inner.ended {
            return MoveOutcome::Illegal;
        }
        let (f, t) = (coord(from as usize), coord(to as usize));
        let mut needs_promo = false;
        let legal = self.inner.legal_moves();
        for m in &legal {
            if m.from != f || m.to != t {
                continue;
            }
            match (m.promo, promotion) {
                (Some(p), Some(req)) if p == from_kind(req) => {
                    self.inner.make_move(*m);
                    return MoveOutcome::Played;
                }
                (Some(_), None) => needs_promo = true,
                (None, _) => {
                    self.inner.make_move(*m);
                    return MoveOutcome::Played;
                }
                _ => {}
            }
        }
        if needs_promo {
            MoveOutcome::NeedsPromotion
        } else {
            MoveOutcome::Illegal
        }
    }

    /// Apply a move in coordinate form ("d1d2", "d2d3q"); for bot/remote moves.
    #[frb(sync)]
    pub fn play_uci(&mut self, uci: String) -> bool {
        let Some((f, t, promo)) = chess4::serial::parse_uci(&uci) else {
            return false;
        };
        for m in self.inner.legal_moves() {
            if m.from == f && m.to == t && m.promo.map(piece_idx) == promo.map(piece_idx) {
                self.inner.make_move(m);
                return true;
            }
        }
        false
    }

    /// The greedy bot's move (UCI form) for the side to move, or None if none.
    #[frb(sync)]
    pub fn bot_move(&self, seed: u64) -> Option<String> {
        chess4::bot::greedy_move(&self.inner, seed).map(chess4::serial::move_to_uci)
    }

    #[frb(sync)]
    pub fn view(&self) -> FourView {
        let board: Vec<Option<FourSquarePiece>> = (0..196)
            .map(|i| {
                self.inner.board.cells[i].map(|(pl, pc)| FourSquarePiece {
                    player: from_player(pl),
                    kind: from_piece(pc),
                })
            })
            .collect();
        let players: Vec<FourPlayerPanel> = Player::ALL
            .into_iter()
            .map(|p| FourPlayerPanel {
                player: from_player(p),
                status: from_status(self.inner.status[p.index()]),
                score: self.inner.scores[p.index()],
                in_check: self.inner.in_check(p),
            })
            .collect();
        FourView {
            board,
            valid: VALID.to_vec(),
            turn: from_player(self.inner.turn),
            players,
            last_from: self.inner.last.map(|(f, _)| idx(f.col, f.row) as u32),
            last_to: self.inner.last.map(|(_, t)| idx(t.col, t.row) as u32),
            format: from_format(self.inner.format),
            result: result_str(self.inner.result()),
        }
    }
}

fn result_str(r: FourResult) -> String {
    match r {
        FourResult::InProgress => "ongoing".into(),
        FourResult::TeamWin(chess4::Team::RedYellow) => "team:red_yellow".into(),
        FourResult::TeamWin(chess4::Team::BlueGreen) => "team:blue_green".into(),
        FourResult::FfaWin(p) => format!("ffa:{}", player_code(p)),
    }
}

fn player_code(p: Player) -> &'static str {
    match p {
        Player::Red => "red",
        Player::Blue => "blue",
        Player::Yellow => "yellow",
        Player::Green => "green",
    }
}

fn piece_idx(p: Piece) -> u8 {
    match p {
        Piece::Pawn => 0,
        Piece::Knight => 1,
        Piece::Bishop => 2,
        Piece::Rook => 3,
        Piece::Queen => 4,
        Piece::King => 5,
    }
}

fn to_format(f: FourFormat) -> Format {
    match f {
        FourFormat::Teams => Format::Teams,
        FourFormat::FreeForAll => Format::FreeForAll,
    }
}
fn from_format(f: Format) -> FourFormat {
    match f {
        Format::Teams => FourFormat::Teams,
        Format::FreeForAll => FourFormat::FreeForAll,
    }
}
fn from_player(p: Player) -> FourPlayer {
    match p {
        Player::Red => FourPlayer::Red,
        Player::Blue => FourPlayer::Blue,
        Player::Yellow => FourPlayer::Yellow,
        Player::Green => FourPlayer::Green,
    }
}
fn from_piece(p: Piece) -> FourPieceKind {
    match p {
        Piece::Pawn => FourPieceKind::Pawn,
        Piece::Knight => FourPieceKind::Knight,
        Piece::Bishop => FourPieceKind::Bishop,
        Piece::Rook => FourPieceKind::Rook,
        Piece::Queen => FourPieceKind::Queen,
        Piece::King => FourPieceKind::King,
    }
}
fn from_kind(k: FourPieceKind) -> Piece {
    match k {
        FourPieceKind::Pawn => Piece::Pawn,
        FourPieceKind::Knight => Piece::Knight,
        FourPieceKind::Bishop => Piece::Bishop,
        FourPieceKind::Rook => Piece::Rook,
        FourPieceKind::Queen => Piece::Queen,
        FourPieceKind::King => Piece::King,
    }
}
fn from_status(s: PlayerStatus) -> FourPlayerStatus {
    match s {
        PlayerStatus::Active => FourPlayerStatus::Active,
        PlayerStatus::Checkmated => FourPlayerStatus::Checkmated,
        PlayerStatus::Stalemated => FourPlayerStatus::Stalemated,
        PlayerStatus::Resigned => FourPlayerStatus::Resigned,
    }
}
