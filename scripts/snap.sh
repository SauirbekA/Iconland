#!/bin/zsh
# Render a theme page offscreen with sample desktop icons and save a PNG (uses the same WebKit as the app).
#   scripts/snap.sh <page.html> <out.png> [--wait 4] [--size 1512x982] [--settings '{"key":1}'] [--icons rects.json] [--move 3]
# Prints JS errors collected on the page ("page: {err:[...], fps:...}").
cd "${0:A:h}/.."
BIN=$(swift build -c release --show-bin-path)/Iconland
[[ -x "$BIN" ]] || { echo "build first: swift build -c release"; exit 1; }
ICONLAND_WEB="$PWD/web" exec "$BIN" --snap "$@"
