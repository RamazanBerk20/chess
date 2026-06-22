//! Newline-delimited JSON protocol for LAN play.

use serde::{Deserialize, Serialize};

/// Bumped on incompatible protocol changes; peers reject mismatches.
pub const PROTOCOL_VERSION: u32 = 3;

/// mDNS service type advertised/browsed for chess hosts.
pub const SERVICE_TYPE: &str = "_chess._tcp.local.";

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum Message {
    /// First message from the joiner: identity + proposed time control.
    Hello {
        name: String,
        protocol_version: u32,
        base_minutes: u32,
        increment_seconds: u32,
    },
    /// Host arbitrates and replies with agreed parameters + colors. `variant`
    /// is the variant code (e.g. "standard", "crazyhouse"); `fen` carries the
    /// concrete start position (e.g. the Chess960 layout).
    Start {
        white_name: String,
        black_name: String,
        you_are_white: bool,
        base_minutes: u32,
        increment_seconds: u32,
        fen: String,
        variant: String,
    },
    /// A move plus the ply and both clocks (for drift reconciliation).
    Move {
        uci: String,
        ply: u32,
        white_ms: i64,
        black_ms: i64,
    },
    // ---- Bughouse (4 players, 2 boards, host-authoritative) ----
    /// Host → each client: seat assignment + the four player names. Seats are
    /// indexed 0=A-White, 1=A-Black, 2=B-White, 3=B-Black.
    BugStart {
        seats: Vec<String>,
        your_seats: Vec<u8>,
        base_minutes: u32,
        increment_seconds: u32,
    },
    /// A move or drop on `board` (0=A, 1=B). Drops use UCI "N@f3" form. Clocks
    /// are the host-authoritative board clocks after the move.
    BugMove {
        board: u8,
        uci: String,
        white_ms: i64,
        black_ms: i64,
    },
    /// Host → clients: a captured piece passed to the partner's reserve.
    /// `to_color` 0=white, 1=black; `piece` 0=Pawn..4=Queen.
    BugPass {
        to_board: u8,
        to_color: u8,
        piece: u8,
    },
    /// Host → clients: the match ended. `winning_team` 1 or 2.
    BugResult {
        winning_team: u8,
        reason: String,
        board: u8,
    },
    /// A seat resigns (forfeits its team).
    BugResign {
        seat: u8,
    },

    // ---- 4-player chess (host-authoritative; seats 0=Red,1=Blue,2=Yellow,3=Green) ----
    /// Host → each client: format ("ffa"/"teams") + the four names + this
    /// client's seats.
    FourStart {
        format: String,
        seats: Vec<String>,
        your_seats: Vec<u8>,
    },
    /// A move/castle/promotion on the cross board (UCI-like, e.g. "g1i1").
    FourMove {
        seat: u8,
        uci: String,
    },
    FourResign {
        seat: u8,
    },
    /// Host → clients: the match ended ("team:red_yellow" | "ffa:red" | ...).
    FourResult {
        result: String,
    },

    Resign,
    DrawOffer,
    DrawResponse {
        accepted: bool,
    },
    Ping {
        t: u64,
    },
    Pong {
        t: u64,
    },
    Rematch,
    Bye,
    Chat {
        text: String,
    },
}

impl Message {
    /// Serialize to a single newline-terminated JSON line.
    pub fn encode(&self) -> String {
        let mut s = serde_json::to_string(self).expect("serialize message");
        s.push('\n');
        s
    }

    /// Parse one JSON line.
    pub fn decode(line: &str) -> Result<Message, serde_json::Error> {
        serde_json::from_str(line.trim())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn round_trip(m: Message) {
        let line = m.encode();
        assert!(line.ends_with('\n'));
        assert_eq!(Message::decode(&line).unwrap(), m);
    }

    #[test]
    fn messages_round_trip() {
        round_trip(Message::Hello {
            name: "Ada".into(),
            protocol_version: PROTOCOL_VERSION,
            base_minutes: 5,
            increment_seconds: 2,
        });
        round_trip(Message::Start {
            white_name: "Ada".into(),
            black_name: "Bob".into(),
            you_are_white: true,
            base_minutes: 5,
            increment_seconds: 2,
            fen: chess_core::START_FEN.into(),
            variant: "standard".into(),
        });
        round_trip(Message::Move {
            uci: "e2e4".into(),
            ply: 1,
            white_ms: 300_000,
            black_ms: 300_000,
        });
        round_trip(Message::BugStart {
            seats: vec!["A".into(), "B".into(), "C".into(), "D".into()],
            your_seats: vec![1, 2],
            base_minutes: 3,
            increment_seconds: 0,
        });
        round_trip(Message::BugMove {
            board: 1,
            uci: "N@f3".into(),
            white_ms: 180_000,
            black_ms: 175_000,
        });
        round_trip(Message::BugPass {
            to_board: 0,
            to_color: 1,
            piece: 4,
        });
        round_trip(Message::BugResult {
            winning_team: 2,
            reason: "checkmate".into(),
            board: 0,
        });
        round_trip(Message::BugResign { seat: 3 });
        round_trip(Message::FourStart {
            format: "ffa".into(),
            seats: vec!["A".into(), "B".into(), "C".into(), "D".into()],
            your_seats: vec![0],
        });
        round_trip(Message::FourMove {
            seat: 2,
            uci: "g1i1".into(),
        });
        round_trip(Message::FourResign { seat: 1 });
        round_trip(Message::FourResult {
            result: "ffa:red".into(),
        });
        round_trip(Message::Resign);
        round_trip(Message::DrawOffer);
        round_trip(Message::DrawResponse { accepted: true });
        round_trip(Message::Ping { t: 42 });
        round_trip(Message::Bye);
        round_trip(Message::Chat { text: "gg".into() });
    }

    #[test]
    fn move_tag_is_snake_case() {
        let line = Message::Resign.encode();
        assert!(line.contains("\"type\":\"resign\""));
    }
}
