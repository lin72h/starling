#!/usr/bin/env bash
# Publish ui/ to the public site repo that serves starling.build.
#
#   ui/deploy.sh [git-url]
#
# Copies this folder's CONTENTS to the site repo's root (GitHub Pages serves
# only from / or /docs, never from /ui) and pushes. Default target:
# git@github.com:starling-build/www.git — override with the argument or
# $STARLING_SITE_REPO.
#
# One-time setup on the target repo: Settings -> Pages -> source `main` / root,
# custom domain starling.build. See README.md for the DNS records.
set -euo pipefail

UI="$(cd "$(dirname "$0")" && pwd)"
REPO="${1:-${STARLING_SITE_REPO:-https://github.com/starling-build/www.git}}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

git clone --depth 1 "$REPO" "$WORK/site" 2>/dev/null || {
    echo "error: cannot clone $REPO — create it (public) first" >&2; exit 1
}

# Replace tracked content, keeping the site repo's own git metadata.
find "$WORK/site" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -r "$UI"/index.html "$UI"/why.html "$UI"/sdk.html "$UI"/start.html "$UI"/guide.html \
      "$UI"/CNAME "$UI"/img "$UI"/video "$WORK/site/"

cd "$WORK/site"
# A freshly created repo has an unborn HEAD, possibly on the wrong branch name.
git symbolic-ref HEAD refs/heads/main
if git diff --quiet && git diff --cached --quiet && [ -z "$(git status --porcelain)" ]; then
    echo "no changes to publish"; exit 0
fi
git add -A
git commit -q -m "site: publish from starling-desktop/ui @ $(cd "$UI" && git rev-parse --short HEAD)"
git push -u origin main
echo "published -> $REPO"
