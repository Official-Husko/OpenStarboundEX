#!/bin/bash
# Packs assets/opensb into the real OpenStarboundEX install's opensb.pak, so
# local .patch/shader/config edits under assets/opensb/ actually reach a
# running dev build. Without this, run-dev.sh's dist/starbound would keep
# silently loading whatever opensb.pak the install already had (e.g. a
# stale CI-built one) - nothing under assets/opensb/ would ever actually be
# tested, no matter how many times the binary was rebuilt and rerun.
#
# Usage: scripts/dev/pack-assets.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

HOME_DIR="${OPENSTARBOUND_HOME:-$HOME/Games/OpenStarboundEX}"
PACKER="dist/asset_packer"

if [ ! -x "$PACKER" ]; then
  echo "error: $PACKER not built yet - run 'cmake --build build/linux-dev --target asset_packer' first" >&2
  exit 1
fi

if [ ! -d "$HOME_DIR/assets" ]; then
  echo "error: $HOME_DIR/assets not found - set OPENSTARBOUND_HOME to a real OpenStarboundEX install" >&2
  exit 1
fi

echo "Packing assets/opensb -> $HOME_DIR/assets/opensb.pak"
"$PACKER" -c scripts/packing.config assets/opensb "$HOME_DIR/assets/opensb.pak"
