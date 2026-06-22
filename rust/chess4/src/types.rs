//! Value types for 4-player chess (chess.com style).

/// The four armies, in turn order Red → Blue → Yellow → Green.
#[derive(Clone, Copy, PartialEq, Eq, Debug, Hash)]
pub enum Player {
    Red,
    Blue,
    Yellow,
    Green,
}

impl Player {
    pub const ALL: [Player; 4] = [Player::Red, Player::Blue, Player::Yellow, Player::Green];

    pub fn index(self) -> usize {
        match self {
            Player::Red => 0,
            Player::Blue => 1,
            Player::Yellow => 2,
            Player::Green => 3,
        }
    }

    pub fn from_index(i: usize) -> Player {
        Player::ALL[i % 4]
    }

    pub fn next(self) -> Player {
        Player::from_index(self.index() + 1)
    }

    /// Team 1 = Red+Yellow, team 2 = Blue+Green. Returns 1 or 2.
    pub fn team(self) -> u8 {
        match self {
            Player::Red | Player::Yellow => 1,
            Player::Blue | Player::Green => 2,
        }
    }

    pub fn partner(self) -> Player {
        match self {
            Player::Red => Player::Yellow,
            Player::Yellow => Player::Red,
            Player::Blue => Player::Green,
            Player::Green => Player::Blue,
        }
    }

    /// The pawn-advance vector (toward the centre) for this army.
    pub fn forward(self) -> (i8, i8) {
        match self {
            Player::Red => (0, 1),    // bottom edge → up
            Player::Yellow => (0, -1), // top edge → down
            Player::Blue => (1, 0),    // left edge → right
            Player::Green => (-1, 0),  // right edge → left
        }
    }

    /// The two diagonal capture vectors for this army's pawns.
    pub fn pawn_captures(self) -> [(i8, i8); 2] {
        let (fc, fr) = self.forward();
        // The two diagonals one step forward, splayed left/right of `forward`.
        if fc == 0 {
            [(-1, fr), (1, fr)]
        } else {
            [(fc, -1), (fc, 1)]
        }
    }
}

#[derive(Clone, Copy, PartialEq, Eq, Debug, Hash)]
pub enum Piece {
    Pawn,
    Knight,
    Bishop,
    Rook,
    Queen,
    King,
}

impl Piece {
    /// Free-for-all capture value (king = 0).
    pub fn value(self) -> u32 {
        match self {
            Piece::Pawn => 1,
            Piece::Knight => 3,
            Piece::Bishop => 5,
            Piece::Rook => 5,
            Piece::Queen => 9,
            Piece::King => 0,
        }
    }

    pub fn to_char(self) -> char {
        match self {
            Piece::Pawn => 'p',
            Piece::Knight => 'n',
            Piece::Bishop => 'b',
            Piece::Rook => 'r',
            Piece::Queen => 'q',
            Piece::King => 'k',
        }
    }
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Team {
    RedYellow,
    BlueGreen,
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Format {
    Teams,
    FreeForAll,
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum PlayerStatus {
    Active,
    Checkmated,
    Stalemated,
    Resigned,
}

impl PlayerStatus {
    pub fn is_active(self) -> bool {
        self == PlayerStatus::Active
    }
}

/// A board coordinate: `col`/`row` each 0..13, (0,0) = bottom-left.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct Coord {
    pub col: i8,
    pub row: i8,
}

impl Coord {
    pub fn new(col: i8, row: i8) -> Coord {
        Coord { col, row }
    }
}
