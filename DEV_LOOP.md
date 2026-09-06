# Local dev loop

**The point of this:** waiting on a GitHub Actions CI build (minutes to build, more to download
the artifact) for every change is too slow to iterate on. This gets a local edit → compile →
relink loop down to seconds for most changes, and a way to actually run the result against a real
game install instead of an empty `dist/`.

## One-time setup

```sh
sudo pacman -S cmake ninja clang sccache watchexec git
git clone https://github.com/microsoft/vcpkg.git ~/.local/share/vcpkg
~/.local/share/vcpkg/bootstrap-vcpkg.sh -disableMetrics
export VCPKG_ROOT=~/.local/share/vcpkg   # put this in your shell rc
```

## The build itself

A new CMake preset, `linux-dev`, was added to `source/CMakePresets.json` alongside the existing
`linux-release`/`linux-release-clang`/etc: same compiler/triplet as `linux-release-clang`
(Clang + `x64-linux-mixed-clang`), but:

- `CMAKE_BUILD_TYPE=Debug` instead of `RelWithDebInfo` - the release presets build with
  `-O3 -ffast-math`, which makes every incremental compile much slower than it needs to be during
  development.
- `BUILD_TESTING=OFF`, `STAR_ENABLE_STEAM_INTEGRATION=OFF`, `STAR_ENABLE_DISCORD_INTEGRATION=OFF` -
  skips building the test suite and the two SDK integrations, which nothing here needs day to day.
- `VCPKG_OVERLAY_PORTS=../overlay-ports` - see "vcpkg build quirks" below.

## vcpkg build quirks hit on this machine

- **jemalloc fails to compile on a new-enough libstdc++**: vcpkg's jemalloc port (5.3.1)
  calls the libstdc++-internal `std::__throw_bad_alloc()` from `jemalloc_cpp.cpp`; newer
  libstdc++ versions (seen here: GCC 16's) have dropped that internal symbol, so the build
  fails with `no member named '__throw_bad_alloc' in namespace 'std'`. `overlay-ports/jemalloc/`
  is a copy of vcpkg's own jemalloc port with one extra patch
  (`fix-libstdcxx-internal-throw.patch`) swapping that call for plain `throw std::bad_alloc();`
  (equivalent behavior, no libstdc++-internal API). Only wired into `VCPKG_OVERLAY_PORTS` on the
  `linux-dev` preset, not the CI/release presets - CI builds on `ubuntu-22.04`, whose older
  libstdc++ never hits this, so there's no reason to touch the shared config for it.
- **`libxcrypt` build fails claiming `autoconf-archive` is missing even when it's installed**:
  this is vcpkg's port check being accurate, not buggy - it actually tries `aclocal --dry-run`
  against a probe file and greps for a real failure. If you hit this right after installing the
  package, it's very likely a stale timing issue (the package finished installing after this
  vcpkg run already probed for it) - just re-run `cmake --preset linux-dev -S source`.
- Own build directory, `build/linux-dev`, so it never fights with `build/linux-release-clang` or
  a CI build's cache.

`sccache` was already installed, which matters here: `source/CMakeLists.txt` auto-detects it
(`find_program(SCCACHE_PATH sccache)`) and, when found, disables precompiled headers in favor of
compiler caching (`STAR_PRECOMPILED_HEADERS` in `core/CMakeLists.txt` / `game/CMakeLists.txt`).
That's an intentional tradeoff already built into this project, not something this setup changes -
just worth knowing it's active. Check it's actually caching with `sccache --show-stats`.

First configure (also done automatically by `scripts/dev/watch.sh` if `build/linux-dev` doesn't
exist yet):

```sh
cmake --preset linux-dev -S source
```

This is the slow part and there's no way around it here: vcpkg has to build every dependency
(~40 packages, most twice - dbg and rel variants) from source, since this triplet isn't on a
public binary cache. Only needs doing once.

## Day to day

Scripts under `scripts/dev/`:

- **`scripts/dev/watch.sh`** - runs `watchexec` over both `source/` and `assets/opensb/`, running
  `scripts/dev/build-and-pack.sh` on every save (see below for what that does). Leave this running
  in a terminal while editing.
- **`scripts/dev/build-and-pack.sh`** - builds `starbound`/`starbound_server`/`asset_packer`, then
  repacks `assets/opensb/` into the real install's `opensb.pak` (see `pack-assets.sh` below). This
  is the one thing that actually needs to run on every change, since either a C++ edit or an
  `assets/opensb` edit needs it. Also what the `.vscode` "Build (linux-dev)" task runs, so F5 gets
  this too, not just `watch.sh`.
- **`scripts/dev/pack-assets.sh`** - packs `assets/opensb/` with the freshly-built `asset_packer`
  into `$OPENSTARBOUND_HOME/assets/opensb.pak` (~0.3-0.6s). **Without this, editing anything under
  `assets/opensb/` - a `.patch` file, a shader, a `.config` - has zero effect on a running dev
  build**: `run-dev.sh` points `assetDirectories` at a real install, and that install's
  `opensb.pak` is just a plain file sitting there from whenever it was last packed (e.g. an old CI
  build) - nothing automatically regenerates it from this repo's live `assets/opensb/` source.
  This was a real gap for a while: every shader/asset change made during dev-loop testing was
  silently untested, since only the C++ binaries were ever being rebuilt and rerun.
- **`scripts/dev/run-dev.sh [client|server]`** - runs the freshly-built `dist/starbound(_server)`
  against a *real* OpenStarboundEX install's assets, since this repo ships no base game assets of
  its own (see `CLAUDE.md`) and a Debug build's `dist/` has nothing to load on its own. Also calls
  `pack-assets.sh` itself first (redundant, and harmless, if `watch.sh` already did it - but
  matters if you build manually without `watch.sh` running). Defaults to `~/Games/OpenStarboundEX`
  (override with `OPENSTARBOUND_HOME`), and **shares that install's `storage/` by default - it
  runs against your real savegames**, not a throwaway world. Set `OPENSTARBOUND_DEV_STORAGE` to a
  scratch directory instead if you'd rather a Debug build not touch real saves while iterating.

So in practice: `scripts/dev/watch.sh` in one terminal, edit code *or* assets, save, wait for it to
report the build finished, then `scripts/dev/run-dev.sh` in another terminal whenever you want to
actually look at the result.

## Running client + server together (local multiplayer testing)

- **`scripts/dev/run-dev-multiplayer.sh`** - starts a dedicated server (scratch storage at
  `build/linux-dev/mp-server-storage`) in the background, waits for its log to report it's
  listening, then runs a client (scratch storage at `build/linux-dev/mp-client-storage`) in the
  foreground. Neither touches your real save. Once the client's loaded, there's no CLI flag to
  auto-join - use its in-game "Join Game" menu and connect to `127.0.0.1` (default port 21025).
  Killing the client (or Ctrl+C) also stops the server. Override
  `OPENSTARBOUND_MP_SERVER_STORAGE`/`OPENSTARBOUND_MP_CLIENT_STORAGE` to reuse a specific
  scratch world/character across runs.

## VS Code debugging (client, server, or both)

`.vscode/launch.json` and `.vscode/tasks.json` (gitignored - local to this machine, matching this
repo's existing `.vscode/` ignore rule) wire up `cppdbg`/gdb debug configs for both binaries,
using `ms-vscode.cpptools` (already installed) and system `gdb`:

- **"Debug Client (starbound)"** / **"Debug Server (starbound_server)"** - each has a
  `preLaunchTask` that builds `build/linux-dev` and (re)generates its own boot config
  (`scripts/dev/gen-boot-config.sh`, the same generator `run-dev.sh` uses) pointing at real
  assets but **scratch storage** (`build/linux-dev/vscode-{client,server}-storage` - not your
  real save, since a debugging session is more likely to crash or leave odd state). Set
  `OPENSTARBOUND_HOME` before launching VS Code if your install isn't at
  `~/Games/OpenStarboundEX`.
- **"Debug Client + Server (multiplayer)"** compound - launches both under the debugger at once
  (each still against its own scratch storage), for stepping through networked code on either
  side. Same manual "Join Game -> 127.0.0.1" step as above; nothing auto-connects.

Both configs default to scratch storage on purpose. To debug against your real save instead, edit
`.vscode/tasks.json`'s "Gen dev boot config" task(s) to point `gen-boot-config.sh`'s second
argument at your real storage directory.

**Gotcha already fixed, but worth knowing about**: `StarMainApplication_sdl.cpp` calls
`File::changeDirectory(SDL_GetBasePath())` very early in startup - the process always chdirs to
its own executable's directory (`dist/`), no matter what cwd it was launched from. A relative
`storageDirectory` in a boot config therefore silently resolves against `dist/`, not wherever you
generated the config from - if that path doesn't exist there, `Root`'s storage setup throws, gets
wrapped as `Star::ApplicationException`, and the app aborts almost immediately (a `Fatal Exception
caught` line in the log, or - if it crashes early enough that Logger hasn't opened the log file
yet - only visible via a core dump). `gen-boot-config.sh` now always resolves `storageDirectory`
to an absolute path (`cd "$STORAGE_DIR" && pwd`) before writing it out, specifically because the
VS Code tasks pass it a relative scratch path; `run-dev.sh` never hit this since its own default
storage path was already absolute. If you ever see this exception, check for a relative path
sneaking into a boot config before anything else.

## What's still slow, and why

- Changing a widely-`#include`d `.hpp` still triggers a large rebuild (every `.cpp` that
  transitively includes it goes dirty). That's inherent to how this codebase is structured
  (`core`/`base`/`game`/etc. as separate CMake object libraries, not independently reloadable
  modules) - no realistic way around it without bigger architectural changes. True in-process hot
  reload isn't available here for the same reason: `starbound`/`starbound_server` are single
  executables assembled from static object libraries, not a host loading swappable `.so` gameplay
  modules.
- The very first build (and the vcpkg dependency build before it) is still going to be slow
  regardless of any of this. The payoff is every build after that.
- For reference, the object library target a change lands in: `source/core` → `star_core`,
  `source/base` → `star_base`, `source/game` → `star_game`, `source/application` →
  `star_application`, `source/rendering` → `star_rendering`, `source/windowing` →
  `star_windowing`, `source/frontend` → `star_frontend`; `client`/`server` are the two executables
  (`starbound`/`starbound_server`) that link all of the above together. Touching something in
  `game` still requires relinking both executables, but not recompiling anything outside `game`
  and whatever few files directly include the changed header.
