class_name HuntBoard
extends Control
## The dojo (placeholder hub): a Hunt tab (biome / hunt selection from BiomeDefinition data) and,
## from Phase 7, a Forge tab (ForgePanel) to craft and equip gear from hunt materials.

@export var biomes: Array[BiomeDefinition] = []

## Display names for material ids shown on the board (data, not code).
@export var known_items: Array[ItemDefinition] = []

## Recipes and item names for the forge.
@export var crafting: CraftingCatalog

var _start_buttons: Dictionary = {}  # hunt id -> Button
var materials_label: Label
var forge: ForgePanel
var _hunt_page: Control
var _gear_label: Label
var _tab_hunt: Button
var _tab_forge: Button


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
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	col.add_child(header)
	var title := UiStyle.label("I want to be NINJA  ·  Dojo", 40)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_tab_hunt = UiStyle.button("Hunt board")
	_tab_hunt.custom_minimum_size = Vector2(200, UiStyle.BUTTON_HEIGHT)
	_tab_hunt.pressed.connect(show_tab.bind("hunt"))
	header.add_child(_tab_hunt)
	_tab_forge = UiStyle.button("Forge", UiStyle.WARNING)
	_tab_forge.custom_minimum_size = Vector2(200, UiStyle.BUTTON_HEIGHT)
	_tab_forge.pressed.connect(show_tab.bind("forge"))
	header.add_child(_tab_forge)
	_gear_label = UiStyle.label("", 17, UiStyle.SPIRIT)
	col.add_child(_gear_label)
	_hunt_page = VBoxContainer.new()
	_hunt_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(_hunt_page as VBoxContainer).add_theme_constant_override("separation", 12)
	col.add_child(_hunt_page)
	if crafting:
		forge = ForgePanel.new()
		forge.size_flags_vertical = Control.SIZE_EXPAND_FILL
		forge.visible = false
		col.add_child(forge)
		forge.setup(crafting)
		forge.forged.connect(func(_g: GearDefinition) -> void: _refresh_summary())
		forge.equipped.connect(func(_g: GearDefinition) -> void: _refresh_summary())
	else:
		_tab_forge.visible = false
	var page := _hunt_page
	page.add_child(UiStyle.label("Choose a jungle and a beast. You have 45 minutes to reach its arena.", 20, UiStyle.MUTED))
	materials_label = UiStyle.label(_materials_text(), 18, UiStyle.WARNING)
	page.add_child(materials_label)
	_refresh_summary()
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
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


## Switch between the "hunt" and "forge" tabs.
func show_tab(tab: String) -> void:
	_hunt_page.visible = tab == "hunt"
	if forge:
		forge.visible = tab == "forge"
		if forge.visible:
			forge.refresh()
	materials_label.text = _materials_text()


func _refresh_summary() -> void:
	if materials_label:
		materials_label.text = _materials_text()
	if crafting == null:
		_gear_label.text = ""
		return
	var names: PackedStringArray = []
	for g in Forge.equipped_gear(PlayerProfile.load_profile(), crafting):
		names.append("%s: %s" % [GearDefinition.slot_name(g.slot), g.display_name])
	_gear_label.text = "Equipped: " + (",  ".join(names) if not names.is_empty() else "starter blades, no armor, no charm")


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
