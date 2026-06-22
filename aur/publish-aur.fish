#!/usr/bin/env fish
# Publish / update an AUR package using your EXISTING ~/.ssh/aur key.
# Usage:  fish aur/publish-aur.fish [chess-bin|chess|chess-git]   (default: chess-bin)
set -l pkg $argv[1]
test -z "$pkg"; and set pkg chess-bin
set -l repo (realpath (dirname (status filename))/..)
set -l work ~/aur-$pkg

if not test -f "$repo/aur/$pkg/PKGBUILD"
    echo "!! unknown package '$pkg' (expected: chess-bin, chess, chess-git)"
    exit 1
end

# 1) Make git use your AUR key for aur.archlinux.org (idempotent).
if not grep -q 'Host aur.archlinux.org' ~/.ssh/config 2>/dev/null
    printf 'Host aur.archlinux.org\n    User aur\n    IdentityFile ~/.ssh/aur\n    IdentitiesOnly yes\n' >> ~/.ssh/config
    chmod 600 ~/.ssh/config
    echo ">> added aur.archlinux.org to ~/.ssh/config"
end

# 2) Verify SSH auth to the AUR.
echo ">> testing AUR ssh ..."
ssh aur@aur.archlinux.org help >/dev/null
or begin
    echo "!! AUR ssh failed — check the key at https://aur.archlinux.org → My Account"
    exit 1
end

# 3) Clone the (empty on first publish) AUR repo, or reuse it.
if not test -d $work
    git clone ssh://aur@aur.archlinux.org/$pkg.git $work
end
cd $work

# 4) Copy packaging files from the project.
cp $repo/aur/$pkg/PKGBUILD $repo/aur/$pkg/.SRCINFO .

# 5) Pin checksums (no-op for git sources) + refresh metadata (computes the real
#    -git pkgver too).
updpkgsums
makepkg --printsrcinfo > .SRCINFO

# 6) Build + install locally to prove it works before publishing.
makepkg -si

# 7) Review, then push (the AUR only accepts the 'master' branch).
git add PKGBUILD .SRCINFO
git --no-pager diff --cached --stat
set -l ver (awk -F" = " '/pkgver =/{print $2; exit}' .SRCINFO)
read -P "Push $pkg $ver to the AUR? [y/N] " ans
if test "$ans" = y -o "$ans" = Y
    git commit -m "$pkg $ver"
    git branch -M master
    if git push origin master
        echo ">> done: https://aur.archlinux.org/packages/$pkg"
    else
        echo "!! push failed (see error above)"
    end
else
    echo ">> skipped. later:  cd $work; and git branch -M master; and git push origin master"
end
