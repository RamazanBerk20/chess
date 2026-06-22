#!/usr/bin/env bash
# Build a .deb from the Flutter Linux release bundle. Requires $VERSION.
# Run from the repo root.
set -euo pipefail

BUNDLE="build/linux/x64/release/bundle"
VERSION="${VERSION:?set VERSION}"
PKG="deb/chess"

rm -rf deb
mkdir -p "$PKG/DEBIAN" "$PKG/opt/chess" "$PKG/usr/bin" \
         "$PKG/usr/share/applications" \
         "$PKG/usr/share/icons/hicolor/512x512/apps"

cp -r "$BUNDLE"/. "$PKG/opt/chess/"

cat > "$PKG/usr/bin/chess" <<'EOF'
#!/bin/sh
exec /opt/chess/chess "$@"
EOF
chmod +x "$PKG/usr/bin/chess"

cp installers/linux/chess.desktop "$PKG/usr/share/applications/chess.desktop"
cp assets/icon/chess.png "$PKG/usr/share/icons/hicolor/512x512/apps/chess.png"

cat > "$PKG/DEBIAN/control" <<EOF
Package: chess
Version: ${VERSION}
Section: games
Priority: optional
Architecture: amd64
Depends: libgtk-3-0, libstdc++6, libblkid1
Maintainer: Ramazan Berk Şirin <ramazanberksirin@protonmail.com>
Homepage: https://github.com/RamazanBerk20/chess
Description: Chess with variants, AI, LAN and puzzles
 A cross-platform chess app (Flutter UI over a Rust rules+AI engine) with
 Fog of War, Bughouse, 4-player, Crazyhouse, Atomic and more, plus LAN play,
 puzzles and post-game analysis.
EOF

dpkg-deb --build --root-owner-group "$PKG" "chess_${VERSION}_amd64.deb"
echo "Built chess_${VERSION}_amd64.deb"
