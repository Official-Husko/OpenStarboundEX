# Changes

Technical changelog for this fork, maintained on every change - each entry tagged `Add:`, `Fix:`,
`Change:`, or `Remove:`. Newest first. See `CHANGELOG.md` for the plain-language, player-facing
version of this (not every entry here has one - only things a player would actually notice), and
`CLAUDE.md` for technical orientation, `IDEAS.md` for not-yet-built ideas, `BUGS.md` for
engine-level bugs with full reproduction detail, and `DEV_LOOP.md` for the local build loop.

> **Branch note:** this is `main`. A separate `weather-expansion` branch has additional
> gusting-wind/lightning/fog-and-hail weather work (and its own changelog) that hasn't been
> merged here yet - check there before assuming weather is untouched.

## main branch

- **Fix**: local dev-loop builds silently ignored every `assets/opensb/` edit. `run-dev.sh` points
  a real OpenStarboundEX install's `assetDirectories` at itself, and that install's `opensb.pak`
  is just a plain file sitting there from whenever it was last packed (e.g. an old CI build) -
  nothing regenerated it from this repo's live `assets/opensb/` source, so editing a `.patch`
  file, a shader, or a `.config` had *zero* effect on a running dev build no matter how many times
  the binaries were rebuilt and rerun. New `scripts/dev/pack-assets.sh` repacks `assets/opensb/`
  (via a freshly-built `asset_packer`, ~0.3-0.6s) into the real install's `opensb.pak`; new
  `scripts/dev/build-and-pack.sh` builds the client/server/packer and then calls it, and is now
  what `scripts/dev/watch.sh` (which now also watches `assets/opensb/`, not just `source/`), the
  `.vscode` "Build (linux-dev)" task (so F5 gets it too), and `run-dev.sh` itself (as a standalone
  safety net) all actually run. See `DEV_LOOP.md`.
- **Add**: native fatal-error dialog on Linux/macOS. Windows already showed a `MessageBox` from
  `fatalException`/`fatalError` (`StarException_windows.cpp`) before aborting; Linux/macOS just
  logged and called `abort()` with nothing visible to the user at all. Added an
  `SDL_ShowSimpleMessageBox` call at the actual catch sites in
  `source/application/StarMainApplication_sdl.cpp`. The main one is inside `SdlPlatform::run()`'s
  own catch block (covers `applicationInit`/`renderInit`/the whole main loop - i.e. almost every
  real crash), using `m_sdlWindow` as the dialog's parent, which matters on Wayland specifically:
  SDL's Wayland backend needs a parent surface to show anything at all and silently does nothing
  without one (unlike X11, where an unparented dialog still works). A first attempt put this in
  `runMainApplication`'s outer catch with a `nullptr` parent - never actually reached for
  in-process exceptions (that inner catch already calls `fatalException`, which aborts before
  unwinding further) and wouldn't have shown anything on Wayland anyway; kept as a best-effort
  fallback for exceptions thrown before any window exists (e.g. during `SdlPlatform`'s own
  constructor), where no parent window is available regardless.
- **Add**: on-screen build-info watermark, always visible on every screen (title, menus, in-game).
  Muted gray text, no background panel, bottom-right corner:
  `OSB v0.1.15 - SB v1.4.4` / `hash (xxxxxxxxxxxx)`. Lives in `ClientApplication::renderBuildInfo`
  (`source/client/StarClientApplication.cpp`), called unconditionally at the end of
  `ClientApplication::render()` so it covers every app state, not just in-game (an earlier version
  lived in `MainInterface`, which only exists once a session starts - moved once "visible
  everywhere" became the actual requirement). The hash is `StarBuildStampString`
  (`source/core/GenerateBuildStamp.cmake`, wired into `star_core` via a custom target with no
  declared inputs so it reruns on *every* build invocation, not just every CMake reconfigure),
  deliberately not the git commit (`StarSourceIdentifierString`) - that only changes on an actual
  commit, so it stays identical across every uncommitted dev-loop edit and can't answer "did my
  last change actually get rebuilt?". Also appended to the existing `Compiled with Clang <version>`
  startup log line as `at <build date>`. One real gotcha hit building this: a `const` global at
  namespace scope gets *internal* linkage in C++ unless a prior `extern` declaration is visible
  before its definition - the generated `StarBuildStamp.cpp` initially didn't include
  `StarVersion.hpp` first, so it compiled fine but the symbols were invisible to every other
  translation unit (undefined reference at link time, not a compile error).
- **Add**: local dev-loop tooling, so testing changes doesn't mean waiting on a multi-minute
  GitHub Actions CI build every time. Full writeup in `DEV_LOOP.md`. Highlights: a `linux-dev`
  CMake preset (Debug, tests/Steam/Discord off, own `build/linux-dev` directory);
  `scripts/dev/watch.sh` (incremental rebuild on save via `watchexec`+`ninja`+`sccache`) and
  `scripts/dev/run-dev.sh` (runs the built binary against a real OpenStarboundEX install's assets,
  since this repo ships none of its own); `scripts/dev/run-dev-multiplayer.sh` (a dedicated server
  and a client together, each on scratch storage, for testing networked behavior locally);
  `.vscode/launch.json`/`tasks.json` (gitignored, local-machine-only) with `cppdbg`/gdb debug
  configs for the client, the server, and both together as a compound.
- **Fix**: two vcpkg build-environment issues hit setting up the dev-loop preset above - an
  `overlay-ports/jemalloc` patch for a libstdc++-internal symbol vcpkg's jemalloc port assumed
  still exists on newer toolchains; a false-alarm `autoconf-archive`-missing error that was
  actually just an install-timing race, not a real missing dependency. See `DEV_LOOP.md`'s "vcpkg
  build quirks" section.
- **Fix**: a client that simply failed to connect could crash the whole server. An accept
  thread's stored exception (from the bug below, or any other ordinary failed/timed-out
  connection) got safely caught and logged on a normal server tick, but rethrown *uncaught* if the
  server stopped before that tick ran - e.g. right after a failed join, exactly when it's likely
  to matter. `UniverseServer`'s destructor now drains pending accept threads with the same catch
  its own `reapConnections()` already used, before relying on implicit member destruction. Full
  writeup in `BUGS.md`.
- **Fix**: local-connection packet round-trip silently dropped fields in Debug builds. A `#ifdef
  STAR_DEBUG`-only self-test in `LocalPacketSocket::sendPackets` called the wrong (no-
  `NetCompatibilityRules`) overload of `read`/`write` for several packet types, which for those
  types is a silent no-op rather than a compile error - manifested as an immediate `EofException`
  on join (nothing written, so the read-back hit EOF on the first field) and, once that was fixed,
  an empty player name silently reaching the server (nothing read back, so the reconstructed
  packet kept its default-constructed fields) and a downstream `MapException`. Only reachable via
  Debug build + local/singleplayer connection, which is exactly what the dev-loop work above made
  possible to test for the first time. Full writeup in `BUGS.md`.
- **Add**, then **Remove**: shoreline foam. Shipped as a shader noise layer, iterated on
  repeatedly (fixing a tile-boundary seam, then a "covers the whole tile height instead of a thin
  surface skin" bug, then a suspected multi-row `isSurface` triggering bug near vertical objects),
  but still didn't look right after all of that, so it was fully reverted rather than left
  half-working - no foam-related code remains in `RenderVertex`, the GL vertex packing,
  `world.{vert,frag}`, or `TilePainter::produceLiquidPrimitives`. Full history, what was learned,
  and ideas for a different approach next time are in `IDEAS.md`'s "Shoreline foam - removed,
  revisit later" entry - read that before attempting foam again.
- **Fix**: a second, more general instance of the JSON-patch engine bug turned up in
  `assets/opensb/client.config.patch` - see `BUGS.md`, worth reading before writing any more
  `.config.patch` files, since it's not limited to `.weather` as first thought.
- **Add**: water wave/shine, seamless across the whole body. Went through three iterations - v1/v2
  computed a fake ripple/glint procedurally from sine functions at a guessed scale and were
  invisible in-game; looking at the actual liquid textures (e.g. `/liquids/watertex.png`)
  explained why (soft repeating light/dark gradient bands, not detailed water photos, clearly
  meant to be animated by scrolling - exactly what `LiquidSettings::textureMovementFactor` was
  already sitting there for, unused). v3 used that field but as a flat linear scroll, which looked
  mechanical ("a conveyor belt") and too fast. Current version: real 2D displacement built from
  several sine terms at deliberately non-matching frequencies/speeds in both axes, slowed down
  substantially, still driven only by `textureMovementFactor`/time - the same value for every tile
  of a given liquid, never anything computed per-tile, so every tile stays in lockstep with its
  neighbors with no seams. `source/rendering/StarTilePainter.cpp` (`produceLiquidPrimitives`),
  `assets/opensb/rendering/effects/world.{vert,frag,config}`,
  `source/application/StarRenderer_opengl.{hpp,cpp}` (packs the quantized value into
  previously-`unused` bits of the per-vertex integer attribute - no new vertex attributes, no new
  shader effect).
- **Add**: liquid currents. Entities (players, NPCs, monsters, dropped items, projectiles,
  vehicles) get pushed by the direction liquid is actually flowing - rivers sweep dropped items
  downstream, waterfalls pull swimmers down, boats drift with the current. Derived from the liquid
  level gradient around the entity, so it works for every liquid type (water, lava, whatever a mod
  adds) with no per-liquid code. No network protocol changes.
  `source/game/StarMovementController.cpp` (`sampleLiquidFlowVelocity`), tuned via
  `MovementParameters::liquidFlowFactor` in `assets/opensb/default_movement.config.patch`.

## Process notes

- Several rendering bugs have shipped and gone unnoticed until actually seen in-game (invisible
  ripple, star-shaped "foam", blue "white" foam, a too-fast/too-linear wave, particles reading as
  "blowing into the air") - and shoreline foam specifically never got past this stage at all
  despite several rounds of fixes. All of this was caught (or, in foam's case, never fully
  resolved) by the user playing a real build, not by compiling cleanly or reasoning about the
  code - there's no way to render a frame or view a running client from here (screenshot capture
  of a live process is blocked in this sandbox), so treat anything visual as unverified until
  someone's actually looked at it. Static inspection (unpacking and viewing the actual
  sprite/texture pixels, as opposed to assuming from a filename) has caught real bugs before they
  even reached the user, though - worth doing by default for anything visual, not just after a
  report.
- `textureMovementFactor`'s displacement amplitudes/frequencies and the `0.045` speed multiplier
  in `world.frag` are a second-pass guess, not tuned against an actual screenshot - its original
  intended unit is still unknown (never consumed by any code before this pass, so there's nothing
  to cross-check against). "Produces visible, non-mechanical-looking motion at a reasonable speed"
  is the current bar, not "matches original intent."
