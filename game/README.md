# Sovereign Ballgame

A Ballz-style brick breaker built in Godot 4.7, portrait 1080x1920, aimed at
desktop and an S10-class Android phone.

The point of difference is the **mod layer**: every rule of the game is a value
or a hook on a `GameRules` resource, so shot spread, ball collision, wall
behaviour, spawn direction, grid shape, density, rotation and loss condition can
each be swapped and combined. See [docs/ROADMAP.md](docs/ROADMAP.md).

Picking this up mid-stream? Start with [docs/HANDOFF.md](docs/HANDOFF.md).

## Running it

Open `game/project.godot` in Godot 4.7 and press F5. `scenes/main.tscn` is the
main scene.

## Controls

| Input | Action |
| --- | --- |
| `←` `→` or `A` `D` | Rotate the aim line (clamped to ±78°) |
| `Space` | Fire the round's balls |
| Click-drag, release | Aim and fire with the mouse |
| `↓` | Debug: end the round without firing (shift down, spawn a row) |
| `↑` | Debug: pull the field back up a row |
| `R` | Restart |

## How a round works

1. Aim.
2. Every ball leaves the shooter in sequence, one every `ball_fire_interval`.
3. Balls bounce off walls, ceiling and blocks; each contact removes one point
   of block value. Crossing the floor line takes a ball out of play.
4. Once the last ball is down, the shooter slides to where the **first** ball
   landed, banked `+1 ball` pickups are applied, the field shifts down one row,
   and a new row spawns at the top.
5. A block reaching the bottom row ends the run.

## Tuning

The numbers live in `scripts/config/*.gd`, one small file per domain (board,
spawning, ball, wall corners, shooter, loss), indexed by the `Cfg` autoload
(`scripts/cfg.gd`). `scripts/game_rules.gd` reads its `@export` defaults from
those same files, so `Cfg.BALL_SPEED` and a fresh `GameRules.new().ball_speed`
are always the same number.

To play with values without touching code, create a `GameRules` resource
(`.tres`) in the editor and drop it on the `Main` node's **Rules** property —
that overrides the per-run instance without touching the shipped defaults in
`scripts/config/`.

### Row spawning

A row is handed `units_per_column × width` **units**, and one unit is worth the
round number. Round 3 on a width-7 board spends 7 units of 3, so every block it
makes is a multiple of 3 — 3, 6, 9, 12. Each row leaves 1–3 columns open
(`min_open_slots` / `max_open_slots`), and at most `max_units_per_cell` units
stack on one cell (4 by default; 0 disables, and it is raised automatically if
the row could not otherwise fit).

One deliberate departure from the design notes, flagged in a comment:
**fire interval.** The notes say one ball per second, which would make round 40
a forty-second wait, so the default is `0.09s`. Raise `ball_fire_interval` if
the slower cadence is what you want.

## Layout

```
game/
  project.godot
  icon.svg             placeholder; neon candidates in branding/icons/
  CLAUDE.md            rules of engagement for Claude Code
  branding/icons/      six neon icon options, one to be chosen
  docs/HANDOFF.md      current state, data model, next tasks
  docs/ROADMAP.md      build order, with what is done marked
  scenes/              main, ball, block, pickup
  scripts/
    cfg.gd             Cfg autoload -- thin index over scripts/config/*.gd
    config/            the numbers, one small file per domain
    game.gd            round loop, playfield construction, scoring
    game_rules.gd      every tunable number (defaults from Cfg) + the mod hooks
    grid_manager.gd    the block lattice: spawn, shift, loss check
    ball.gd            constant-speed reflector (not a RigidBody2D, on purpose)
    block.gd           numbered brick, ROYGBIV by health
    ball_pickup.gd     +1 ball
    shooter.gd         aim line
    hud.gd             round / balls / damage counters
    palette.gd         shared colours
```

Walls, ceiling and floor are built in code from `GameRules` rather than placed
in the scene, so a grid-shape or wall mod can change them without a scene edit.
