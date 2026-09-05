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
- **Water wave/shine, seamless across the whole body.** Two earlier versions computed a fake
  ripple/glint procedurally from sine functions - both turned out to be invisible in-game (the
  amplitudes were tuned against a guessed texture scale, not the real one). Looking at the actual
  liquid textures (e.g. `/liquids/watertex.png`) explained why: they're soft repeating light/dark
  gradient bands, not detailed water photos, clearly meant to be animated by scrolling - which is
  exactly what `LiquidSettings::textureMovementFactor` was already sitting there for, unused,
  before this pass. Liquid tile quads now carry that per-liquid value (`RenderVertex::param2`, a
  new generic field defaulted to zero elsewhere) and the shader scrolls the texture by it, plus a
  small vertical wave on top. It's the *same* value for every tile of a given liquid (never
  anything computed per-tile), so every tile scrolls in lockstep with its neighbors - no seams,
  no patchwork. `source/rendering/StarTilePainter.cpp` (`produceLiquidPrimitives`),
  `assets/opensb/rendering/effects/world.{vert,frag,config}`,
  `source/application/StarRenderer_opengl.{hpp,cpp}` (packs the quantized value into
  previously-`unused` bits of the per-vertex integer attribute - no new vertex attributes, no new
  shader effect).
- **Wall foam, as particles.** A shader-tint version of this (blending liquid tiles towards white)
  looked bad - flat, tile-aligned, and it recolored the actual water. Replaced with real ambient
  particles: where a flowing surface tile's level gradient points straight into a solid wall,
  there's a chance each tick to spawn a particle drifting away from the wall. First attempt reused
  `/particles/splash/1.png`, which turned out to be a tiny star/spark icon meant for a raindrop's
  impact instant, not a lingering foam clump - read as "sparks shooting out" in-game. Switched to
  the gas-cloud puff animation (`/animations/gas/bluegas.animation`, a soft round blob that
  dissolves into wisps), tinted white. Purely cosmetic, client-side only, scanned each tick over
  the visible tile region (bounded, cheap - same cost class as weather's own particle spawning).
  `WorldClient::spawnLiquidFoamParticles` in `source/game/StarWorldClient.cpp`, tuned via
  `liquidFoamParticle`/`liquidFoamParticleVariance`/`liquidFoamChance` in
  `assets/opensb/client.config.patch`.

`assets/opensb/client.config.patch` also turned up a second, more general instance of an
engine-level JSON patch bug — see `BUGS.md` — worth reading before writing any more
`.config.patch` files, since it's not limited to `.weather` as first thought.

## Ideas for later

Water/liquid physics ideas now live in their own file, `IDEAS.md` - it grew large enough to want
more room than fits here. Weather ideas are on the `weather-expansion` branch's version of this
file, not this one.

### Water physics - further shimmer/foam tuning

- The scroll-speed-to-visible-motion conversion (the `0.15` multiplier in `world.frag`, i.e.
  "texture-repeats per second per unit of `textureMovementFactor`") is a first guess at what unit
  that field was originally meant to be in, since it was never actually consumed by any code
  before this pass - there's nothing to cross-check it against. Confirmed only that it produces
  *visible* motion now, not that the rate matches original intent.
- Foam currently only triggers on horizontal wall collisions; waterfalls hitting a floor
  (vertical collision) could get the same treatment.
- Foam particle timing (`timeToLive: 0.9`) doesn't necessarily match the gas animation's own
  natural cycle length - worth checking they end together rather than the particle cutting off
  mid-animation or lingering blank after it finishes.
- Two rendering bugs shipped and went unnoticed until actually seen in-game (the invisible
  sine-based ripple, the star-shaped "foam"). Both were caught by the user playing a real build,
  not by compiling cleanly or reasoning about the code - there's no way to render a frame from
  here, so treat anything visual in this file as unverified until someone's actually looked at it.
