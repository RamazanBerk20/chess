#!/usr/bin/env bash
# Build a portable AppImage from the Flutter Linux release bundle.
# Requires $VERSION in the environment. Run from the repo root.
set -euo pipefail

BUNDLE="build/linux/x64/release/bundle"
APPDIR="AppDir"
VERSION="${VERSION:?set VERSION}"

rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin"
# Flutter resolves data/ and lib/ next to the executable, so keep the whole
# bundle together under usr/bin.
cp -r "$BUNDLE"/. "$APPDIR/usr/bin/"
cp installers/linux/chess.desktop "$APPDIR/chess.desktop"
cp assets/icon/chess.png "$APPDIR/chess.png"

cat > "$APPDIR/AppRun" <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
export LD_LIBRARY_PATH="$HERE/usr/bin/lib:${LD_LIBRARY_PATH:-}"
exec "$HERE/usr/bin/chess" "$@"
EOF
chmod +x "$APPDIR/AppRun"

if [ ! -x ./appimagetool ]; then
  wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -O appimagetool
  chmod +x appimagetool
fi

# No FUSE on CI runners → extract-and-run.
ARCH=x86_64 ./appimagetool --appimage-extract-and-run "$APPDIR" "Chess-${VERSION}-x86_64.AppImage"
echo "Built Chess-${VERSION}-x86_64.AppImage"
