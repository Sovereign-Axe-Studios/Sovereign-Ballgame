## Loss condition: which row ends the run.
##
## Read as `Cfg.Loss.<KEY>`, or `Cfg.<KEY>`. `GameRules` preloads this file
## directly for its @export defaults -- see board.gd for why.

## Which row kills you. -1 means "the bottom row" (grid_height - 1).
const DEATH_ROW_OVERRIDE: int = -1
