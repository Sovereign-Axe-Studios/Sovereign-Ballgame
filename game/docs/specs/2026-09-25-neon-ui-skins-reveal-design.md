# Neon UI, skins pack, board events, Nomai reveal: design

2026-09-25. Status: built 2026-09-26 (see HANDOFF §16 for what shipped).

Four parts, built in this order, each playable on its own:

1. **Neon geometric UI.** One visual language for every menu, plus an
   animated geometric title screen.
2. **Skins pack + board events.** Drawn ball and background skins, and
   backgrounds that react to "board cleared" and "new ball".
3. **Asset Viewer.** Live previews of every skin, with buttons that fire the
   background reactions.
4. **Nomai reveal.** The Outer Wilds unlock pop-up.

Fixed separately (already done, not in this spec): the collapsing pause-page
width, the ball-return dropdown size, Line up, Snowball's power label and
growth, and the Debug Menu's Outer Wilds reset.

---

## 1. Neon geometric UI (direction A)

### Look
- Near-black violet ground (`#07060f`), cyan `#4ff0ff` and magenta `#ff4fd8`
  accents, white text for selected items and soft lilac for the rest.
- Buttons are slanted parallelograms (`StyleBoxFlat.skew`) with a thin neon
  border and a soft glow (`shadow_color` / `shadow_size`). Hover and
  selected get a brighter border, a tinted fill, and a bigger glow.
- Headers are caps with a short magenta underline bar.
- Panels have a dark translucent fill, a cyan border, and a glow.

### `NeonUI` (`scripts/ui/neon_ui.gd`)
Replaces `ArcadeUI`, which is removed, and its call sites move over. Static
builders: `button`, `chip`, `toggle`, `header`, `label`, `panel_style`,
`slider`, `option_button` (styles the popup too), and `page(title)` (a
centred scroll column that fills its width: the fix from the layout bug is
built in, so it can't regress).

### `GeometricBackdrop` (`scripts/vfx/geometric_backdrop.gd`)
- Drifting, slowly rotating wireframe polygons (3-8 sides) in cyan and
  magenta, at three depths. A gentle parallax follows the mouse.
- Used by: the title, Mode Select, the Asset Viewer, the pause menu (behind
  its dim, faint), and the **Geometric** background skin, which is the same
  class.

### Screens
- **Title:** `GeometricBackdrop` plus a sparse starfield (the constellation
  still hides among the stars), a neon title, and a centred button column:
  Quick Play, Play, **Skins** (new), Settings, Game States, Asset Viewer.
- **Pause menu:** a centred neon panel, not top-left. Root, Settings, Skins
  and Debug pages all use `NeonUI.page`.
- **Shared panels (a targeted cleanup):** the Settings controls exist twice
  today and the Skins pickers three times (pause, Asset Viewer, and now the
  title). Extract **`SettingsPanel`** and **`SkinsPanel`**
  (`scripts/ui/settings_panel.gd`, `skins_panel.gd`) and use them
  everywhere.
- **Mode Select, the ? detail panel, the unlock reveal:** all restyled with
  `NeonUI`.

---

## 2. Skins pack + board events

### Architecture: one file per skin, like mods
- `BallLook` (`scripts/skins/ball_look.gd`), the base class:
  - `display_name`, `color` (the accent for menus and the launcher),
    `locked_by`;
  - `draw(canvas, radius, spin, t)`.
  - The default draws a flat disc with a highlight (the basic colours).
- `Ball` tracks `spin` from the distance travelled / radius, so looks roll
  with motion. `FallingBall`, `PreviewDraw.ball` and the swatches all call
  the same `draw`.
- `AnimatedBackground` (`scripts/skins/animated_background.gd`), a `Node2D`
  base:
  - `on_board_cleared(pos)` and `on_new_ball(pos)`, which do nothing by
    default;
  - `show_behind_parent`, and fills the viewport.
  - `EndTimesBackground` moves onto it.
- Files: `scripts/skins/balls/*.gd`, `scripts/skins/backgrounds/*.gd`.
  `Skins` registers them with explicit preload lists (the same pattern as
  `Cfg.MODS`). The selection stays session-only; `locked_by` works as now.

### Balls
- **Basic colours** (10 chips): red, orange, yellow, green, cyan, blue,
  purple, pink, white (the current "Classic"), and charcoal. These replace
  Classic, Neon Cyan, Magma and Violet.
- **Drawn looks:**
  - Beach ball: six panels that spin.
  - Planet: a banded sphere with a tilted ring.
  - Disco ball: glinting facets.
  - Marble: a glass sphere with an inner swirl.
  - 8-ball: the number disc rolls.
  - Golf ball (v2): a hex dimple grid with shading, and it rolls.
  - Basketball (v2): a pebbled texture with four seams.
  - Meteor: cratered rock with a fire trail and embers.
  - Snowball: packed snow that sparkles and sheds flakes.
  - Pearl: an iridescent sheen that shifts as it moves.
  - Apple: red/green shading, and a stem with a wobbling leaf.
- **Interloper** (locked) moves onto `BallLook`; its trail becomes part of
  its own `draw` plus history.

### Backgrounds
The existing flat Void, Indigo Night, Deep Forest and Crimson Dusk stay (no
reactions). New animated ones:

| Background | Idle | Board cleared | New ball |
|---|---|---|---|
| Synthwave | Striped sun, scrolling horizon grid | The sun flares, and a pulse races down the grid | A neon ring ripples along the horizon |
| Arcade | Scanlines, drifting pixel invaders | Every invader bursts into pixels, and "STAGE CLEAR" blinks | One invader flashes "1UP" and zips off |
| Mosaic | Tiles shimmer in waves | A colour wave radiates from the last block destroyed | A tile ripple spreads from the landing spot |
| Geometric | `GeometricBackdrop` | Every polygon bursts outward, then re-forms | A new polygon spins up at the landing spot |
| Aurora | Tall hanging curtains with vertical rays, filling most of the screen | The curtains surge bright and shift hue | One ribbon brightens |
| Lava lamp | Blobs rise and merge | Every blob pops, then they re-bubble from the bottom | A new blob rises |
| End Times (locked) | As now | An instant big bang | One star goes supernova |

### Events
- **Board cleared:**
  - When a block is destroyed and `grid.block_count() == 0`, `Game` emits
    `board_cleared(pos)` with the last block's position.
  - It fires once per clear, and re-arms once blocks exist again.
  - This also resolves the HANDOFF loose end ("no board cleared handling").
- **New ball:** `Game._on_powerup_ball_landed` emits `new_ball(pos)`.
- `Game` forwards both to the active `AnimatedBackground`.

---

## 3. Asset Viewer

- The Skins tab uses `SkinsPanel`, with live previews:
  - a ball rolling across a strip for the selected ball look;
  - a live 540×500 view of the selected background (the real node,
    clipped).
- Under the background preview: **Board cleared** and **New ball** buttons
  that call the preview node's hooks, at the centre and at a random point.
- Locked skins show as `???` here too.

---

## 4. Nomai reveal (the Outer Wilds unlock pop-up)

`OuterWildsReveal` (`scripts/title/outer_wilds_reveal.gd`), a full-screen
overlay that `MainMenu` opens on completion (replacing today's banner). It
takes about 5 seconds, and a click skips to the end state.

1. **0-0.8 s:** the screen dims, and the constellation's lines flare.
2. **0.8-2.8 s:** a glowing Nomai-style spiral of text writes itself
   outward from the centre, a character at a time along an Archimedean
   spiral. The flavour text is original, written in their voice, not
   quoted from the game. Something like: *"You followed the old light
   between the stars and found our mark. What we left waiting is yours
   now. Explore."*
3. **2.8-4.8 s:** five cards flip in one by one (scale-x 0 to 1), each with
   a live preview:
   - the Interloper rolling;
   - the probe cannon firing;
   - End Times, in miniature;
   - the Wormholes sketch;
   - the Time Rewind sketch.
4. **After:** a **Continue** button fades in.

The unlock is saved at the start of the reveal, not the end.

---

## Verification

- `check_mods` as now. A new `check_skins` scene draws every `BallLook`
  (t = 0 and 1) and runs every `AnimatedBackground` for 2 s, firing both
  events.
- Windowed screenshots: the title, the pause menu (each page), Mode Select,
  the Asset Viewer, every background idle and mid-event, and the reveal at
  each stage.
- Headless: the board-cleared event fires exactly once per clear.
- For Theo by eye: animation feel, the mouse parallax, and the reveal
  pacing.
