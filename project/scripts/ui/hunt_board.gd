class_name HuntBoard
extends Control
## Biome / hunt selection (Phase 3 stub of the dojo hunt board). One card per biome from
## BiomeDefinition data; unlocked biomes list their hunts with a "Begin expedition" button.

@export var biomes: Array[BiomeDefinition] = []

## Display names for material ids shown on the board (data, not code).
@export var known_items: Array[ItemDefinition] = []

var _start_buttons: Dictionary = {}  # hunt id -> Button
var materials_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()


## Start the given hunt's expedition (also used by tests).
func begin(biome: BiomeDefinition, hunt: HuntDefinition) -> Node:
	return SceneFlow.start_expedition(get_tree(), biome.expedition_scene, hunt)


func get_start_button(hunt_id: StringName) -> Button:
	return _start_buttons.get(hunt_id) as Button


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.035)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	margin.add_child(col)
	col.add_child(UiStyle.label("I want to be NINJA", 46))
	col.add_child(UiStyle.label("Hunt board — choose a jungle and a beast. You have 45 minutes to reach its arena.", 20, UiStyle.MUTED))
	materials_label = UiStyle.label(_materials_text(), 18, UiStyle.WARNING)
	col.add_child(materials_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	var first: Button = null
	for biome in biomes:
		var card := _biome_card(biome)
		grid.add_child(card)
		if first == null and biome.unlocked and not biome.hunts.is_empty():
			first = _start_buttons.get(biome.hunts[0].id)
	if first:
		first.grab_focus.call_deferred()


func _materials_text() -> String:
	var profile := PlayerProfile.load_profile()
	if profile.materials.is_empty():
		return "Materials: none yet — break beast parts to earn them."
	var parts: PackedStringArray = []
	for id in profile.materials:
		var name := String(id)
		for item in known_items:
			if String(item.id) == name:
				name = item.display_name
		parts.append("%s ×%d" % [name, int(profile.materials[id])])
	return "Materials: " + ",  ".join(parts)


func _biome_card(biome: BiomeDefinition) -> Control:
	var accent := biome.accent if biome.unlocked else Color(0.35, 0.35, 0.35)
	var card := UiStyle.panel(Color(0.04, 0.05, 0.055, 0.95), accent * Color(1, 1, 1, 0.6))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)
	col.add_child(UiStyle.label(biome.display_name, 30, accent))
	col.add_child(UiStyle.label(biome.mood, 18, UiStyle.MUTED))
	for hunt in biome.hunts:
		col.add_child(UiStyle.label(hunt.full_name(), 22, UiStyle.BONE if biome.unlocked else UiStyle.MUTED))
		col.add_child(UiStyle.label("Element: %s   Weak to: %s" % [hunt.element, hunt.weakness], 18, UiStyle.MUTED))
		if biome.unlocked:
			col.add_child(UiStyle.label(hunt.description, 17, UiStyle.MUTED))
			var minutes := int((hunt.config.duration_seconds if hunt.config else ExpeditionConfig.MIN_DURATION_SECONDS) / 60.0)
			var b := UiStyle.button("Begin expedition  (%d:00)" % minutes, accent)
			b.pressed.connect(begin.bind(biome, hunt))
			col.add_child(b)
			_start_buttons[hunt.id] = b
	if not biome.unlocked:
		var locked := UiStyle.button("Locked — %s" % biome.locked_note, accent)
		locked.disabled = true
		col.add_child(locked)
	return card
