# Known Engine Bugs

Bugs found while working on this fork that look like they live in the engine itself (asset
loading, JSON patching) rather than in any specific content this repo ships. Each one includes
enough to reproduce and investigate a real fix, not just a workaround.

---

## JSON patch race: plain-object merge patches crash on heavily/eagerly-read assets

**Status:** Workaround in place (use array/`add` patches - see `CLAUDE.md` → "Asset patching").
Root cause not fixed, and not fully isolated - needs someone to actually dig into
`Assets::readJson` / `applyJsonPatches` thread-safety.

### Summary

A `.patch` file written as a plain JSON object (deep-merged onto its base via `jsonMergeNulling`)
can crash the game at startup with:

```log
(AssetException) Could not read JSON asset <path>
Caused by: (JsonParsingException) Cannot parse json file: <path>
Caused by: (JsonException) Improper conversion to JsonArray from object
```

This is **not deterministic per-file in an obvious way** - it doesn't reproduce for every
plain-object patch, but it has now reproduced on two unrelated files (see below), including one
whose patch content already ships to real players today. That rules out "this specific content is
malformed" as the explanation.

### Confirmed reproductions

1. **`weather/rain/storm.weather.patch`** (new content, added in this fork's weather work) - a
   trivial single-key plain-object patch (`{"lightningChance": 0.06}`) against *any* `.weather`
   file crashes the same way. `.weather` files are bulk-prefetched eagerly by `BiomeDatabase`'s
   constructor (`scanFiles("weather", m_weathers)` in `source/game/StarBiomeDatabase.cpp`) via
   `assets->queueJsons(files)` followed by a synchronous `assets->json(path)` per file.
2. **`assets/opensb/client.config.patch`** - crashed identically, and critically, **using its
   pre-existing, already-shipped, unmodified content** (no new keys at all - just the
   `universeScriptContexts`/`warpCinematicBase`/etc. block that's been in this repo's history and
   presumably ships fine in production). `/client.config` isn't extension-bulk-scanned like
   `.weather`, but it's read very early by *multiple independent database constructors on
   different worker threads* - confirmed via stack trace that both `MaterialDatabase` and
   `ItemDatabase` (via `ObjectDatabase::readConfig`) pull `/client.config:defaultFootstepSound` as
   part of their own construction.

Reproduction is **not test-content-specific**: it happened for genuinely trivial new content and
for real, already-shipped content alike. The common thread across both cases is *the same JSON
asset being read from more than one place around the same time during startup*, not what the
patch actually says.

### Where it's actually throwing (and why that's suspicious)

The crash is thrown from inside `Assets::readJson` (likely with `applyJsonPatches` inlined into
it, based on symbol names in the stack trace), specifically from a `Json::toArray()` call. In
`source/base/StarAssets.cpp`, the only `.toArray()` call in that path is guarded immediately
beforehand by a type check:

```cpp
if (patchJson.isType(Json::Type::Array)) {
  auto patchData = patchJson.toArray();   // <- this is what throws "Improper conversion ... from object"
  ...
```

For `.toArray()` to throw "improper conversion from object" *right after* `isType(Array)` returned
true implies the value observed by the type check and the value observed by `.toArray()` are not
the same value - which is the signature of a data race (something else mutating/replacing the
cached `Json` between the check and the use), not a logic bug in this function itself. The crash
always lands on a background `Star::WorkerPool::WorkerThread` in every capture so far, consistent
with two threads racing to resolve the same not-yet-cached patched asset for the first time.

This is a hypothesis based on the available evidence (stack traces + the "shouldn't be reachable"
nature of the throw), not a confirmed root cause - it needs someone to actually instrument or
read `Assets`'s caching/locking around `m_files` / patch resolution to confirm.

### Two related-but-distinct wrinkles found alongside it

- **The custom `"merge"` patch op appears to be an OpenStarbound-only extension.** Vanilla
  Starbound's engine logs `(JsonPatchException) Invalid operation: merge` and skips the operation
  (non-fatal - the patch just silently never applies). This means the validation technique in
  `CLAUDE.md` (which runs against a real, separately-installed, *vanilla* Starbound binary,
  since this repo has no way to build+run its own fork here) **cannot validate `"merge"` operations
  at all** - a `"merge"` patch might work fine once actually compiled into OpenStarboundEX, but
  you'll never see confirmation of that through this method. This is not necessarily a bug, just
  a blind spot in how it can be tested from here - someone with an actual compiled OpenStarboundEX
  binary should confirm `"merge"` operations work as intended.
- **Array-style patches using only standard ops (`add`/`remove`/`replace`/`move`/`copy`/`test`)
  have never reproduced the crash**, across every attempt on both affected files (10+ boots).
  Whether that's because the array code path (`checkPatchArray`) is genuinely safer under
  concurrency, or just because it happens to run fast/differently enough to dodge the race window,
  is unknown.

### How to reproduce

See `CLAUDE.md` → "Validating asset patches against the real game" for the full recipe
(unpack real assets, pack a scratch mod with just the suspect patch file, boot
`starbound_server` against base + scratch pak with a throwaway boot config). To reproduce this
specific bug:

1. Take `assets/opensb/client.config.patch` (or any `.weather.patch`) as a **plain JSON object**
   (not the array form it's currently written in on this branch).
2. Pack it alone into a scratch mod pak and boot against it, per the recipe above.
3. It should crash within ~1-2 seconds of boot, before any world loads, with the stack trace shape
   above. Repeating the boot a handful of times is worth doing - given the race hypothesis, it's
   plausible (though not yet observed) that it doesn't reproduce 100% of the time.

### Workaround in use in this repo

Write `.config`/`.weather` patches as an RFC6902-style array of operations using only the
standard ops, e.g.:

```json
[
  { "op": "add", "path": "/someNewKey", "value": 123 }
]
```

instead of:

```json
{
  "someNewKey": 123
}
```

`assets/opensb/client.config.patch` and `assets/opensb/weather/rain/storm.weather.patch` (on the
`weather-expansion` branch) are both working examples. This avoids the crash in every test so
far, but is a workaround, not a fix - the underlying race (if that's what it is) is still there
for anyone who writes a plain-object patch against an affected file in the future, including
outside this repo.

### Suggested next steps for an actual fix

- Get eyes on `Assets::readJson` / `Assets::applyJsonPatches` / `Assets::doLoad` /
  `Assets::loadAsset` in `source/base/StarAssets.cpp` with concurrency specifically in mind:
  what's locked, what's cached, and whether two threads resolving the same not-yet-cached
  patched asset for the first time can observe each other's partial work.
- Try to build a tighter repro: a minimal custom asset + object that both eagerly reference it
  from two different `Root::loadMember` database constructors, to confirm the "concurrent first
  access" theory directly rather than inferring it from stack traces.
- Confirm whether this reproduces on an actual compiled OpenStarboundEX binary at all (everything
  above was tested against vanilla Starbound 1.4.4, since this repo has no bundled assets to run
  its own build standalone) - it's possible OpenStarboundEX's fork has already changed something
  here, for better or worse.
