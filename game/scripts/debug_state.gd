extends Node
## Debug -- whether debug-mode actions are available during play (autoload).
##
## Lives as an autoload rather than a `Game` field because it should survive a
## scene reload: having to re-enable it after every restart while testing
## would be its own kind of friction. Everything else debug-related (the
## row-shift credit, the "expected" shadow counters, the overlay's own
## touch-shift toggle) belongs to the current run instead and resets with it
## -- see `Game` and `scripts/ui/debug_overlay.gd`.
##
## Both flags stay false outside a Debug build (see Build.shows_debug_panel):
## the setters drop any attempt to turn them on, so hiding the menu isn't the
## only thing standing between a release player and the debug tools.

signal enabled_changed(value: bool)

var enabled: bool = false:
	set(value):
		value = value and Build.shows_debug_panel()
		if enabled == value:
			return
		enabled = value
		enabled_changed.emit(value)

## When true, GridManager.advance() destroys a Block that would land in the
## death row instead of reporting a loss -- a safety net for testing rounds
## deep into a run without actually dying. Independent of `enabled`: it's a
## debug-menu toggle either way, but doesn't need the full debug feature set
## switched on to make sense on its own.
var invincible: bool = false:
	set(value):
		invincible = value and Build.shows_debug_panel()

## When true, the whole screen renders in grayscale (luminance only) -- the
## colour-blind / value check from playtest 10/01. Two colours that look the
## same here can only be told apart by hue. Session-only like the rest.
var grayscale: bool = false:
	set(value):
		grayscale = value and Build.shows_debug_panel()
		if grayscale and _grayscale_layer == null:
			_grayscale_layer = _make_grayscale_layer()
			add_child(_grayscale_layer)
		if _grayscale_layer != null:
			_grayscale_layer.visible = grayscale

## Above every game and menu layer, so it filters the whole frame.
const GRAYSCALE_LAYER := 128
const GRAYSCALE_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	COLOR = vec4(vec3(dot(c, vec3(0.2126, 0.7152, 0.0722))), 1.0);
}
"""

var _grayscale_layer: CanvasLayer

func _make_grayscale_layer() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = GRAYSCALE_LAYER
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = GRAYSCALE_SHADER
	rect.material = mat
	layer.add_child(rect)
	return layer
