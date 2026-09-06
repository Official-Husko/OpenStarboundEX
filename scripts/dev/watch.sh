#!/bin/bash
# Fast local incremental-build loop, in place of waiting minutes on a GitHub
# Actions CI build for every change. See DEV_LOOP.md at the repo root.
#
# First run configures build/linux-dev (a Debug, tests-off, Steam/Discord-off
# build - see the "linux-dev" CMake preset) if it doesn't exist yet, which
# will be slow (vcpkg has to build every dependency from source). After that,
# saving a changed .cpp/.hpp only recompiles what actually depends on it and
# relinks - normally a few seconds, not minutes.
#
# Usage: scripts/dev/watch.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

export VCPKG_ROOT="${VCPKG_ROOT:-$HOME/.local/share/vcpkg}"

if [ ! -d build/linux-dev ]; then
  echo "No build/linux-dev yet - configuring it now (first run only, this part is not fast)..."
  cmake --preset linux-dev -S source
fi

echo "Watching source/ and assets/opensb/ - Ctrl+C to stop. Edit a .cpp/.hpp or any"
echo "assets/opensb file (.patch, .vert/.frag, .config, ...) and save to rebuild."
# No --exts filter: assets/opensb has dozens of extensions (.patch, .vert,
# .frag, .config, .lua, .png, ...) and a hardcoded list would inevitably miss
# some - both cmake (nothing to do if no .cpp/.hpp changed) and asset_packer
# (~0.6s for the whole assets/opensb tree) are cheap enough that watching
# everything under both directories costs nothing extra in practice.
exec watchexec \
  --watch source \
  --watch assets/opensb \
  --debounce 300ms \
  -- scripts/dev/build-and-pack.sh
