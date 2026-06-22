#!/usr/bin/env fish
# Publish / update the chess-bin AUR package using your EXISTING ~/.ssh/aur key.
# Run from anywhere:  fish aur/publish-aur.fish
set -l pkg chess-bin
set -l repo (realpath (dirname (status filename))/..)
set -l work ~/aur-$pkg

# 1) Make git use your AUR key for aur.archlinux.org (idempotent).
if not grep -q 'Host aur.archlinux.org' ~/.ssh/config 2>/dev/null
    printf 'Host aur.archlinux.org\n    User aur\n    IdentityFile ~/.ssh/aur\n    IdentitiesOnly yes\n' >> ~/.ssh/config
    chmod 600 ~/.ssh/config
    echo ">> added aur.archlinux.org to ~/.ssh/config"
end

# 2) Verify SSH auth to the AUR (prints your account; aborts if it fails).
echo ">> testing AUR ssh ..."
ssh aur@aur.archlinux.org help >/dev/null
or begin
    echo "!! AUR ssh failed — check the key is added at https://aur.archlinux.org → My Account"
    exit 1
end

# 3) Clone the (empty on first publish) AUR repo, or reuse it.
if not test -d $work
    git clone ssh://aur@aur.archlinux.org/$pkg.git $work
end
cd $work

# 4) Copy packaging files from the project.
cp $repo/aur/PKGBUILD $repo/aur/.SRCINFO .

# 5) Pin real checksums (downloads the GitHub release assets) + refresh metadata.
updpkgsums
makepkg --printsrcinfo > .SRCINFO

# 6) Build + install locally to prove it works before publishing.
makepkg -si

# 7) Review, then push.
git add PKGBUILD .SRCINFO
git --no-pager diff --cached --stat
set -l ver (grep '^pkgver=' PKGBUILD | cut -d= -f2)
read -P "Push $pkg $ver to the AUR? [y/N] " ans
if test "$ans" = y -o "$ans" = Y
    git commit -m "$pkg $ver"
    git push
    echo ">> done: https://aur.archlinux.org/packages/$pkg"
else
    echo ">> skipped. later:  cd $work; and git commit -am '$pkg $ver'; and git push"
end
