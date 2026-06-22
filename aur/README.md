# AUR packages

Three flavours (each its own AUR repo). All install `/usr/bin/chess`; they
`conflict` so only one is installed at a time.

| Package | Build | When to use |
|---------|-------|-------------|
| [`chess-bin`](chess-bin/) | installs the prebuilt GitHub release tarball | fastest, no toolchain |
| [`chess`](chess/) | builds the tagged release from source | reproducible source build |
| [`chess-git`](chess-git/) | builds the latest `main` from source | bleeding edge |

`chess` / `chess-git` build with Flutter + Rust, so they need
`makedepends=(flutter rust clang cmake ninja pkgconf git)`. If your AUR `flutter`
package is named differently (e.g. `flutter-bin`), adjust that one makedepend.

## Publish / update (uses your existing `~/.ssh/aur` key)

```fish
fish aur/publish-aur.fish chess-bin   # or: chess  |  chess-git
```

The script: ensures the ssh-config entry → tests AUR auth → clones the package
repo → copies its `PKGBUILD`/`.SRCINFO` → `updpkgsums` + regenerates `.SRCINFO`
→ `makepkg -si` (build/install to verify) → shows the diff → asks before pushing
(to `master`, which the AUR requires).

> You only need ONE key for all packages — AUR keys are per-account. No new keys.

## Manual (per package)

```fish
git clone ssh://aur@aur.archlinux.org/chess.git ~/aur-chess
cd ~/aur-chess
cp ~/Belgeler/AI/Code/Chess/aur/chess/{PKGBUILD,.SRCINFO} .
updpkgsums; and makepkg --printsrcinfo > .SRCINFO
makepkg -si
git add -A; and git commit -m "chess 1.0.1"; and git branch -M master; and git push origin master
```

## New release

After tagging a new `vX.Y.Z` (CI builds the assets):

- `chess-bin` / `chess`: bump `pkgver` (reset `pkgrel=1`), then re-run the script.
- `chess-git`: nothing to bump — `pkgver()` tracks git; just re-run to refresh.
