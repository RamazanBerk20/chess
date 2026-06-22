# Chess

Cross-platform chess app: a **Flutter** front end over a hand-written **Rust** core
(rules engine + AI), connected via **flutter_rust_bridge v2**. Targets Linux,
Windows and Android.

## Download / Install

Grab the latest build from **[Releases](https://github.com/RamazanBerk20/chess/releases/latest)**:

| Platform | File |
|----------|------|
| Android  | `chess-<version>-android.apk` (sideload) |
| Windows  | `chess-<version>-windows-setup.exe` (installer) or the portable `.zip` |
| Linux    | `.AppImage` (portable), `.deb` (Debian/Ubuntu), or the `.tar.gz` bundle |

Arch Linux: install **`satranc-bin`** from the AUR (e.g. `yay -S satranc-bin`).

The app checks GitHub Releases on launch and offers an in-app update when a newer
version is available (Settings → Support → Check for updates).

## Structure

- `rust/chess_core` — bitboard rules engine, move generation, FEN/SAN, Zobrist,
  clocks, termination rules (perft-verified).
- `rust/chess_ai` — negamax + alpha-beta search, quiescence, transposition table,
  tapered PeSTO evaluation, configurable difficulty.
- `rust/chess_net` — LAN discovery (mDNS) + newline-JSON TCP protocol.
- `rust/chess_api` — the flutter_rust_bridge boundary.
- `rust/puzzle_prep` — dev tool that builds `assets/puzzles/puzzles.json`.
- `lib/` — Flutter app (Riverpod state, custom-painted board).

## Features

Single player vs AI (configurable difficulty), two-player same-device, two-player
over LAN (auto-discovery, resign/draw/disconnect handling), plus **variants**:
Three-Check, King of the Hill, Chess960, Atomic, Crazyhouse, Fog of War,
**Bughouse** (2-board) and **4-player** (14×14). Premove (queued chains +
castling) in every mode where it applies. Clocks (Fischer + presets, flag-fall
with insufficient-material draw), post-game **analysis** (accuracy, move
classification, eval graph), a 100-puzzle trainer (hints, persisted progress),
saved/resumable games, 10 UI languages, and settings (board themes,
accessibility, sound/haptics, hints, animation, defaults).

## Puzzles

The bundled `assets/puzzles/puzzles.json` is curated from the
[Lichess open puzzle database](https://database.lichess.org/#puzzles), which is
released into the **public domain (CC0)**. 100 puzzles are sampled across the
rating range (easy → hard) by `rust/puzzle_prep`.

## Build

Prereqs: Flutter 3.44+, `rustup` with the host toolchain, and
`flutter_rust_bridge_codegen` 2.12 (`cargo install flutter_rust_bridge_codegen --version 2.12.0 --locked`).

```sh
# regenerate the bridge bindings after changing the Rust API
flutter_rust_bridge_codegen generate
# Linux desktop
flutter run -d linux            # or: flutter build linux
```

### Android

Needs the Android SDK + NDK 28.2.13676358 and the Rust Android target:

```sh
rustup target add aarch64-linux-android
export ANDROID_HOME=$HOME/Android/Sdk
export ANDROID_NDK_HOME=$ANDROID_HOME/ndk/28.2.13676358
flutter build apk --debug --target-platform android-arm64
flutter install -d <device-id>
```

The bundled cargokit Gradle plugin (`rust_builder/cargokit/gradle/plugin.gradle`)
is patched for Gradle 9 (`ExecOperations` instead of the removed `Project.exec`,
`layout.buildDirectory` instead of `project.buildDir`).

### Dev container

`.devcontainer/` provides the full toolchain (Flutter, Rust + Android targets,
frb, Android SDK/NDK, GTK desktop deps). Open with "Reopen in Container".

## Tests

```sh
cd rust && cargo test --release --workspace   # rules (perft gate), AI, clocks, protocol
flutter test                                  # widget/unit
```

> Use `--release`: the engine is unoptimised in debug, so a depth-6 Fog-of-War
> search test takes ~40 min in debug vs seconds in release.

## Releases (CI)

Pushing a tag `v*` triggers `.github/workflows/release.yml`, which builds the
Android APK, the Windows installer (+ portable zip) and the Linux
AppImage/`.deb`/`.tar.gz`, and attaches them all to a GitHub Release.

```sh
# bump `version:` in pubspec.yaml first, then:
git tag v1.0.0 && git push origin v1.0.0
```

## Support

If you enjoy the app, you can support development via
**[GitHub Sponsors](https://github.com/sponsors/RamazanBerk20)** (also reachable
in-app: Settings → Support → Donate). Thank you! ♥

## License

[MIT](LICENSE) © Ramazan Berk Şirin
