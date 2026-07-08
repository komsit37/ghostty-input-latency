#!/usr/bin/env bash
# Launch a terminal fullscreen running flip.py, so you can point the harness at it.
# Usage: ./run.sh ghostty | ./run.sh alacritty
set -euo pipefail
cd "$(dirname "$0")"
DIR="$PWD"
READER="${2:-flip.py}"   # flip.py (full-screen) or block.py (localized)

case "${1:-}" in
  ghostty)
    exec /Applications/Ghostty.app/Contents/MacOS/ghostty \
      --config-file="$DIR/ghostty.conf" --fullscreen=true \
      -e "$DIR/$READER"
    ;;
  alacritty)
    exec /Applications/Alacritty.app/Contents/MacOS/alacritty \
      --config-file "$DIR/alacritty.toml" -o 'window.startup_mode="Fullscreen"' \
      -e "$DIR/$READER"
    ;;
  *)
    echo "usage: $0 ghostty|alacritty [flip.py|block.py]" >&2
    exit 1
    ;;
esac
