# Build order

`[x]` shipped · `[~]` partial · `[ ]` not started

## Basic version
- [x] Level with walls
- [x] Ball that moves on its own and bounces off walls
- [x] Ball dies if it hits the ground
- [x] Block in level that destroys on hit
- [x] Blocks taking multiple hits

## Shooter
- [x] Line pointing upwards, arrow keys rotate ±78°
- [x] Space spawns and shoots a ball upwards
- [x] Ball spawns pointing along the line

## Grid maker
- [x] Array grid class that spawns a block in each spot (`GridManager`)
- [x] Random population, at least one open slot per row

## Level basics
- [x] Only spawn on row 0
- [x] Up / down keys move blocks to the next grid row
- [x] Moving down spawns a new row above

## Round progression basics
- [x] Blocks have a numeric value = hits before break
- [x] Row spends `width` units worth the round number each, so blocks come out
      as multiples of the round (round 3 -> 3, 6, 9, 12), over random columns,
      leaving 1-3 open, max 4 units stacked on a cell

## Player progression
- [x] Player fires `ball_count` balls, one every `ball_fire_interval`
- [x] Ball++ pickup, spawned with each row, banked and applied at round end

## Aesthetic
- [x] Round number
- [x] Counter for damage per shot cycle
- [x] Counter for damage overall
- [x] Blocks change colour with health, ROYGBIV across 0–100
- [x] Visual for the ball shooter
- [~] Juice: hit chunks + destroy fragments done (fragment cols/rows
      configurable, Debug Menu adjustable), no screen shake yet --
      Settings.screen_shake_strength is plumbed, unconsumed
- [x] Balls gather to the new launch position instead of vanishing where they
      land, with 5 selectable variants (Stick x3 / Move to shooter / Line up
      -- Debug Menu, Skins.ReturnMode); the shooter slides on the FIRST ball's
      landing, not at round end
- [x] +1 ball pickup spawns a falling ball that lands before the count ticks up
- [x] A few alternate ball/background/block/launcher-shape visuals (a plain
      ball or a simple vector cannon), with live previews on the pause
      menu's Skins page (no art assets, so these are recolours/reshapes, not
      skins in the asset sense)
- [x] Background grid lines are pixel-snapped (were anti-aliasing to
      near-invisible on some rows/columns) and their thickness is a setting

## Challenge
- [x] Round advances once every ball is down
- [x] Debug lose message when a block reaches the bottom row
- [x] Game over overlay, `R` to restart
- [x] Invincible debug toggle: a Block landing in the death row is destroyed
      instead of ending the run (`Debug.invincible`, `GridManager.advance`)

## Drag integration  ← next
- [~] Mouse drag sets shooting direction (press, drag, release fires); a
      release past `max_aim_degrees` cancels the shot instead of firing at
      the clamped angle
- [ ] Click shooter to focus, then click elsewhere to shoot
- [ ] Dynamic predicted-bounce line while dragging
- [x] The shooter keeps showing its aim line through FIRING (pointed at the
      last shot), instead of dimming/hiding until the round resolves

## Modularity basics
- [x] `GameRules` resource holds every value, plus one `GameMod` slot per
      category that every hook delegates to (HANDOFF §14)
- [x] Categories: shot spread · ball collision · wall mods · spawn direction ·
      shape · rotation · density · grid · loss condition
- [x] One example mod per category: Spread, Snowball, Wrap Around, Circles,
      15° Tilt, Boss, 9x11 Grid, Lives. Spawn direction deferred --
      Reinforcements is listed greyed out
- [ ] Two mods per category
- [ ] Combine mods across all categories at once

## Basic port
- [ ] Standalone exe
- [ ] Android build for the S10
- [ ] Touch support
- [ ] Scale to any phone screen (stretch mode is already `canvas_items` /
      `expand`, so this is mostly HUD anchoring)

## Unscheduled
- [x] Title screen (`scenes/main_menu.tscn`: Play / Settings / States (stub)
      / Asset Viewer, arcade-styled, procedural starfield background) ·
- [x] Asset Viewer (`scenes/asset_viewer.tscn`): tabbed Skins / Modes / Audio,
      showing what the project actually has, not padded with placeholders
      for content (ships, bosses, etc.) that has no equivalent here
- [~] Mod menu: Play -> Mode Select (2 placeholder curated modes + Custom
      character-select grid: animated tile icons, ? detail panel with a live
      mini-board), Quick Play on the title screen. No per-mod value editing
      or persisting the chosen mods yet. Revisit the layout (tabs / loadout
      slots) once categories hold ~6-12 mods ·
      settings ([x] UI scale, SFX/music volume — no sounds routed yet;
      screen shake strength plumbed, unconsumed; [x] debug menu)
- [ ] Persistence across scenes: high scores, active mods
- [~] Mod unlocking: the `Unlocks` system exists (persisted, locked `???`
      tiles and skin chips). First unlock is the Outer Wilds constellation on
      the title screen (HANDOFF §15). The GDD's "new random mod every 25
      rounds" is not built
- [ ] Audio: BG, SFX, button click, collection, milestone stingers
- [ ] Consumables from milestones: delete a tile, shift up, 2048 slam,
      tapsplosion
- [ ] Checkpoints: save the block layout every X rounds or on demand
- [ ] Grid size chosen from the UI before a round

---

# Where the mods will plug in

`GameRules` is the single seam. Each category below maps to a specific place in
the current code, so none of this needs a rewrite:

| Category | Hook |
| --- | --- |
| Shot spread (Spread, Sprinkler, Short lifetime, Zig Zag) | `Game._spawn_ball` direction + a per-ball behaviour resource |
| Ball collision (Ghost, Missiles, Fracture, Infection, Group up, Poison, Gravity, Self collision, Billiards, Snowball, Buildup, Sniper) | `Ball._physics_process` bounce handler + `GameRules.shots_for_round` |
| Wall mods (Wrap around, Bounce pierce, Portals) | `Playfield.build_walls` + `GameMod.on_wall_hit` / `on_ball_moved` |
| Spawn direction (Sidewinder, Left/right march, Inverse, Reinforcements, Virus) | `GridManager.spawn_row` / `advance` |
| Shape (Circles, Octagon, Triangle) | `Block` collision shape + `_draw` |
| Rotation | `Block.rotation` at placement |
| Density (Dense, Solid, MiniBoss, Boss, Mafia, Pawn wall, Checkers, Tree) | `GridManager.spawn_row` distribution step |
| Grid (7×7, X×Y) | `GameRules.grid_width` / `grid_height` — already live |
| Loss (Basic, One last chance, Lives, Health) | `GridManager.advance` return + `Game._end_round` |

The intended end state is `GameRules` as a base class with a small stack of
mod resources applied over it, so a run is "base rules + these N mods".
