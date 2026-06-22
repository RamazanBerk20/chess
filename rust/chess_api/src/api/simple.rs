#[flutter_rust_bridge::frb(sync)] // Synchronous mode for simplicity of the demo
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

/// Round-trips through the pure `chess_core` crate, proving the workspace wiring:
/// Flutter → chess_api (bridge) → chess_core.
#[flutter_rust_bridge::frb(sync)]
pub fn engine_info() -> String {
    chess_core::engine_info()
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}
