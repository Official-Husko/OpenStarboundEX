# Water & Liquid Physics Ideas

A dedicated brainstorm for where the water/liquid work could go next, beyond what's already in
`FEATURES.md`. Nothing here is committed to — it's a menu, not a roadmap. Each idea notes roughly
how it'd be built, grounded in mechanisms this engine already has (so "needs new engine code"
means genuinely new, not just "nobody's built it yet").

## Currents & flow

- **Whirlpools / vortices.** The current system (`MovementController::sampleLiquidFlowVelocity`)
  is a scalar gradient - it can push things downhill but can't curl. A real vortex needs a true
  vector field. The engine already has `PhysicsForceRegion` (used for wind/explosions) - a
  scripted object could drop a rotational force region at a whirlpool's center, layered on top of
  the existing gradient-based current for the "water genuinely spins here" feel.
- **Undertow / drag zones.** A variant of the current idea that pulls entities toward a point (or
  straight down) instead of pushing them along a direction - same `PhysicsForceRegion` hook,
  different shape. Good for "this specific pool is dangerous" set-pieces without touching the
  general liquid simulation.
- **Current-riding transportation.** Rivers/flumes as an intentional traversal mechanic in
  dungeons - the current already exists and already moves rafts/dropped items; this is mostly a
  content/level-design exercise once someone builds a raft-like vehicle tuned to lean into it
  (low `liquidFriction`, current-favorable `liquidFlowFactor`).
- **Rapids impact.** Getting slammed into a wall by a strong current currently does nothing
  special. Could feed the same flow-speed value already computed for currents/foam into a
  knockback or minor damage effect above some threshold - "a real current can hurt you."
- **Ambient water sound scales with local current strength**, using the exact same gradient
  calculation the currents/foam already use — loud rapids, quiet ponds, no new detection logic
  needed, just a volume/pitch curve off a value that already exists.

## Buoyancy & density

- **Per-material buoyancy for dropped items.** Right now `liquidBuoyancy` is set per entity type
  in movement config, not per material - wood floats, metal sinks, mods can't differentiate items
  finely because it's one property. Making item drops read a buoyancy hint off their material
  (or a per-item config field) would need a small plumbing change but no new physics concept.
- **Layered/immiscible liquids** - oil floating on water, forming a visible distinct layer
  instead of the two liquids fighting over the same tile via `liquidInteraction`. This is a
  genuinely new simulation concept (the engine currently treats one tile as holding one liquid
  type at a time) - the biggest lift on this list.
- **Displacement.** Dropping something large into a full container could raise the local level a
  little (or just look like it does, cosmetically, via a brief particle/ripple burst) rather than
  liquid volume being completely indifferent to what's floating in it.

## State changes

- **Freezing / melting.** Cold biomes already have snow/ice content; water freezing into ice near
  an ice liquid source, or ice melting near heat, would use the same `liquidMaterialInteraction`
  /`liquidModInteraction` config hooks that already turn lava+water into obsidian - this is
  content authoring on an existing mechanism, not a new one.
- **Evaporation / steam.** Water meeting lava already has a defined interaction (obsidian); a
  visible steam-burst particle effect at the interaction point, or slow evaporation of shallow
  water near a strong heat source, would build on the same `liquidCollision`/`liquidInteraction`
  callback that already fires for exactly this kind of contact.
- **Boiling/bubbling visual near heat sources** - cosmetic only, likely achievable with the same
  "continuous function of position + time" shader trick used for the current wave/shine effect,
  gated by proximity to a heat-emitting tile instead of by flow.

## Environmental systems

- **Tides for ocean biomes** - a slow, periodic rise/fall of sea level. Mechanically this is
  "occasionally nudge the level of source tiles along a coastline," which the liquid engine
  already supports (source cells, `setLiquid`) - the new part is a world-level timer driving it.
- **Flooding events tied to weather intensity** - heavy storms temporarily raising liquid levels
  in low-lying areas, on top of the rain-projectile system that already deposits liquid on
  impact. Mostly about deciding *where* it's allowed to accumulate (drainage) rather than *how*.
- **Aquifers / natural refill.** Dug-out underground pockets slowly refilling from a hidden
  source over time - same source-cell mechanism as tides, applied underground instead of at a
  coastline.

## Visual/rendering depth

- **Depth-based tint.** Liquid tiles currently render with one flat color regardless of depth. A
  gradient darkening/saturating with distance from the surface (or from open air) would read as
  "this lake has depth" - doable in `world.frag` using the same per-tile draw-level data already
  computed in `TilePainter::produceLiquidPrimitives`, no new per-vertex data needed.
- **Underwater screen tint/fog** when the camera (or the player) is submerged - a full-screen
  overlay in the same family as the lightning-flash mechanism from the weather work, just
  triggered by submersion instead of a strike.
- **Caustics** - the dancing light-ray patterns real underwater scenes have. Same "continuous
  function of world position + time" technique as the current wave/shine effect, applied as a
  light-map modulation instead of an albedo one.
- **Refraction distortion** for what's visible through water (terrain/sprites behind/under a
  liquid surface). Bigger lift than the above - would need the water pass to sample an
  already-rendered background layer and offset it, which isn't how the renderer is structured
  today (liquids currently render as flat-colored quads over whatever's already drawn behind
  them, not as a separate distortion pass).
- **Cheap surface reflections** - even a rough, low-cost version (a vertically-flipped, blurred
  sample of what's just above the surface tile) would sell "surface" a lot harder than a flat
  color does. Same caveat as refraction: needs a render pass that can read back nearby already-
  drawn pixels, which is a bigger architectural change than anything shipped so far.
- **Rising bubble particles** from underwater vents or from entities moving through liquid -
  straightforward particle content, same pattern as the wall-foam particles already shipped.

## Hazards & mechanics

- **Riptides** - a scripted, localized dangerous current for ocean biomes, same
  `PhysicsForceRegion` hook as whirlpools/undertow above, just authored as a hazard rather than a
  traversal mechanic.
- **Quicksand-style heavy liquid** - a "liquid" that behaves like negative buoyancy (pulls down
  instead of pushing up), trivially expressible with the existing per-type `liquidBuoyancy`
  system - already possible today with the right movement config on a custom liquid, mostly
  worth calling out as an underused option rather than something to build.
- **Corrosive/toxic liquid visual bubbling + more distinct status feedback** than the current
  flat tint, building on the acid rain status-effect work already shipped.

## Liquid variety as content (no new engine code)

A reminder that a lot of "new liquid physics" is really just new liquid *content* on mechanisms
that already exist:

- Honey/mud: very high `liquidFriction`, near-zero `liquidFlowFactor` response - already
  expressible.
- Oil: low friction, flammable (status effect / ignite-on-contact via existing interaction hooks).
- Carbonated/bubbling liquids: cosmetic particle emission, no physics change at all.

## Modding/scripting hooks

Dug into the object and Lua-binding side this pass — a couple of real gaps stood out.

- **Expose current/flow to Lua.** `world.liquidAt`/`liquidAlongLine` are already bound
  (`source/game/scripting/StarWorldLuaBindings.cpp`) but only return level/id — the current/flow
  direction built for `sampleLiquidFlowVelocity` has no Lua-facing equivalent at all. A thin
  `world.liquidFlow(pos)` binding would let scripted objects react to real currents with zero new
  physics work, just a getter.
- **`PhysicsObject` is an already-built, ready-to-use hook** for water-reactive machines: it's a
  scriptable object that already supports configurable `PhysicsForceRegion`s and
  `PhysicsMovingCollision`s (`source/game/objects/StarPhysicsObject.{hpp,cpp}`). Nothing currently
  queries liquid level/flow from an object at all (confirmed - no object reads `liquidLevel`
  today). Combined with the Lua binding above, this is what a water wheel, a tide-driven power
  generator feeding the wire network, a sluice gate, or a dock that bobs with local liquid level
  would be built on - genuinely just content once the one binding exists.

## Combat/elemental crossover

Checked for existing fire/electric/water interactions - there aren't any yet, so these are wide
open rather than "extend what's there":

- **Water conducts electricity.** An electric attack landing in or near a connected liquid body
  should damage everything submerged in that *same connected body*, not just the impact point -
  the classic "shock the whole pool" mechanic. Needs a flood-fill over the liquid tile graph to
  find what's actually connected (the liquid engine already walks this graph internally for
  simulation, just not exposed for this purpose), so it's a real, if bounded, new feature rather
  than a config tweak.
- **Water extinguishes fire.** No status effect currently checks for liquid contact to clear an
  "on fire" state - a burning entity wading into any liquid staying on fire looks like an
  oversight once you notice it. Straightforward status-effect-side hook once someone wants it.
- **Cold liquid contact status effects** (a "Chilled"/slowed debuff from ice-liquid, distinct from
  just tuning friction/buoyancy) - authored content on the existing per-liquid `statusEffects` list,
  same mechanism "wet" already uses.

## Diving & breath

There's already a real breath/drowning system (`Player::breath()`, a depletable "breath" resource
in `StatusController`) - these are about deepening it, not building it from scratch:

- **Breath depletion tied to current turbulence**, using the same flow-speed value the
  currents/foam/ambient-sound ideas above all reuse - a calm pool costs breath at the normal rate,
  a rapid or waterfall column drains it faster, which gives strong currents a reason to be
  dangerous beyond just displacement.
- **Air pockets underwater** - a submerged empty tile (surrounded by liquid but open to breathable
  air, e.g. a bubble under an overhang) as a deliberate "come up for air here" beat in underwater
  dungeon design. Detecting one is just the existing `breathable(pos)` world query at a
  liquid-surrounded position - the new part is dungeon content built around it, plus maybe a
  bubbling particle/visual cue so players notice one from a distance.

## Farming/irrigation

Checked `StarPlant.cpp` - plant growth currently has **no liquid/water dependency at all**, so
"crops need water" isn't implemented, just assumed by genre convention:

- **Growth rate (or a grow/don't-grow gate) tied to nearby liquid**, sampled the same way currents
  already sample neighboring tiles. Would give irrigation channels - which the liquid simulation
  can already carry water through - an actual gameplay payoff instead of being purely decorative.

## Boats & vehicles

Checked `StarVehicle.cpp` - vehicles have zero liquid-specific logic today; a "boat" is just a
generically-tuned entity with no real nautical behavior:

- **Cargo-weight-affected draft/buoyancy** - a heavier-loaded boat rides lower and gets pushed
  around by currents more, using the buoyancy system that already exists per-entity, just made to
  respond to a runtime cargo value instead of a fixed config number.
- **Capsizing above some current-speed threshold** - reusing the flow-speed value everything else
  on this list reuses, as a real consequence of taking a raft into rapids it can't handle.
- **A raft explicitly tuned to surf the current system already shipped** (low friction, current-
  favorable `liquidFlowFactor`) rather than fight it - fast transportation on rivers, awkward on
  land, as an intentional tradeoff rather than an edge case.

## Multiplayer/technical fidelity

- **Sync pressure (or a compact flow hint) to clients.** Right now clients only receive liquid
  *level*, quantized to a byte and clamped to [0,1] - pressure never crosses the network. The
  gameplay currents and visual shimmer both work around this by deriving an approximation from
  level alone, which is why they can't see genuine hydraulic-head effects (e.g. a pressurized
  pipe with a uniform level throughout). Syncing even a coarse pressure byte would let currents
  feel more "real" in exactly those cases, at the cost of a network protocol change.
