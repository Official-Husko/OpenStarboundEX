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
- **Shoreline foam, as a shader noise layer.** Went through two wrong approaches before this one.
  v1 blended whole liquid tiles towards white - flat, tile-aligned, recolored the actual water.
  v2 was an ambient particle system spawning sprites that drifted off the water with real
  velocity - read as "stuff shooting/blowing into the air" regardless of which sprite was tried
  (a star/spark icon, then a gas-cloud puff that turned out to be un-tintable since it's colored
  blue in its own pixels, not white). Current version is neither: a per-vertex "how close is this
  tile to a wall" intensity (`RenderVertex::param3`, fading smoothly over ~3 tiles, computed in
  `TilePainter::produceLiquidPrimitives`) gates a procedural noise pattern computed entirely in
  `world.frag` from world position + time - thresholded into bubble-like clusters rather than a
  smooth gradient, slowly drifting so it doesn't look like a static decal. Nothing is spawned,
  nothing has velocity, nothing leaves the water's surface - it's a layer on the water, not an
  object in the world. `source/rendering/StarTilePainter.cpp`,
  `assets/opensb/rendering/effects/world.{vert,frag}`, `source/application/StarRenderer_opengl.{hpp,cpp}`
  (packs the quantized intensity into more of the same previously-`unused` bits the wave/shine
  value uses).

`assets/opensb/client.config.patch` also turned up a second, more general instance of an
engine-level JSON patch bug — see `BUGS.md` — worth reading before writing any more
`.config.patch` files, since it's not limited to `.weather` as first thought.

## Ideas for later

Water/liquid physics ideas now live in their own file, `IDEAS.md` - it grew large enough to want
more room than fits here. Weather ideas are on the `weather-expansion` branch's version of this
file, not this one.

### Water physics - further shimmer/foam tuning

- The displacement amplitudes/frequencies and the `0.045` speed multiplier in `world.frag` are a
  second-pass guess, not tuned against an actual screenshot. `textureMovementFactor`'s original
  intended unit is still unknown (never consumed by any code before this pass, so there's nothing
  to cross-check against) - "produces visible, non-mechanical-looking motion at a reasonable
  speed" is the current bar, not "matches original intent."
- Foam currently only appears near *any* wall a surface tile is adjacent to (shoreline-style), not
  specifically where a current is flowing into one - simpler and matches "foam along a pond's
  edge" better, but means it no longer conveys current strength/direction the way the old
  particle version's spawn rate did. Could reintroduce that as a secondary intensity factor later.
- The noise scale (`* 4.0`), threshold (`smoothstep(0.48, 0.7, ...)`), drift speed, and opacity
  (`* 0.85`) in `world.frag` are first-guess values for "looks like clusters of foam" - not tuned
  against an actual screenshot.
- Foam only fades in near horizontal walls; waterfalls hitting a floor (vertical collision) don't
  currently get any.
- Several rendering bugs have shipped and gone unnoticed until actually seen in-game (invisible
  ripple, star-shaped "foam", blue "white" foam, a too-fast/too-linear wave, particles reading as
  "blowing into the air"). All were caught by the user playing a real build, not by compiling
  cleanly or reasoning about the code - there's no way to render a frame or view a running client
  from here, so treat anything visual in this file as unverified until someone's actually looked
  at it. Static inspection (unpacking and viewing the actual sprite/texture pixels, as opposed to
  assuming from a filename) has caught real bugs before they even reached the user, though - worth
  doing by default for anything visual, not just after a report.
