## Destruction juice: how many pieces a killed block cracks into.
##
## Read as `Cfg.Juice.<KEY>`, or `Cfg.<KEY>`. `GameRules` preloads this file
## directly for its @export defaults -- see board.gd for why.
##
## Cols/rows are each a random pick in [MIN, MAX] per destroyed block --
## MIN == MAX gives a constant. 2x2 (4 pieces) matches the original fixed
## count; debug-menu adjustable from there.

const FRAGMENT_COLS_MIN: int = 2
const FRAGMENT_COLS_MAX: int = 2
const FRAGMENT_ROWS_MIN: int = 2
const FRAGMENT_ROWS_MAX: int = 2
