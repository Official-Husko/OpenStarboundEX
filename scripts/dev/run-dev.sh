#!/bin/bash
# Runs the locally-built dev binary (see scripts/dev/watch.sh) against a
# real, already-assembled OpenStarboundEX install's assets/mods/storage -
# this repo has no base game assets of its own (see CLAUDE.md), so a Debug
# build's dist/ has nothing to actually load on its own.
#
# Usage:
#   scripts/dev/run-dev.sh            # runs the client
#   scripts/dev/run-dev.sh server     # runs the server
#   scripts/dev/run-dev.sh -- -loglevel debug   # extra args passed through
#
# Set OPENSTARBOUND_HOME to the install's root directory (the one containing
# assets/, mods/, storage/, logs/ - NOT its linux/ subfolder), otherwise
# defaults to ~/Games/OpenStarboundEX.
#
# Storage is shared with that install by default, i.e. this runs against
# your real savegames, not a throwaway world - set OPENSTARBOUND_DEV_STORAGE
# to a scratch directory instead if you'd rather not risk a Debug build
# touching real saves.
set -euo pipefail
cd "$(dirname "$0")/../.."

TARGET="client"
if [ "${1:-}" = "server" ]; then
  TARGET="server"
  shift
elif [ "${1:-}" = "client" ]; then
  shift
fi
if [ "${1:-}" = "--" ]; then
  shift
fi

HOME_DIR="${OPENSTARBOUND_HOME:-$HOME/Games/OpenStarboundEX}"
STORAGE_DIR="${OPENSTARBOUND_DEV_STORAGE:-$HOME_DIR/storage/}"

# Per-target filename (not one shared file) so running client and server at
# the same time - see scripts/dev/run-dev-multiplayer.sh - doesn't have one
# overwrite the other's storageDirectory mid-run.
BOOT_CONFIG="build/linux-dev/dev-boot-$TARGET.config"
scripts/dev/gen-boot-config.sh "$BOOT_CONFIG" "$STORAGE_DIR"

if [ "$TARGET" = "server" ]; then
  BIN="dist/starbound_server"
else
  BIN="dist/starbound"
fi

if [ ! -x "$BIN" ]; then
  echo "error: $BIN not built yet - run scripts/dev/watch.sh (or cmake --build build/linux-dev) first" >&2
  exit 1
fi

echo "Running $BIN"
echo "  assets:  $HOME_DIR/assets, $HOME_DIR/mods"
echo "  storage: $STORAGE_DIR"
exec "$BIN" -bootconfig "$(pwd)/$BOOT_CONFIG" "$@"
