//! Off-UI-thread AI search exposed to Flutter as a stream, with cancellation.
//!
//! `ai_search` takes a [`StreamSink`], so flutter_rust_bridge runs it on a Rust
//! worker thread (never the Dart UI isolate) and surfaces it as a Dart `Stream`.
//! It emits one [`AiUpdate`] per completed search depth plus a final `done`
//! update. `ai_cancel(id)` flips a shared flag the search polls.

use std::collections::HashMap;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex, OnceLock};

use chess_ai::{AiConfig, Engine, SearchInfo};
use chess_core::parse_fen;
use flutter_rust_bridge::frb;

use crate::frb_generated::StreamSink;

/// One progress update from the search.
#[derive(Clone, Debug)]
pub struct AiUpdate {
    pub depth: u32,
    pub score_cp: i32,
    pub best_uci: String,
    pub pv: Vec<String>,
    pub nodes: u64,
    pub done: bool,
}

/// Difficulty configuration passed from Dart.
#[derive(Clone, Copy, Debug)]
pub struct AiConfigDto {
    pub max_depth: u32,
    pub move_time_ms: Option<u64>,
    pub eval_noise: i32,
    pub blunder_chance: f32,
    pub top_n_random: u32,
    pub contempt: i32,
    pub seed: u64,
}

fn registry() -> &'static Mutex<HashMap<u64, Arc<AtomicBool>>> {
    static R: OnceLock<Mutex<HashMap<u64, Arc<AtomicBool>>>> = OnceLock::new();
    R.get_or_init(|| Mutex::new(HashMap::new()))
}

/// Lock the registry, recovering from a poisoned mutex (a prior search panic)
/// instead of cascading the panic — the map itself is always in a valid state.
fn reg() -> std::sync::MutexGuard<'static, HashMap<u64, Arc<AtomicBool>>> {
    registry().lock().unwrap_or_else(|e| e.into_inner())
}

/// Removes a search's cancel flag on drop, so the registry entry is cleared on
/// every exit path — normal return, early `?`, or an unwinding panic in the
/// search — preventing leaked flags and stale-id cancellation.
struct RegistryGuard {
    id: u64,
}

impl Drop for RegistryGuard {
    fn drop(&mut self) {
        reg().remove(&self.id);
    }
}

/// Run a search for `fen`, streaming progress. `search_id` identifies it for
/// cancellation. Runs off the UI thread (StreamSink param).
pub fn ai_search(
    search_id: u64,
    fen: String,
    config: AiConfigDto,
    history: Vec<u64>,
    variant: crate::api::game::GameVariant,
    white_checks: u32,
    black_checks: u32,
    white_hand: Vec<u32>,
    black_hand: Vec<u32>,
    promoted: u64,
    sink: StreamSink<AiUpdate>,
) -> Result<(), String> {
    let mut pos = parse_fen(&fen).map_err(|e| e.to_string())?;
    // The FEN carries no variant/reserve info; restore it so the engine plays by
    // the variant's rules (three-check counts, Crazyhouse hand + promoted mask).
    pos.variant = crate::api::game::to_variant(variant);
    pos.checks = [white_checks as u8, black_checks as u8];
    if white_hand.len() == 5 && black_hand.len() == 5 {
        for i in 0..5 {
            pos.hand[0][i] = white_hand[i] as u8;
            pos.hand[1][i] = black_hand[i] as u8;
        }
    }
    pos.promoted = promoted;
    // Re-derive the hash so it matches the game's (includes check/hand keys) —
    // keeps transposition + repetition detection consistent with the history.
    pos.hash = pos.compute_hash();

    let flag = Arc::new(AtomicBool::new(false));
    reg().insert(search_id, flag.clone());
    let _guard = RegistryGuard { id: search_id };

    let mut eng = Engine::new(19);
    eng.set_game_history(&history);
    // Fog of War searches pseudo-legal moves (no king-safety filter), so the
    // branching factor is much larger — cap depth/time so moves stay snappy.
    let is_fog = pos.variant == chess_core::Variant::FogOfWar;
    let cfg = AiConfig {
        max_depth: {
            let d = config.max_depth.clamp(1, 255) as u8;
            if is_fog {
                d.min(4)
            } else {
                d
            }
        },
        move_time_ms: if is_fog {
            Some(config.move_time_ms.unwrap_or(800).min(500))
        } else {
            config.move_time_ms
        },
        eval_noise: config.eval_noise.max(0),
        blunder_chance: config.blunder_chance.clamp(0.0, 1.0),
        top_n_random: config.top_n_random.clamp(1, 255) as u8,
        contempt: config.contempt,
        seed: config.seed,
    };

    let cancel_flag = flag.clone();
    let cancel = move || cancel_flag.load(Ordering::Relaxed);

    let stop_flag = flag.clone();
    let on_info = |info: &SearchInfo| {
        let update = AiUpdate {
            depth: info.depth as u32,
            score_cp: info.score_cp,
            best_uci: info.best.map(|m| m.to_uci()).unwrap_or_default(),
            pv: info.pv.iter().map(|m| m.to_uci()).collect(),
            nodes: info.nodes,
            done: false,
        };
        // If the Dart listener was dropped, stop searching.
        if sink.add(update).is_err() {
            stop_flag.store(true, Ordering::Relaxed);
        }
    };

    let result = eng.search_with_config(&pos, cfg, &cancel, on_info);

    let _ = sink.add(AiUpdate {
        depth: result.depth as u32,
        score_cp: result.score_cp,
        best_uci: result.best.map(|m| m.to_uci()).unwrap_or_default(),
        pv: result.pv.iter().map(|m| m.to_uci()).collect(),
        nodes: result.nodes,
        done: true,
    });

    Ok(())
}

/// Request cancellation of the search with `search_id`.
#[frb(sync)]
pub fn ai_cancel(search_id: u64) {
    if let Some(f) = reg().get(&search_id) {
        f.store(true, Ordering::Relaxed);
    }
}
