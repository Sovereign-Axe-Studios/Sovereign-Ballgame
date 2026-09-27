# Mods wave 2: design

2026-09-26. Status: built (see HANDOFF §17).

One new mod per category, plus spawn direction gets three: every category
ends with at least two, and spawn direction, ball collision and wall end with
three. Same pattern as wave 1:
- one file per mod in `scripts/mods/<category>/`, tunables as `const`s at the
  top;
- a `draw_preview` sketch;
- a line in `cfg.gd`.

| Category | New mod | File |
|---|---|---|
| Shot spread | Sprinkler | `shot_spread/sprinkler.gd` |
| Ball collision | Poison | `ball_collision/poison.gd` |
| Wall | Bounce Pierce | `wall/bounce_pierce.gd` |
| Spawn direction | Reinforcements (built for real) | `spawn_direction/reinforcements.gd` |
| Spawn direction | Pile-Up (Theo's) | `spawn_direction/pile_up.gd` |
| Spawn direction | Virus | `spawn_direction/virus.gd` |
| Shape | Triangles | `shape/triangles.gd` |
| Rotation | Random Rotation | `rotation/random_rotation.gd` |
| Density | Checkers | `density/checkers.gd` |
| Grid | Compact 5×7 | `grid/compact_grid.gd` |
| Loss | Health | `loss/health.gd` |

---

## New hooks

Same rule as before: a direct typed call, owned by one category (except
where marked "every").

| Hook | Owner | Called from | Default |
|---|---|---|---|
| `shot_direction(rules, aim, shot_index) -> Vector2` | SHOT_SPREAD | `Game._spawn_ball` (index counts shots this round) and `ModLivePreview` | `rules.spread_direction(aim)`, today's behaviour |
| `on_block_hit(rules, ball, block)` | BALL_COLLISION | `Ball`, after the damage call | nothing |
| `configure_ball(rules, ball)` | WALL | `Ball.launch` | nothing |
| `advance_field(rules, grid, round_number) -> bool` (true = lost) | SPAWN_DIRECTION | `Game._end_round`, replacing the `spawn_row` + `advance` pair | `grid.spawn_row(round + 1)` then `grid.advance()` |
| `choose_columns(rules, width, count, round_number) -> Array[int]` | DENSITY | `GridManager.spawn_row` | `count` random distinct columns (today's shuffle) |

Supporting changes:
- **`GridManager`:**
  - `resolve_death_row(blocks) -> bool` is split out of `advance`, so every
    spawn-direction mod ends through the same `Debug.invincible` /
    `on_death_row_reached` path.
  - New public helpers: `move_cell(from, to)`, `occupant(col, row)`,
    `place_block(value, col, row)`, `merge_into(block, value)`.
  - `spawn_row` gains an optional target row.
- **`Block`:** a `Shape.TRIANGLE` (upright or flipped), and a generic
  `badge: String` drawn in its corner (Poison's stack count).
- **`Ball`:**
  - `finish()` becomes public, so a mod can end a ball.
  - `pierced: Dictionary`, per-ball state for Bounce Pierce.
  - `side_bounces: int`.

---

## The mods

**Sprinkler** (shot spread). Shots cycle through fixed offsets from the aim,
left to right, then repeat. `OFFSETS := [-20.0, 0.0, 20.0]` degrees.

**Poison** (ball collision). Block contacts deal 0 immediate damage and add
`STACKS_PER_HIT := 1` poison stack. Stacks persist, and at every round end
(before the next shift) each poisoned block takes damage equal to its
stacks. The block's `badge` shows "☠n". Live preview off, since the preview
has no round ends.

**Bounce Pierce** (wall).
- `configure_ball` takes blocks out of the ball's collision mask. In
  `on_ball_moved`, the block under the ball (`grid.block_at`) takes
  `ball_damage` once per ball per block.
- Side-wall bounces are counted in `on_wall_hit` (returns false, so it still
  bounces). After `MAX_SIDE_BOUNCES := 3` the ball finishes. The ceiling
  doesn't count.

**Reinforcements** (spawn direction, the existing placeholder, now
`available`).
- Rows alternate moving: on even rounds the even-indexed rows move down one,
  on odd rounds the odd rows.
- A block moving into an occupied cell merges: its value adds to the block
  there, and the mover is freed. Pickups in the way are collected
  cosmetically (freed).
- The new row spawns into row 0 every round, merging onto anything still
  there.

**Pile-Up** (spawn direction, Theo's design). For each column: the new row's
block (if the column got one) enters at row 0 and pushes down through the run
of touching occupants below it. The push stops at the first empty cell, which
the last pushed occupant fills. Occupants below a gap don't move. A column
that got no new block doesn't move at all. Pickups count as occupants.

```
before        new [3] arrives     after
r1 [5]                            [3]
r2 [4]                            [5]
r3 ( )  gap                       [4]
r4 [9]                            [9]  not pushed
```

**Virus** (spawn direction).
- The field never shifts. Each round the row's units spawn into random cells
  of rows 0-1; landing on an existing block adds to its value.
- Then every surviving block with value ≥ `MIN_SPLIT_VALUE := 2` splits:
  - it keeps half its value (rounded up);
  - it sends the other half to a random neighbour (down, left or right,
    weighted `DOWN_WEIGHT := 2`); an occupied neighbour absorbs it (value
    adds).
- Total value is conserved. The loss is a block spreading onto the death
  row.

**Triangles** (shape). Every block is a triangle, flipped on alternating
`(col + row) % 2`, so rows tessellate. `ConvexPolygonShape2D` collider.

**Random Rotation** (rotation). Each block gets `randf_range(0, 90)`
degrees, fit-scaled like Tilt.

**Checkers** (density). `choose_columns` returns only the columns whose
parity matches `round_number % 2` (4 or 3 of the 7), so rows stack in a
checkerboard. It still leaves at least one open slot.

**Compact 5×7** (grid). Value-only: `grid_width = 5`, `grid_height = 7`.
Live preview off.

**Health** (loss). `START_HEALTH := 100`.
- `on_death_row_reached` subtracts the landing blocks' values from health and
  destroys them.
- The run ends at ≤ 0. The HUD shows "HP n". Live preview off.

---

## Curated modes

Unchanged. Wave 2 is reachable through Custom.

## Verification

- `check_mods` covers every new file.
- Headless harnesses:
  - Sprinkler's directions cycle.
  - Poison applies stacks and ticks at round end.
  - Bounce Pierce damages each block once and stops at 3 side bounces.
  - Pile-Up matches the column example above.
  - Reinforcements merges.
  - Virus conserves total value per round.
  - Checkers keeps its parity.
  - Health counts down and ends the run.
- Auto-play every new mod to game over or round 10, with no script errors.
- Screenshots of Triangles, Random Rotation, Checkers, Poison badges, and the
  new tiles in the Custom grid.
