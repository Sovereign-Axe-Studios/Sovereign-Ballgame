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
| `A` `D` | Rotate the aim line (clamped to ±78°) |
| `Space` | Fire the round's balls |
| Click-drag, release | Aim and fire with the mouse |
| `R` | Restart |
| `Esc` | Pause menu |

`←` `→` `↑` `↓` are reserved for the debug menu (see below), not aiming --
that's deliberately A/D-only now so the two don't fight over the same keys.

## Pause menu

`Esc` opens the pause menu: **Resume**, **Settings**, **Debug Menu**, **Main
menu** (stub -- no main menu scene exists yet). Settings and Debug Menu each
open their own page, with a **Back** button to return.

### Settings

UI scale (zooms the HUD / pause / debug-overlay layers, 50–200%), screen
shake strength (not consumed yet -- no screen shake exists), and SFX / Music
volume, which move the "SFX" / "Music" audio buses (`audio/bus_layout.tres`;
no sounds route through them yet either, but the buses and sliders are real).
All four persist to `user://settings.cfg` via the `Settings` autoload.

### Debug menu

The Debug Menu page has an **Enable debug mode** checkbox. While it's on:

| Input | Action |
| --- | --- |
| Click/tap a block | 1 damage |
| Shift+click, or a two-finger tap | Destroy that block outright |
| `↑` `↓` | Ball count +/- 1 |
| Shift+`↑` `↓` | Shift the whole field up/down one row |
| `←` `→` (held) | Move the shooter (and any live balls) sideways |
| Shift+`←` `→` | Level +/- 1 |

Shifting the field up "banks" a credit: the next N real round-completions
shift down without spawning a new row or advancing the level, since an
up-shift manufactures slack that normal play didn't earn. On screen (touch or
mouse), a `+`-shaped D-pad does the same four directions, with a center toggle
button standing in for holding Shift; a button next to each row clears it, and
a bottom-left hold-to-fill button clears the whole field. The Debug Menu page
also has grid width/height/kill-row/spawn-row fields (Apply resets the
board), a game-mods stub, a save-game-state stub, and **Restart** (moved here
rather than the pause-menu root, to match the four-button spec above).

The on-screen D-pad and two-finger-tap gesture are unverified on real touch
hardware -- there's no Android/touch build yet (see ROADMAP.md).

## How a round works

1. Aim.
2. Every ball leaves the shooter in sequence, one every `ball_fire_interval`.
3. Balls bounce off walls, ceiling and blocks; each contact removes one point
   of block value. Crossing the floor line takes a ball out of play.
4. Once the last ball is down, the shooter slides to where the **first** ball
   landed, banked `+1 ball` pickups are applied, a new row spawns at the top,
   and the field shifts down one row -- in that order, so row 0 reads as
   clear again once the shift settles, the same as it does before round 1.
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
  audio/bus_layout.tres  Master -> Music, SFX buses (no sounds routed yet)
  scripts/
    cfg.gd             Cfg autoload -- thin index over scripts/config/*.gd
    config/            the numbers, one small file per domain
    debug_state.gd     Debug autoload -- the debug-mode on/off flag
    settings_state.gd  Settings autoload -- persisted user prefs
    ui/pause_menu.gd   pause menu pages: root, Settings, Debug Menu
    ui/debug_overlay.gd  row-clear buttons, clear-all, on-screen D-pad
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
