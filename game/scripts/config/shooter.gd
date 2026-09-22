## Shooter aim: the clamp and turn speed on the aim line.
##
## Read as `Cfg.Shooter.<KEY>`, or `Cfg.<KEY>`. `GameRules` preloads this file
## directly for its @export defaults -- see board.gd for why. Not to be
## confused with `scripts/shooter.gd`, the `Shooter` gameplay class; this file
## declares no class_name and holds numbers only.

## Aim is clamped to +/- this many degrees off straight up.
const MAX_AIM_DEGREES: float = 78.0
## Degrees per second while an aim key is held.
const AIM_SPEED_DEGREES: float = 90.0
