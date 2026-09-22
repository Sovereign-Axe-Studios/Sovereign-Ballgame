# CLAUDE.md — Sovereign Ballgame

Read `docs/HANDOFF.md` before your first change. It has the current state, the
data model, and the ordered next tasks. `docs/ROADMAP.md` is the build order.

## What this is

A Ballz-style brick breaker in **Godot 4.7**, portrait **1080x1920**, targeting
desktop and an S10-class Android phone. Main scene: `scenes/main.tscn`.
Repo root is this folder; the Godot project root is the same folder.

## The one architectural rule

**No gameplay number is written anywhere but `scripts/game_rules.gd`.**

`GameRules` is a `Resource` holding every tunable, plus virtual hooks
(`row_units`, `unit_value`, `open_slots`, `shots_for_round`, `death_row`). Every
other script receives a `GameRules` and reads from it. The whole point of the
project is the mod layer, and the mod layer is "swap or subclass GameRules" —
a magic number in `ball.gd` is a mod that can never exist.

If you need a new constant, add an `@export` to `GameRules` with a `##` comment
explaining what it does, and read it from there.

## Git — Theo commits, you do not

Theo uses GitHub Desktop and does his own committing, branching and pushing.

- **Never run** `git commit`, `git push`, `git branch`, `git checkout -b`, or
  anything that rewrites history.
- Instead: say which files changed and propose a commit message. He takes it
  from there.
- **Never add `Co-Authored-By: Claude` or similar trailers** to commit messages
  you propose.
- Repo identity is already set locally: `theo-sovereignaxe
  <theo.sovereignaxe@gmail.com>`. Do not change it.
- `git status`, `git diff` and `git log` are fine and encouraged.

## Code conventions

- Typed GDScript throughout: `func f(x: int) -> void`, `var v: float = 0.0`,
  `:=` where the type is obvious.
- **Tabs** for indentation (Godot standard), LF endings (enforced by
  `.gitattributes`).
- `##` doc comments on every class and every non-obvious function. Comments
  explain *why*, not *what* — the existing files set the tone, match it.
- `gdlint` must pass. Config in `.gdlintrc`: max line length 120,
  `class-definitions-order` disabled. `pip install "gdtoolkit==4.*"` then
  `gdlint scripts/*.gd`.
- Section banners (`# ---- spawning`) separate concerns in longer files.

## Things that are the way they are on purpose

- **The ball is a `CharacterBody2D`, not a `RigidBody2D`.** We want identical
  bounces every time — no restitution drift, no sleeping bodies, no gravity
  surprises. `Ball._physics_process` steps the frame's travel manually and
  consumes it across each bounce. Do not "simplify" this to a RigidBody.
- **Physics runs at 120 Hz** (`project.godot`). Balls move ~1750 px/s; a lower
  tick rate tunnels them through blocks.
- **Walls, ceiling and floor are built in code** (`Game._build_walls`) from
  `GameRules`, not placed in `main.tscn`. Grid-shape and wall mods need to move
  them, and a scene-placed wall can't be moved by a rules change.
- **The floor is a Y comparison, not a collider.** Crossing it ends the ball.
- **`ball_fire_interval` defaults to 0.09s**, not the 1.0s in Theo's original
  notes. Deliberate — see HANDOFF. Do not "fix" it back.

## Verification

Static parsing is not enough. `gdparse` and `gdlint` catch syntax, not the
things that actually break here (collision layers, node paths, signal
signatures, balls wedging between blocks). **Run the project** — `godot
--path . ` or F5 in the editor — and play a few rounds before calling
something done.

## Layout

```
project.godot        Godot 4.7, portrait, GL compatibility, 120 Hz physics
icon.svg             placeholder; neon options live in branding/icons/
branding/icons/      six neon icon candidates, Theo picks one
scenes/              main, ball, block, pickup
scripts/             see docs/HANDOFF.md for the file-by-file map
docs/HANDOFF.md      current state + next tasks  <- start here
docs/ROADMAP.md      full build order, what's done marked
```
