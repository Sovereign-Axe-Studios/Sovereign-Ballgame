## Wall-corner scatter: keeps a ball from settling into a perfect repeating
## bounce path near a corner.
##
## Read as `Cfg.WallCorners.<KEY>`, or `Cfg.<KEY>`. `GameRules` preloads this
## file directly for its @export defaults -- see board.gd for why.

## Hitting a wall within this many pixels of a corner scatters the bounce a
## little, so balls do not settle into a perfect repeating path.
const CORNER_RADIUS: float = 90.0
## Maximum scatter applied there, in degrees.
const CORNER_JITTER_DEGREES: float = 12.0
