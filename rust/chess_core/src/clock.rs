//! Chess clock as a pure, deterministic state machine.
//!
//! The core never reads the wall clock; the caller drives elapsed time via
//! [`Clock::elapse`] (so it stays unit-testable and is the single source of
//! truth for remaining time, increments and flag-fall). The UI renders a smooth
//! countdown but authoritative remaining time comes from here.

use crate::types::Color;

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum TimeControl {
    /// No clock.
    Infinite,
    /// Fischer increment: each side starts with `base_ms` and gains
    /// `increment_ms` after completing a move.
    Fischer { base_ms: u64, increment_ms: u64 },
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct Clock {
    tc: TimeControl,
    white_ms: i64,
    black_ms: i64,
    /// Side whose clock is currently counting down.
    running: Color,
}

impl Clock {
    pub fn new(tc: TimeControl) -> Clock {
        let base = match tc {
            TimeControl::Infinite => 0,
            TimeControl::Fischer { base_ms, .. } => base_ms as i64,
        };
        Clock {
            tc,
            white_ms: base,
            black_ms: base,
            running: Color::White,
        }
    }

    #[inline]
    pub fn is_infinite(&self) -> bool {
        matches!(self.tc, TimeControl::Infinite)
    }

    #[inline]
    pub fn running(&self) -> Color {
        self.running
    }

    #[inline]
    pub fn remaining(&self, c: Color) -> i64 {
        match c {
            Color::White => self.white_ms,
            Color::Black => self.black_ms,
        }
    }

    /// Apply move completion by `mover`: add the Fischer increment to `mover`
    /// and hand the running clock to the opponent.
    pub fn on_move(&mut self, mover: Color) {
        if let TimeControl::Fischer { increment_ms, .. } = self.tc {
            let inc = increment_ms as i64;
            match mover {
                Color::White => self.white_ms += inc,
                Color::Black => self.black_ms += inc,
            }
        }
        self.running = mover.opp();
    }

    /// Subtract `ms` from the running side. Returns true if that side just
    /// flagged (ran out of time).
    pub fn elapse(&mut self, ms: i64) -> bool {
        if self.is_infinite() {
            return false;
        }
        match self.running {
            Color::White => {
                self.white_ms -= ms;
                if self.white_ms <= 0 {
                    self.white_ms = 0;
                    return true;
                }
            }
            Color::Black => {
                self.black_ms -= ms;
                if self.black_ms <= 0 {
                    self.black_ms = 0;
                    return true;
                }
            }
        }
        false
    }

    /// Reconcile remaining time from a (semi-trusted) LAN peer. Clamped to a
    /// sane range so a buggy/hostile peer can't set absurd or negative clocks.
    pub fn set(&mut self, white_ms: i64, black_ms: i64) {
        let max = match self.tc {
            TimeControl::Infinite => return,
            TimeControl::Fischer {
                base_ms,
                increment_ms,
            } => (base_ms + increment_ms.saturating_mul(1000)) as i64,
        };
        self.white_ms = white_ms.clamp(0, max);
        self.black_ms = black_ms.clamp(0, max);
    }

    /// Which side, if any, has flagged.
    pub fn flagged(&self) -> Option<Color> {
        if self.is_infinite() {
            None
        } else if self.white_ms <= 0 {
            Some(Color::White)
        } else if self.black_ms <= 0 {
            Some(Color::Black)
        } else {
            None
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn infinite_never_flags() {
        let mut c = Clock::new(TimeControl::Infinite);
        assert!(c.is_infinite());
        assert!(!c.elapse(10_000_000));
        assert_eq!(c.flagged(), None);
    }

    #[test]
    fn base_and_running_init() {
        let c = Clock::new(TimeControl::Fischer {
            base_ms: 60_000,
            increment_ms: 1_000,
        });
        assert_eq!(c.remaining(Color::White), 60_000);
        assert_eq!(c.remaining(Color::Black), 60_000);
        assert_eq!(c.running(), Color::White);
    }

    #[test]
    fn elapse_decrements_running_side_only() {
        let mut c = Clock::new(TimeControl::Fischer {
            base_ms: 10_000,
            increment_ms: 0,
        });
        assert!(!c.elapse(3_000));
        assert_eq!(c.remaining(Color::White), 7_000);
        assert_eq!(c.remaining(Color::Black), 10_000);
    }

    #[test]
    fn on_move_adds_increment_and_switches() {
        let mut c = Clock::new(TimeControl::Fischer {
            base_ms: 10_000,
            increment_ms: 2_000,
        });
        c.elapse(3_000); // white -> 7000
        c.on_move(Color::White); // +2000 to white -> 9000, running -> black
        assert_eq!(c.remaining(Color::White), 9_000);
        assert_eq!(c.running(), Color::Black);
        assert!(!c.elapse(1_000)); // black -> 9000
        assert_eq!(c.remaining(Color::Black), 9_000);
    }

    #[test]
    fn flag_fall_detected() {
        let mut c = Clock::new(TimeControl::Fischer {
            base_ms: 1_000,
            increment_ms: 0,
        });
        assert!(c.elapse(1_500)); // white flags
        assert_eq!(c.remaining(Color::White), 0);
        assert_eq!(c.flagged(), Some(Color::White));
    }
}
