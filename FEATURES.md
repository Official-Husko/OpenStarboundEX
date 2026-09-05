# Features

Running list of what's been added on top of stock OpenStarbound, and ideas for what could come
next.

## Shipped

### Water physics

- **Liquid currents.** Entities (players, NPCs, monsters, dropped items, projectiles, vehicles)
  now get pushed by the direction liquid is actually flowing rivers sweep dropped items
  downstream, waterfalls pull swimmers down, boats drift with the current. Derived from the
  liquid level gradient around the entity, so it works for every liquid type (water, lava,
  whatever a mod adds) with no per-liquid code. No network protocol changes.
  `source/game/StarMovementController.cpp` (`sampleLiquidFlowVelocity`), tuned via
  `MovementParameters::liquidFlowFactor` in `assets/opensb/default_movement.config.patch`.
- **Flow-direction shimmer.** Flowing liquid tiles visibly drift/wobble in their current's
  direction; still water is untouched. `source/rendering/StarTilePainter.cpp`,
  `assets/opensb/rendering/effects/world.{vert,frag,config}`.

### Weather

- **Gusting wind.** Wind eases towards a randomly re-rolled target every few seconds instead of
  being pinned at one fixed value for the whole weather event naturally drifts through calm,
  ramps into gusts, occasionally reverses direction. `source/game/StarWeather.cpp`
  (`ServerWeather::updateWind`).
- **Lightning + thunder.** Storms above a configured `lightningChance` flash the screen and
  (if a sound is configured) rumble a delayed thunderclap, distance-randomized so near strikes
  crack fast and loud while far ones rumble in late and quiet. Purely client-side/cosmetic, no
  server sync needed. `ClientWeather::updateLightning`, `WeatherType::lightningChance` /
  `thunderSounds`.
- **Fog and hail are live.** The base game ships complete `hailstones`/`fog`/`groundmist`
  weather types that were never wired into any biome's pool. Now added at low weights to
  garden/forest/ocean/jungle (`assets/opensb/weather.config.patch`), and "storm" (the existing
  heaviest rain tier) is now a real thunderstorm (`weather/rain/storm.weather.patch`).
  Flash-only for now for now because no thunder sound exists anywhere in the base assets to reuse. I am looking for a suitable thunder sound to add to the`thunderSounds` array to the storm patch.

## Ideas for later

### Weather new types worth authoring

None of these need new engine code beyond what's already shipped (particles + projectiles +
`actionOnReap` tricks + the lightning/flash system) unless noted.

- **Dry lightning / ion storm** lightning without any rain, for biomes where rain doesn't fit
  (volcanic, magma, space stations). Just a `.weather` file with `lightningChance` set and no
  rain particles the flash/thunder system already supports this standalone.
- **Toxic fog** the existing fog-primer trick, recolored green, paired with a damage-over-time
  status effect, so `toxic` gets its own atmospheric hazard distinct from acid rain.
- **Aurora** ambient colorful light-streak particles for arctic/tundra/space nights. Purely
  decorative, no projectiles/damage.
- **Falling leaves** gentle decorative-only weather for forest/garden, no threat, pure
  seasonal atmosphere.
- **Cosmetic meteor shower** a non-damaging shooting-star variant of the existing
  `meteorshower` for surface biomes at night, ambiance only.
- **Solar flare / radiation storm** reuses the lightning flash plumbing directly, paired with
  a radiation-flavored status effect, for space or very hot biomes.
- **Dust devils / whirlwinds** *(needs new engine code)* localized spinning debris. The
  existing `PhysicsForceRegion` system (already used for wind/explosions) could drive an actual
  rotational pull, which the current liquid-current-style approach can't do (it's a scalar
  gradient, not a true vector field with curl).

### Water/weather crossover

- **Storm-driven rough seas** temporarily strengthen liquid currents near open water while a
  storm's intensity is high, tying the new wind-gust system into the new liquid-current system
  for rogue waves / rough seas during weather events.
- **Whirlpools** same `PhysicsForceRegion` idea as dust devils, applied to open water; would
  give genuine rotational currents that the level-gradient approach fundamentally can't produce.

### Weather deeper mechanics

- **True intensity tiers.** Right now a storm is one fixed preset (rain OR storm OR hailstones)
  chosen once per event with only a warmup/cooldown fade. A real escalation model light rain
  building into a downpour building into a storm within a single event would need a new
  mechanic layered on top of `ServerWeather`, not just content.
- **Visibility-reducing fog.** The current fog is decorative ground-level cloud sprites. A true
  "can't see very far" screen fog would need a new post-process overlay (the engine already has
  a data-driven post-process shader pipeline this could hook into), separate from the existing
  fog weather content.
- **Heat shimmer / mirage.** Desert-only cosmetic distortion. Could reuse the same trick as the
  water flow shimmer (a per-tile/screen-space `time`-driven UV wobble) generalized into a
  standalone heat-haze effect.
