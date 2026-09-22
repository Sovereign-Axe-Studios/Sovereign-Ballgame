## Board layout: the playfield rectangle in screen pixels.
##
## Read as `Cfg.Board.<KEY>`, or `Cfg.<KEY>` -- `cfg.gd` re-exports every
## constant flat. `GameRules` (the mod seam, docs/ROADMAP.md) preloads this
## file directly for its @export defaults rather than going through the `Cfg`
## autoload: a Resource's exports must resolve even when the editor
## instantiates one outside of a running game, before any autoload exists.

const GRID_WIDTH: int = 7          ## Columns in the playfield.
const GRID_HEIGHT: int = 7         ## Rows total, including spawn row (0) and death row (GRID_HEIGHT - 1).
const SIDE_MARGIN: float = 40.0    ## Gap between screen edge and the inner face of the side walls.
const GRID_TOP: float = 280.0      ## Y of the ceiling, i.e. the top of row 0.
const FLOOR_Y: float = 1820.0      ## Y of the floor line. A ball crossing this is out for the round.
const SHOOTER_HEIGHT: float = 70.0 ## How far above the floor the shooter sits.
