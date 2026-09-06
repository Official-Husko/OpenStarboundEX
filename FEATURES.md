# Features

Running list of what's been added on top of stock OpenStarbound on this branch, and ideas for
what could come next. See `CLAUDE.md` for the technical orientation.

> **Branch note:** this is `main`. A separate `weather-expansion` branch has additional
> gusting-wind/lightning/fog-and-hail weather work (and its own, longer version of this file)
> that hasn't been merged here yet - check there before assuming weather is untouched.

## Shipped

### Water physics

- **Liquid currents.** Entities (players, NPCs, monsters, dropped items, projectiles, vehicles)
  get pushed by the direction liquid is actually flowing - rivers sweep dropped items
  downstream, waterfalls pull swimmers down, boats drift with the current. Derived from the
  liquid level gradient around the entity, so it works for every liquid type (water, lava,
  whatever a mod adds) with no per-liquid code. No network protocol changes.
  `source/game/StarMovementController.cpp` (`sampleLiquidFlowVelocity`), tuned via
  `MovementParameters::liquidFlowFactor` in `assets/opensb/default_movement.config.patch`.
- **Water wave/shine, seamless across the whole body.** Went through three iterations. v1/v2
  computed a fake ripple/glint procedurally from sine functions at a guessed scale and were
  invisible in-game. Looking at the actual liquid textures (e.g. `/liquids/watertex.png`)
  explained why: they're soft repeating light/dark gradient bands, not detailed water photos,
  clearly meant to be animated by scrolling - which is exactly what
  `LiquidSettings::textureMovementFactor` was already sitting there for, unused, before this pass.
  v3 used that field but as a flat linear scroll, which looked mechanical - "a conveyor belt" -
  and too fast. Current version: real 2D displacement built from several sine terms at
  deliberately non-matching frequencies/speeds in both axes (so no two points move identically at
  once), slowed down substantially, still driven only by `textureMovementFactor`/time - the same
  value for every tile of a given liquid, never anything computed per-tile, so every tile stays in
  lockstep with its neighbors with no seams. Liquid tile quads carry that per-liquid value via
  `RenderVertex::param2` (a new generic field defaulted to zero elsewhere).
  `source/rendering/StarTilePainter.cpp` (`produceLiquidPrimitives`),
  `assets/opensb/rendering/effects/world.{vert,frag,config}`,
  `source/application/StarRenderer_opengl.{hpp,cpp}` (packs the quantized value into
  previously-`unused` bits of the per-vertex integer attribute - no new vertex attributes, no new
  shader effect).
- **Shoreline foam - removed.** Went through several iterations (flat tile tint, particles, a
  shader noise layer with progressively fixed seam/height bugs) but still didn't look right after
  repeated rounds of fixes, so it was fully reverted rather than left in a half-working state - no
  foam-related code remains in `RenderVertex`, the GL vertex packing, `world.{vert,frag}`, or
  `TilePainter::produceLiquidPrimitives`. Full history, what was learned, and ideas for a
  different approach next time are in `IDEAS.md`'s "Shoreline foam - removed, revisit later"
  entry - read that before attempting foam again.

`assets/opensb/client.config.patch` also turned up a second, more general instance of an
engine-level JSON patch bug — see `BUGS.md` — worth reading before writing any more
`.config.patch` files, since it's not limited to `.weather` as first thought.

### Local dev-loop tooling

Building and running this fork locally (instead of waiting on a multi-minute GitHub Actions CI
build for every change) is now real - see `DEV_LOOP.md` for the full writeup. Highlights:

- A `linux-dev` CMake preset (Debug, tests/Steam/Discord off, own `build/linux-dev` directory) plus
  `scripts/dev/watch.sh` (incremental rebuild on save via `watchexec`+`ninja`+`sccache`) and
  `scripts/dev/run-dev.sh` (runs the built binary against a real OpenStarboundEX install's assets,
  since this repo ships none of its own).
- `scripts/dev/run-dev-multiplayer.sh` runs a dedicated server and a client together, each on
  scratch storage, for testing networked behavior locally.
- `.vscode/launch.json`/`tasks.json` (gitignored, local-machine-only) wire up `cppdbg`/gdb debug
  configs for the client, the server, and both together as a compound.
- Two real vcpkg build-environment issues hit and fixed along the way (an `overlay-ports/jemalloc`
  patch for a libstdc++-internal symbol vcpkg's jemalloc port assumed still exists; a false-alarm
  `autoconf-archive`-missing error that was actually just an install-timing race) - see
  `DEV_LOOP.md`'s "vcpkg build quirks" section.
- **On-screen build identification**, since getting a local dev build actually running exposed a
  real gap: the git commit (`StarSourceIdentifierString`) doesn't change between uncommitted
  edits, so it can't answer "did my last change actually get rebuilt?" during iterative local
  testing. Fixed with a build stamp that's regenerated at *every* build invocation (not just every
  CMake reconfigure, unlike the existing git-derived version string) -
  `source/core/GenerateBuildStamp.cmake`, wired into `star_core` via a custom target with no
  declared inputs so it always reruns. Shown two ways: an always-visible bottom-right corner label
  in-game (`MainInterface::renderBuildInfo`, `source/frontend/StarMainInterface.cpp`) reading
  `OSB v0.1.15 - SB v1.4.4` / `hash (xxxxxxxxxxxx)`, and appended to the existing startup log line
  (`Compiled with Clang <version> at <build date>`, `source/client/StarClientApplication.cpp`).

Two real engine bugs (not content bugs) turned up once a local build made it possible to actually
try a real local join for the first time - both are now fixed, full writeups in `BUGS.md`:

- **Local-connection packet round-trip silently dropped fields in Debug builds.** A `#ifdef
  STAR_DEBUG`-only self-test in `LocalPacketSocket::sendPackets` called the wrong (no-`
  NetCompatibilityRules`) overload of `read`/`write` for several packet types, which for those
  types is a silent no-op rather than a compile error - manifested as an immediate `EofException`
  on join (nothing written, so the read-back hit EOF on the first field) and, once that was fixed,
  an empty player name silently reaching the server (nothing read back, so the reconstructed packet
  kept its default-constructed fields) and a downstream `MapException`.
- **A client that simply failed to connect could crash the whole server.** An accept thread's
  stored exception (from the bug above, or any other ordinary failed/timed-out connection) got
  safely caught and logged on a normal server tick, but rethrown uncaught if the server stopped
  before that tick ran - e.g. right after a failed join, which is exactly when it's likely to
  matter. `UniverseServer`'s destructor now drains pending accept threads with the same catch its
  own `reapConnections()` already used, before relying on implicit member destruction.

## Ideas for later

Water/liquid physics ideas now live in their own file, `IDEAS.md` - it grew large enough to want
more room than fits here. Weather ideas are on the `weather-expansion` branch's version of this
file, not this one.

### Water physics - further shimmer tuning

- The displacement amplitudes/frequencies and the `0.045` speed multiplier in `world.frag` are a
  second-pass guess, not tuned against an actual screenshot. `textureMovementFactor`'s original
  intended unit is still unknown (never consumed by any code before this pass, so there's nothing
  to cross-check against) - "produces visible, non-mechanical-looking motion at a reasonable
  speed" is the current bar, not "matches original intent."
- Several rendering bugs have shipped and gone unnoticed until actually seen in-game (invisible
  ripple, star-shaped "foam", blue "white" foam, a too-fast/too-linear wave, particles reading as
  "blowing into the air") - and shoreline foam specifically never got past this stage at all
  despite several rounds of fixes, and was removed rather than left half-working (see `IDEAS.md`).
  All of this was caught (or, in foam's case, never fully resolved) by the user playing a real
  build, not by compiling cleanly or reasoning about the code - there's no way to render a frame or
  view a running client from here (screenshot capture of a live process is blocked in this
  sandbox), so treat anything visual in this file as unverified until someone's actually looked at
  it. Static inspection (unpacking and viewing the actual sprite/texture pixels, as opposed to
  assuming from a filename) has caught real bugs before they even reached the user, though - worth
  doing by default for anything visual, not just after a report.
