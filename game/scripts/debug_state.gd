extends Node
## Debug -- whether debug-mode actions are available during play (autoload).
##
## Lives as an autoload rather than a `Game` field because it should survive a
## scene reload: having to re-enable it after every restart while testing
## would be its own kind of friction. Everything else debug-related (the
## row-shift credit, the "expected" shadow counters, the overlay's own
## touch-shift toggle) belongs to the current run instead and resets with it
## -- see `Game` and `scripts/ui/debug_overlay.gd`.

signal enabled_changed(value: bool)

var enabled: bool = false:
	set(value):
		if enabled == value:
			return
		enabled = value
		enabled_changed.emit(value)

## When true, GridManager.advance() destroys a Block that would land in the
## death row instead of reporting a loss -- a safety net for testing rounds
## deep into a run without actually dying. Independent of `enabled`: it's a
## debug-menu toggle either way, but doesn't need the full debug feature set
## switched on to make sense on its own.
var invincible: bool = false
