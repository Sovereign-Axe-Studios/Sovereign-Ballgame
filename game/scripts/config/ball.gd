## Ball feel: speed, damage, fire cadence, and the anti-stall guards.
##
## Read as `Cfg.Ball.<KEY>`, or `Cfg.<KEY>`. `GameRules` preloads this file
## directly for its @export defaults -- see board.gd for why. Not to be
## confused with `scripts/ball.gd`, the `Ball` gameplay class; this file
## declares no class_name and holds numbers only.

const BALL_RADIUS: float = 17.0
const BALL_SPEED: float = 1750.0
const BALL_DAMAGE: int = 1 ## Damage one ball does per block contact.

## Seconds between each ball leaving the shooter.
## NOTE: Theo's spec says "one every second". That reads as a placeholder --
## at round 40 it would be 40 seconds of watching balls queue up. 0.09 is in
## the same neighbourhood as the original game. Turn it up if you disagree.
const BALL_FIRE_INTERVAL: float = 0.09

## Hard stop so a ball trapped in a horizontal groove cannot stall the round.
const BALL_MAX_LIFETIME: float = 18.0

## After a bounce, force at least this much vertical travel (fraction of
## speed). Without it, balls settle into flat left-right loops and never
## come down.
const BALL_MIN_VERTICAL: float = 0.18

## Once the round's first ball lands, the shooter slides to where it landed
## and the rest return there. This is how the original game feels. False =
## fixed shooter.
const BALLS_RETURN_TO_LANDER: bool = true
