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

echo "Watching source/ - Ctrl+C to stop. Edit a .cpp/.hpp and save to rebuild."
exec watchexec \
  --watch source \
  --exts cpp,hpp,h,cc \
  --debounce 300ms \
  -- cmake --build build/linux-dev --target starbound starbound_server -j"$(nproc)"
