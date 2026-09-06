# Changelog

Plain-language summary of what changed, for anyone playing rather than developing - no file
names, no technical detail. See `CHANGES.md` for the full technical changelog aimed at whoever's
working on the code.

> **Branch note:** this is `main`. A separate `weather-expansion` branch has additional weather
> work (wind, lightning, fog, hail) not listed here yet. Only main branch changes are included here.

## main branch

### Version 0.1.15.2

#### Feat

- Added a small version label in the corner of the screen, mainly useful for testing.
- Water now gently ripples and shimmers instead of sitting completely still.
- Currents in rivers, waterfalls, and other flowing water now actually push you (and
  items, and other creatures) along with the flow.

#### Fix

- If something goes wrong on startup, the game now shows a clear error message with a
  button to close it, instead of just crashing with no explanation.
- Fixed a crash that could happen if a connection to a server failed partway through
  joining a game.
- Fixed a rare issue where a player's name could fail to reach the server correctly while
  joining, which then caused a crash.
