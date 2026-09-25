# Breakout Roguelite: Game Design Document

## Overview

A breakout style shooter where the player fires balls upward at descending rows of blocks. Blocks gain more value each round, forcing the player to prioritize targets and build power through modifiers. The core loop is inspired by Peggle/Breakout hybrids, with a modding system that lets rules be swapped and combined for high replayability.

---

## Core Grid and Round Loop

- Grid size: 7x7, bottom row empty (player position), top row empty (spawn zone)
- Each new row occupies 2 to 7 blocks, with a total value equal to Round * (3 to 7), spread across the occupied blocks
- Values can stack on a single block, capped at 2x the round number
- When a round ends, all rows shift down by one
- Loss condition (basic): if the bottom row still has any block value when the round ends, the game is lost
- Next round's row value = (current round + 1) * width, spread across width random blocks, with the ability to double up
- The next row always includes 1 ball++ pickup in an empty spot
- Every new row must have at least 1 open slot

### Scorekeeping

- Balls in play counter
- Current round hits counter
- Total hits counter

### Wall and Corner Physics

- Balls bounce normally off side walls
- Near corners: if the impact point's distance to the nearest corner is under a threshold value, apply a small random angle variation while preserving overall direction
- Alternative approach: use an octagonal collider sprite so corners behave distinctly without extra logic

---

## Build Order

### Phase 1: Basic Prototype

1. Build a level with walls
2. Ball moves on its own, bounces off walls
3. Ball dies if it hits the ground
4. Block in the level that is destroyed on a single hit
5. Blocks that require multiple hits to destroy

### Phase 2: Shooter

1. Vertical aiming line, rotated left/right with arrow keys in increments of +/- X degrees
2. Space bar spawns and fires a ball upward along the aim line

### Phase 3: Grid System

1. Basic array based grid class that spawns a block in each grid position
2. Basic random population: each row occupies width minus 2 spaces

### Phase 4: Level Basics

1. Blocks only spawn on row 1
2. Up/down keys shift all blocks by one grid row (rounded)
3. When shifting down, spawn a new row at the top

### Phase 5: Round Progression

1. Blocks carry a numeric value representing hits required to break
2. Next row's blocks are more powerful than the row above: value = (current round + 1) * width, spread horizontally across width minus 2 blocks

### Phase 6: Player Progression

1. Player fires (round number) balls, one per second
2. Basic ball++ pickup, integrated into the round spawner

### Phase 7: Aesthetics (Pass 1)

- Round number display
- Damage-per-shot-cycle counter
- Total damage counter
- Blocks change color by health, following a ROYGBIV gradient from 0 to 100
- Visual indicator for the ball shooter

### Phase 8: Challenge Rules

1. Once all balls from a shot cycle have hit the ground, advance to the next round
2. If any blocks remain in the lowest row, trigger a debug "lose game" print

### Phase 9: Drag/Aim Integration

1. Click the shooter to gain focus, then click elsewhere to fire (the line from the second click to the first sets the angle)
2. Mouse drag also sets shooting direction
3. Render a dynamic aim line while dragging

### Phase 10: Modularity Foundations

1. Build a game rules class that can specify: shot spread, ball collision behavior, wall mods, spawn direction, grid shape, density, rotation, and loss condition
2. Implement one example mod per category and confirm the rules class can be filled in for a new game rule
3. Repeat the above but covering all categories at once
4. Build out 2 mods per category

### Phase 11: Basic Port

1. Build a standalone executable
2. Build an Android version (target device: Galaxy S10)
3. Test transferring and playing on device
4. Add touch support for phones
5. Open question: scale to any phone screen size?

### Unscheduled / Not Yet Ordered

**Title Screen**
- Basic title screen with a single Start button
- Add a Mod Menu button
- Add a Settings button

**Settings Menu**
- BG volume slider
- SFX volume slider
- Debug button

**Mod Menu**
- Simple on/off toggle for a single mod
- Support multiple active mods across different categories
- Support mutually exclusive mods within a category
- Category headers
- Basic icons

**Persistence**
- Structure to hold data across scenes
- Store high scores
- Store which mods are active

**Mod Unlocking**
- Mods are locked at game start
- Every 25 rounds, unlock a new random mod
- Visual indicator for unlocks

**Audio**
- Background music
- SFX
- Button click sounds
- Pickup/collection sound
- Misc stingers
- Possible audio callout for milestones (e.g. 50 balls in a row, clearing the board)

---

## Consumable Abilities (Milestone Rewards)

Earned by hitting a milestone (total score, a score threshold within a round, or reaching round X):

- **Delete tile**: remove one tile by tapping it
- **Shift up**: move all tiles up one row
- **2048**: shift all tiles as far as possible in one chosen direction
- **Tapsplosion**: tapped tile explodes, dealing (ball count + 1) / 2 damage to adjacent tiles and 1/4 damage to tiles two spaces out

---

## Game Modes and Modifiers

The base game (**Basic Mode**) fires straight shots with standard bounce behavior. All modes below are modifiers layered on top via the mod system.

### Shot Spread Mods

| Mod | Description |
|---|---|
| Spread | Each shot fires at the aim angle +/- X degrees of random variation |
| Sprinkler | Shots fire from X arc positions relative to the aim angle (e.g. 3 positions: -30, 0, +30), cycling left to right and resetting at the end |
| Short Lifetime | Shots deal 2x damage but expire after X seconds |
| Zig Zag | Shots reverse lateral direction every X seconds, inverting relative to the last wall/side hit |

### Ball Collision Mods

| Mod | Description |
|---|---|
| Ghost Mode | Ball does not collide until it hits an outer wall; becomes solid again once it enters an open square |
| Missiles | Shots deal 2*X damage with 1/X the ball count; each ball explodes on contact in a grid radius of Y |
| Fracture | Destroyed blocks spawn a ball in a random direction; spawned balls are limited to X bounces |
| Infection | Shots are absorbed into the block they hit; on block death, stored balls eject in random directions; stuck balls expire after 1 to 2 rounds |
| Group Up | Shots stick to the block on impact, dealing 2x damage, and remember their would-be bounce direction; on block death, all stuck balls release; otherwise they vanish (possibly after 1 round) |
| Poison | Balls apply poison stacks and can only bounce off a given block X times; at end of round, blocks take damage equal to their poison value before moving |
| Gravity | Shots arc downward under gravity |
| Self Collision | Ball count reduced to 1/X, but balls collide with each other using circle collision |
| Billiards | One ball per round with power equal to ball count; balls have friction, persist across levels, and despawn after X rounds |
| Snowball | Ball count reduced to 1/X, but each ball gains +1 impact power per bounce (scales fast in dense fields, slower in sparse ones; may become unwinnable at high rounds with few strong blocks) |
| Buildup | Ball count reduced to 1/X; power doubles on wall hit, halves on block hit (after damage is applied) |
| Sniper | Ball count reduced to 1/X; every X pickups grants a new ball with damage equal to pickup count; balls fire one at a time, next ball fires once the previous lands |

### Wall Mods

| Mod | Description |
|---|---|
| Wrap Around | Balls hitting the left/right wall reappear on the opposite side |
| Full Wrap Around | Same as Wrap Around, but also applies to top/bottom up to N times; passing through top/bottom does not cost a life, but reduces ball durability by 1 |
| Bounce Pierce | Shots pierce blocks and bounce off side walls up to X times |
| Wrap Pierce | Shots pierce blocks and wrap on side walls; hitting the top ends the ball |
| Portals | Left wall connects to the bottom, right wall connects to the top; usable up to X times per ball; balls exit at the same relative position along the connected edge that they entered (e.g. entering the left wall 25% up exits the floor 25% from the left) |

### Spawn Direction Mods

| Mod | Description |
|---|---|
| Sidewinder | Left and right walls become end zones; player still shoots from the bottom; bottom wall bounces balls without costing a life |
| Right/Left March | Blocks spawn on one side and move toward the other; reaching the far side is a loss; spawn orientation rotates 90 degrees from normal |
| Inverse | Player shoots from the bottom, but blocks spawn just above the player and move upward; loss condition triggers at the top |
| Reinforcements | Blocks move every other turn; a row moving into an occupied row adds its value to it (odd and even rows alternate moving) |
| Virus | Blocks spawn in the top two rows; spawning onto an existing block adds to its value; surviving blocks spawn a new block in a random direction with half their value, while losing half their own value |

### Shape Mods

- Circles
- Octagons
- Triangles

### Rotation Mods

| Mod | Description |
|---|---|
| Normal | Blocks align to the grid |
| 5° x N Rotation | All blocks rotated by 5 degrees times an input value N |
| Random Rotation | Each block gets a random rotation |

### Density Mods

| Mod | Description |
|---|---|
| Dense | Always spawns 6 blocks with value equal to the round number (no stacking on one tile) |
| Solid | Only 3 tiles spawn per row, each doubled up |
| MiniBoss | Only 2 tiles spawn per row, each tripled up |
| Boss | 1 tile spawns per row at 6x strength |
| Mafia | 3 blocks spawn: one at 3x, one at 2x, one at 1x value |
| Pawn Wall | Fills all available spaces (only the ball's gap remains open), using values from X rounds prior, forming a full wall of weaker blocks |
| Checkers | Blocks always spawn one gap apart from neighbors, checkerboard style |
| Tree | Round 1 spawns a single block at a random column with value = round. If destroyed, spawn 1 new block on the next row. If not destroyed, the next row's blocks must be diagonal to or above a block from the row below (row 1 has 1 possible block, row 2 up to 3, row 3 up to 5, etc.) |

### Grid Mods

- Basic: 7x7
- Modified: custom X by Y dimensions

### Loss Condition Mods

| Mod | Description |
|---|---|
| Basic | Blocks reaching the player's row end the game |
| One Last Chance | Blocks can advance one extra row before losing; if a block would land directly on the player's square, its value is added to the block above instead, and the loss triggers next time |
| Lives | Player has X lives; a row reaching the end zone removes a life instead of ending the game immediately; game ends when lives reach 0 |
| Health | Player has X health; blocks reaching the end zone disappear and subtract their value from health; game ends when health drops below 0 |

---

## Mod System Architecture

To support combining mods, the base game should be built around a **Game Mode class** that accepts the following as injectable components:

- Ball class
- Block class
- Walls class
- Ceiling class
- Floor class
- Block Spawn class
- Grid Layout class (7x7, 5x5, etc.)

The mod menu allows the player to toggle these on and off, configure per mod values, and run multiple compatible mods simultaneously.

---

## Open Design Questions

- Should grid size be player selectable before a run starts via UI?
- Checkpoint system: auto save block layout every X rounds, or trigger manually via debug menu?
- Should the player be able to toggle between spread shot and solid line shot per tap?
