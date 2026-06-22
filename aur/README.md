# AUR package (`satranc-bin`)

A binary AUR package that installs the prebuilt Linux release from GitHub
Releases (no Flutter/Rust toolchain needed to install).

These files are kept in the repo for reference; the AUR has its **own** git
repo. Publishing is manual (needs your AUR SSH key — the one you used before).

## First-time publish

```sh
# 1) Clone the (empty) AUR repo for the package name
git clone ssh://aur@aur.archlinux.org/satranc-bin.git
cd satranc-bin

# 2) Copy PKGBUILD + .SRCINFO from this repo's aur/ dir
cp /path/to/chess/aur/PKGBUILD .
cp /path/to/chess/aur/.SRCINFO .

# 3) (recommended) pin real checksums instead of SKIP, then refresh .SRCINFO
updpkgsums
makepkg --printsrcinfo > .SRCINFO

# 4) Test it builds + installs cleanly
makepkg -si

# 5) Commit + push to the AUR
git add PKGBUILD .SRCINFO
git commit -m "satranc-bin 1.0.0"
git push
```

## Updating for a new release

1. Bump `pkgver` (and reset `pkgrel=1`) in `PKGBUILD`.
2. `updpkgsums` then `makepkg --printsrcinfo > .SRCINFO`.
3. Commit + push.

Requires a published GitHub Release `v<pkgver>` with the
`chess-<pkgver>-linux-x86_64.tar.gz` asset (the release workflow produces it).
