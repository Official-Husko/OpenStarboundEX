#!/bin/bash
# Builds the client/server/packer and repacks assets/opensb, in that order -
# the one thing scripts/dev/watch.sh (and the VS Code build task) actually
# need to run on every change, since either a C++ edit or an assets/opensb
# edit (a .patch, a shader, a .config) needs a slightly different follow-up
# step to actually reach a running dev build. See scripts/dev/pack-assets.sh
# for why the packing step exists at all.
#
# Usage: scripts/dev/build-and-pack.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

cmake --build build/linux-dev --target starbound starbound_server asset_packer -j"$(nproc)"
scripts/dev/pack-assets.sh
