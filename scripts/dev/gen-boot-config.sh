#!/bin/bash
# Writes a throwaway boot config pointing at a real OpenStarboundEX install's
# assets (same shape as run-dev.sh's own boot config) without launching
# anything. Split out of run-dev.sh so both it and the VS Code debug configs
# under .vscode/ (see DEV_LOOP.md) share one place that knows the boot config
# shape - not meant to be run directly.
#
# Usage: scripts/dev/gen-boot-config.sh <output-path> <storage-dir>
set -euo pipefail
cd "$(dirname "$0")/../.."

OUT="$1"
STORAGE_DIR="$2"

HOME_DIR="${OPENSTARBOUND_HOME:-$HOME/Games/OpenStarboundEX}"

if [ ! -d "$HOME_DIR/assets" ]; then
  echo "error: $HOME_DIR/assets not found - set OPENSTARBOUND_HOME to a real OpenStarboundEX install" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT")" "$STORAGE_DIR"
# Resolve to an absolute path: the game chdirs to its own executable's
# directory (dist/) very early in startup (SDL_GetBasePath +
# File::changeDirectory, in StarMainApplication_sdl.cpp), regardless of the
# cwd it was launched from - a relative path here would silently resolve
# against dist/ instead of wherever this script was run from, fail to find
# the directory, and crash with an ApplicationException.
STORAGE_DIR="$(cd "$STORAGE_DIR" && pwd)"
cat > "$OUT" <<EOF
{
  "assetDirectories" : [
    "$HOME_DIR/assets/",
    "$HOME_DIR/mods/"
  ],
  "storageDirectory" : "$STORAGE_DIR",
  "logDirectory" : "$(pwd)/build/linux-dev/"
}
EOF
