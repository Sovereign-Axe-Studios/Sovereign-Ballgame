class_name SkinRecord
extends RefCounted
## Shared by every skin: its picker name, and the unlock that gates it.

var skin_name: String = ""
## Unlocks id; empty = always available.
var locked_by: StringName = &""

func is_locked() -> bool:
	return not Unlocks.is_unlocked(locked_by)
