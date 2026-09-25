## Row spawning: how many units a new row gets and how they land on the grid.
##
## Read as `Cfg.Spawning.<KEY>`, or `Cfg.<KEY>`. `GameRules` preloads this file
## directly for its @export defaults -- see board.gd for why.
##
## A row is handed `UNITS_PER_COLUMN * grid_width` units, and every unit is
## worth the round number. So a round-3 row on a width-7 board spends 7 units
## of 3, and every block it makes is a multiple of 3: 3, 6, 9, 12... Density
## mods (Dense, Solid, Boss, Mafia, Pawn wall) move this number.

const UNITS_PER_COLUMN: float = 0.75

## How many columns a new row leaves empty, picked per row from this range.
## At least one, always: a sealed row is a dead round.
const MIN_OPEN_SLOTS: int = 1
const MAX_OPEN_SLOTS: int = 3

## Most units that may stack on a single cell. 0 = no cap. Raised automatically
## if the row's units could not otherwise fit in the cells available.
const MAX_UNITS_PER_CELL: int = 4

## Chance a new row also drops a +1 ball pickup, if an empty column exists.
const PICKUP_CHANCE: float = 1.0
