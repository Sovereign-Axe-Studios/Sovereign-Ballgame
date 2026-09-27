class_name ActiveModsPanel
extends VBoxContainer
## The pause menu's Mods page body: the run's installed mods as tiles, with a
## detail card below. Hovering a tile animates its icon and shows that mod in
## the card -- name, category, description, its live status line (e.g.
## "LIVES 2") and a larger looping sketch. The card rests on the first mod.
##
## Read-only: a run's mods can't change mid-run. `show_mods()` rebuilds the
## tiles from the live mod instances each time the page opens (the pause menu
## is built before Game installs them, and status lines change as you play).

const TILE_SIZE := Vector2(170.0, 190.0)
const ICON_SIZE := 120.0
const DETAIL_ICON := 220.0

var _rules: GameRules
var _tiles: HFlowContainer
var _empty: Label
var _detail: PanelContainer
var _detail_icon: ModPreviewIcon
var _detail_category: Label
var _detail_name: Label
var _detail_desc: Label
var _detail_status: Label

func _init() -> void:
	add_theme_constant_override("separation", 24)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_empty = NeonUI.label("No mods -- stock rules.", NeonUI.LABEL_FONT, NeonUI.TEXT_DIM)
	add_child(_empty)

	_tiles = HFlowContainer.new()
	_tiles.add_theme_constant_override("h_separation", 16)
	_tiles.add_theme_constant_override("v_separation", 16)
	add_child(_tiles)

	_detail = PanelContainer.new()
	var style := NeonUI.panel_style()
	style.set_content_margin_all(24.0)
	_detail.add_theme_stylebox_override("panel", style)
	add_child(_detail)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	_detail.add_child(row)
	_detail_icon = ModPreviewIcon.new()
	_detail_icon.custom_minimum_size = Vector2.ONE * DETAIL_ICON
	_detail_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_detail_icon)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 10)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	_detail_category = NeonUI.label("", 22, NeonUI.TEXT_DIM)
	text.add_child(_detail_category)
	_detail_name = NeonUI.label("", 40, NeonUI.CYAN)
	text.add_child(_detail_name)
	_detail_desc = NeonUI.label("", 26, NeonUI.TEXT)
	text.add_child(_detail_desc)
	_detail_status = NeonUI.label("", 28, NeonUI.MAGENTA)
	text.add_child(_detail_status)

## Rebuild from `rules`' installed mods.
func show_mods(rules: GameRules) -> void:
	_rules = rules
	for child in _tiles.get_children():
		child.queue_free()
	var mods := rules.active_mods()
	_empty.visible = mods.is_empty()
	_tiles.visible = not mods.is_empty()
	_detail.visible = not mods.is_empty()
	for mod in mods:
		_tiles.add_child(_tile(mod))
	if not mods.is_empty():
		_show_detail(mods[0])

func _tile(mod: GameMod) -> Control:
	var tile := PanelContainer.new()
	tile.custom_minimum_size = TILE_SIZE
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.tooltip_text = mod.description
	var normal := NeonUI.box(false, NeonUI.CYAN, 0.0)
	normal.set_content_margin_all(10.0)
	var lit := NeonUI.box(true, NeonUI.CYAN, 0.0)
	lit.set_content_margin_all(10.0)
	tile.add_theme_stylebox_override("panel", normal)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(col)
	var icon := ModPreviewIcon.new(mod)
	icon.custom_minimum_size = Vector2.ONE * ICON_SIZE
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(icon)
	var name_label := NeonUI.label(mod.display_name, 20, NeonUI.TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_label)
	var cat := NeonUI.label(GameMod.category_name(mod.category), 16, NeonUI.TEXT_SOFT)
	cat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(cat)

	tile.mouse_entered.connect(func() -> void:
		icon.playing = true
		tile.add_theme_stylebox_override("panel", lit)
		_show_detail(mod))
	tile.mouse_exited.connect(func() -> void:
		icon.playing = false
		tile.add_theme_stylebox_override("panel", normal))
	return tile

func _show_detail(mod: GameMod) -> void:
	_detail_icon.mod = mod
	_detail_icon.playing = true
	_detail_category.text = GameMod.category_name(mod.category).to_upper()
	_detail_name.text = mod.display_name
	_detail_desc.text = mod.description
	var status := mod.status_text(_rules) if _rules != null else ""
	_detail_status.text = status
	_detail_status.visible = status != ""
