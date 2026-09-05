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
- **Water wave/shine, seamless across the whole body.** All liquid tiles get a small continuous
  ripple (a gentle sample-coordinate wobble) plus a drifting brightness glint, applied to every
  tile uniformly. Two earlier versions tied the effect to a per-tile flow value (direction/speed
  computed independently per tile, later restricted to just the surface row) - both looked like a
  patchwork of independently-animated tiles, because neighboring tiles' values didn't agree at
  their shared edge. The fix was to stop keying the effect off any per-tile value at all: it's now
  a pure function of continuous world position + time, so adjacent tiles always compute
  near-identical results right up to their boundary and the whole body reads as one surface.
  Liquid tile quads only carry a single boolean "is this liquid" flag (`RenderVertex::param2`, a
  new generic field defaulted to zero elsewhere) so the shader knows to apply the effect at all.
  `source/rendering/StarTilePainter.cpp` (`produceLiquidPrimitives`),
  `assets/opensb/rendering/effects/world.{vert,frag,config}`,
  `source/application/StarRenderer_opengl.{hpp,cpp}` (packs the flag into a previously-`unused`
  bit of the per-vertex integer attribute - no new vertex attributes, no new shader effect).
- **Wall foam, as particles.** A shader-tint version of this (blending liquid tiles towards white)
  looked bad - flat, tile-aligned, and it recolored the actual water. Replaced with real ambient
  particles: where a flowing surface tile's level gradient points straight into a solid wall,
  there's a chance each tick to spawn a small white particle drifting away from the wall,
  reusing the existing splash particle sprite. Purely cosmetic, client-side only, scanned each
  tick over the visible tile region (bounded, cheap - same cost class as weather's own particle
  spawning). `WorldClient::spawnLiquidFoamParticles` in `source/game/StarWorldClient.cpp`, tuned
  via `liquidFoamParticle`/`liquidFoamParticleVariance`/`liquidFoamChance` in
  `assets/opensb/client.config.patch`.

`assets/opensb/client.config.patch` also turned up a second, more general instance of an
engine-level JSON patch bug — see `BUGS.md` — worth reading before writing any more
`.config.patch` files, since it's not limited to `.weather` as first thought.

## Ideas for later

Water/liquid physics ideas now live in their own file, `IDEAS.md` - it grew large enough to want
more room than fits here. Weather ideas are on the `weather-expansion` branch's version of this
file, not this one.

### Water physics - further shimmer/foam tuning

- Wave/shine and foam-chance constants (the sine frequencies/amplitudes in `world.frag`, the
  `0.15f`/`0.95f` thresholds and `liquidFoamChance` in `client.config.patch`) are first-guess
  values, not tuned against an actual build/screenshot - worth revisiting once seen in-game.
- Foam currently only triggers on horizontal wall collisions; waterfalls hitting a floor
  (vertical collision) could get the same treatment.
- The wave/shine effect is now identical for every liquid type (water, lava, etc.) since it no
  longer reads any per-liquid data at all - could reintroduce per-liquid variation (e.g. lava
  glows/bubbles instead of rippling) later without reintroducing the old per-tile-seam problem,
  as long as whatever drives it stays a continuous function of position/time rather than a
  per-tile value.
