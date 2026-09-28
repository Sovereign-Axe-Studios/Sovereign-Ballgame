# Seeded runs, share codes and the Daily — design

2026-09-28 · status: step 1 (the randomness split) done; steps 2–6 not started

## Goal

Every run has a seed. The seed and the run's mods are packed into a short
code that anyone can paste into Mode Select to play the same run. A code can
also carry the sharer's score as a target. A Daily card gives everyone the
same mode and seed each day.

## What a seed guarantees (and what it doesn't)

**Guaranteed:** with the same mods and seed, row N spawns the same (columns,
values, pickups, block shapes and angles) for everyone, **however they have
played so far**. The per-shot randomness (Spread, Sprinkler, corner jitter) is
also seeded, so the same aim gives the same shots.

**Not guaranteed:** the rest of the run doesn't replay itself. Once two
players aim differently their boards diverge, and state-driven mods (Virus
spreading, Wormholes relocating into empty cells) diverge with them. That is
fine: everyone faces the same incoming rows. Full replays would need recorded
inputs plus cross-machine physics determinism, and they're out of scope.

## 1. Splitting the randomness

Today everything draws from Godot's global RNG, and `Game._ready` calls
`randomize()`. Cosmetic calls (fragments, ball return durations, audio pitch,
backgrounds) would shift the gameplay stream, so seeding the global RNG is
not enough.

`GameRules` gains:

```gdscript
var run_seed: int = randi()            # `seed` is a GDScript built-in
var field_rng := RandomNumberGenerator.new()
var shot_rng  := RandomNumberGenerator.new()

## Before the field step that brings in row `row_number` (advance_field /
## the opening rows).
func seed_field(row_number: int) -> void:
    field_rng.seed = derive_seed(run_seed, row_number, _FIELD_SALT)

## Before round `round_number`'s first shot.
func seed_shots(round_number: int) -> void:
    shot_rng.seed = derive_seed(run_seed, round_number, _SHOT_SALT)
```

`derive_seed` is a hand-rolled splitmix64-style mix, not `hash()`, which
Godot doesn't promise is stable across engine versions. `GameRules.advance_field`
calls `seed_field` itself, so every SPAWN_DIRECTION mod is covered.

**Fixed rolls come first.** A row's own draws happen before anything whose
draw count depends on the board. `spawn_row` rolls its pickup
(`GridManager.roll_pickup`) before placing blocks, because Random Tilt draws
once per *new* block and a merge draws nothing. Virus rolls its landings
before it spreads.

The row for round n+1 is spawned at the *end* of round n
(`advance_field` → `spawn_row(round_number + 1)`), so the field reseed is
keyed by the row being brought in, not by the round that's ending. The
opening rows are seeded the same way, and each one gets its own key.
Reseeding every step is what makes row N independent of how the earlier
rounds went.

**Field RNG** (`rules.field_rng`) is for anything that decides the board:

| Call site | Today |
| --- | --- |
| `grid_manager.gd` spawn_row stack scatter | `randi_range` |
| `grid_manager.gd` maybe_place_pickup (chance + column) | `randf`, `randi_range` |
| `game_rules.gd` default_open_slots | `randi_range` |
| `game_mod.gd` choose_columns | `Array.shuffle()` |
| `virus.gd` spawn + spread | `randi_range` |
| `wormholes.gd` _relocate | `Array.shuffle()` |
| `random_rotation.gd` configure_block | `randf_range` |

**Shot RNG** (`rules.shot_rng`) is for anything that steers a ball:

| Call site | Today |
| --- | --- |
| `game_rules.gd` spread_direction | `randf_range` |
| `ball.gd` corner jitter | `randf_range` |

`Array.shuffle()` has no RNG argument, so a new helper
`GameRules.shuffle(arr, rng)` (Fisher–Yates) replaces it at those two sites.

**Everything else stays on the global RNG**, unchanged: fragments, chunks,
ball return durations and STICK_RANDOM order, trail flecks, audio, the title
screen's stars, backgrounds and the reveal. Rule for new code: *if it changes
the board or a ball's path, it draws from `rules.field_rng` or
`rules.shot_rng`.* This rule goes into `CLAUDE.md`.

`ModLivePreview` builds its own `GameRules` with a random seed, so the ?
panel never touches a real run's streams.

## 2. The Run autoload

`Run` gains `seed: int`, `target: Dictionary` (empty, or
`{round, total}`) and `is_daily: bool`.

- `Run.start(mode, mods, seed := -1, target := {})`: -1 picks a random seed.
- Quick Play, the curated cards and Custom all pass through `Run.start`, so
  every run has a seed.
- **R keeps the seed.** R reloads the scene and `Run` persists, so this
  already works once `Game` reads `Run.seed`.
- **New seed:** a button on the pause root page and on the game-over
  screen restarts the same mode with a random seed and clears the target.

## 3. The share code

### Stable mod ids

Codes can't depend on `Cfg.MODS` order or file names. A new
`scripts/modes/share_code.gd` (`class_name ShareCode`) holds an
**append-only** table: for each category, a list of mod scripts. A mod's
code number is its index + 1, and 0 means "slot empty".

```gdscript
## APPEND ONLY. Removing or reordering entries breaks every shared code.
static func table() -> Array:   # a function: Cfg is an autoload (see CuratedModes)
    return [
        [Cfg.Spread, Cfg.Sprinkler],                  # SHOT_SPREAD
        [Cfg.Snowball, Cfg.Poison, Cfg.TimeRewind],   # BALL_COLLISION
        ...
    ]
```

A retired mod stays in the table as `null`, so its number is never reused.
`check_mods` fails if any `Cfg.MODS` entry is missing from the table.

### Bit layout (version 1)

| Field | Bits | Notes |
| --- | --- | --- |
| version | 4 | 1 |
| flags | 4 | bit 0 = has target |
| 9 category slots | 9 × 5 | 0 = empty, 1–31 = table index + 1 |
| seed | 32 | |
| target round | 12 | only if flag set, capped at 4095 |
| target total | 30 | only if flag set, capped |
| checksum | 10 | from `hash()` of the bits above |

That comes to 95 bits (**19 characters**) without a target and 137 bits
(**28 characters**) with one. The encoding is Crockford base32 (no I, L, O
or U), grouped in fives after an `SB` prefix:

```
SB-4F7KQ-2MX9A-RDT3P-8Q
```

Decoding ignores case, spaces and dashes, and reads O as 0 and I and L as 1,
so a typed code survives typos between look-alike characters. The version
field means per-mod values (a ROADMAP item) can come later in v2 without
breaking v1 codes.

### Decoding outcomes

| Result | Shown |
| --- | --- |
| OK | the code's mods as tiles, the seed, the target if any, and a PLAY button |
| Bad checksum, unknown version or garbage | "That code doesn't look right." |
| Unknown mod number (code from a newer build) | "This code needs a newer version of the game." |
| Two mods from one category | impossible by construction |
| An Outer Wilds mod (`locked_by == Unlocks.OUTER_WILDS`) and the egg unsolved | shown as ??? with "Look to the stars.", and PLAY disabled |
| Any other locked mod | playable. It stays locked in Custom afterwards; `Unlocks` is never written by an import |
| A mod with `available == false` | refused: "Uses a mod that isn't finished yet." |

`GameMod.is_selectable()` stays as it is for menus. Import uses a new
`ShareCode.can_import(mod)` with the rules above.

### Where codes appear

- **Pause menu root:** a CODE line under the mode summary, with COPY
  (`DisplayServer.clipboard_set`) and NEW SEED buttons. There's no target,
  because the run isn't over.
- **Game-over screen:** the code **with this run's score as its target**,
  plus COPY and NEW SEED. "press R to restart" stays.
- **Mode Select:** an ENTER CODE button below Custom opens an import panel:
  a text field, a PASTE button (`clipboard_get`), a preview of the decoded
  mods, the seed and the target, then PLAY.
- **Custom:** an optional SEED field above PLAY. Blank = random. Digits are
  used as the seed as they are; any other text is hashed, so "theo" is a
  valid seed.

## 4. Score to beat

The target is the round reached (the main score) and TOTAL (the tiebreak).

- In the HUD during a run with a target: `TARGET  R23` under the round
  counter, which changes to `BEATEN` once passed.
- At game over: "beat it by 4 rounds" or "4 rounds short", and the new code
  carries **this** run's score.
- Poison's round-end damage isn't counted in TOTAL (an existing open item).
  Fixing that first makes the tiebreak honest; it's listed as a
  prerequisite, not part of this work.

## 5. The Daily

A DAILY card at the top of Mode Select, above the curated grid.

- **Date:** the **UTC** date (`Time.get_date_string_from_system(true)`),
  so everyone rolls over at the same moment.
- **Mode:** `CuratedModes.all()` filtered to modes with no locked mods
  (fixed by definition, not per player, so everyone gets the same list),
  then indexed by `hash(["daily-mode", date]) % size`.
- **Seed:** `hash(["daily", date])` masked to 32 bits.
- **Card:** "DAILY · 2026-09-28", the mode's name and icons, and
  "best today: R17" if played.
- **Persistence:** `user://records.cfg` keeps `daily/<date>/best_round`
  and `best_total`. Only today's entry is read, and older entries can be
  pruned on write. It lives in a new small **`Records` autoload**, not in
  `Unlocks`. `Unlocks` holds permanent yes/no flags that the Debug Menu
  resets, while records are scores that change every run. Keeping them
  apart means resetting the egg never wipes scores. It also gives future
  per-mode bests an obvious home.
- A Daily run is shareable like any other, and its code is just mods +
  seed. It doesn't know it was a Daily, and it doesn't need to.

## 6. Checks

A new `scenes/tools/check_seeds.tscn`, a scene because tool checks must run
after autoloads:

1. **Round-trip:** encode → decode for every mod set in `CuratedModes`,
   random Custom sets, with and without a target, and the extreme seeds
   0 and 2³²−1.
2. **Rejection:** one flipped character fails the checksum; an unknown
   version and an unknown mod number give their own errors.
3. **Typo tolerance:** lowercase, spaces, O↔0 and I/L↔1 all decode the same.
4. **Determinism:** two headless `GridManager`s (built the way
   `ModLivePreview` does), with the same mods and seed, spawn identical rows
   1–30. A third one, with extra `field_rng` draws injected between rounds,
   still spawns identical row N (this proves the per-round reseed works).
5. **Daily:** the same date gives the same mode + seed; the chosen mode is
   never locked.

`check_mods` also gains the table-coverage check from §3.

## Out of scope

Replays and input recording. Online leaderboards. Per-mod values in codes
(v2, once that ROADMAP item exists). Persisting skin choices.

## Build order

1. Split the RNG (§1) plus the determinism check. Nothing visible changes;
   verify with `check_mods` and auto-play.
2. `Run.seed`, the reseed-per-round wiring, R keeps the seed, NEW SEED.
3. `ShareCode` encode/decode plus its checks.
4. UI: the pause code line, the game-over code, ENTER CODE, the Custom seed
   field.
5. The score-to-beat HUD and game-over lines.
6. The Daily card plus records.
