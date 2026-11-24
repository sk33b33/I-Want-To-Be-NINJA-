class_name HuntBoard
extends Control
## The dojo (placeholder hub): a Hunt tab (biome / hunt selection from BiomeDefinition data) and,
## from Phase 7, a Forge tab (ForgePanel) to craft and equip gear from hunt materials.

@export var biomes: Array[BiomeDefinition] = []

## Display names for material ids shown on the board (data, not code).
@export var known_items: Array[ItemDefinition] = []

## Recipes and item names for the forge.
@export var crafting: CraftingCatalog

## Tab to show when the board opens (set before reloading it).
static var open_tab_on_ready: String = ""

var _start_buttons: Dictionary = {}  # hunt id -> Button
var materials_label: Label
var forge: ForgePanel
var _hunt_page: Control
var _gear_label: Label
var _tab_hunt: Button
var _tab_forge: Button
var _tab_settings: Button
var settings: SettingsPanel
var controls: ControlsPanel
var benchmark_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameSettings.ensure_loaded()  # Applies saved readability options to the warning materials.
	if get_tree().current_scene == self:  # Booted as the game (not in a test / benchmark).
		CrashReport.begin_session(get_tree())
	_build()
	if CrashReport.previous_crashed:
		_show_crash_report()


## After a crash: show the end of the previous session's log so the owner can send it.
func _show_crash_report() -> void:
	var overlay := Control.new()
	overlay.name = "CrashReport"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel := UiStyle.panel()
	panel.name = "CrashReportPanel"
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	col.add_child(UiStyle.label("The game closed unexpectedly last time.", 26, UiStyle.WARNING))
	col.add_child(UiStyle.label("Please copy this report and send it to the developer.", 17, UiStyle.MUTED))
	var text := TextEdit.new()
	text.text = CrashReport.previous_log_tail
	text.editable = false
	text.custom_minimum_size = Vector2(900, 320)
	text.add_theme_font_size_override("font_size", 13)
	col.add_child(text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var copy := UiStyle.button("Copy report")
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(CrashReport.previous_log_tail)
		copy.text = "Copied")
	row.add_child(copy)
	var close := UiStyle.button("Close", UiStyle.MUTED)
	close.pressed.connect(func() -> void:
		CrashReport.dismiss()
		overlay.queue_free())
	row.add_child(close)
	col.add_child(row)
	overlay.add_child(UiStyle.dim_backdrop(0.7))
	overlay.add_child(UiStyle.centered(panel))
	add_child(overlay)
	copy.grab_focus.call_deferred()


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
	_tab_settings = UiStyle.button("Settings", UiStyle.MUTED)
	_tab_settings.custom_minimum_size = Vector2(200, UiStyle.BUTTON_HEIGHT)
	_tab_settings.pressed.connect(show_tab.bind("settings"))
	header.add_child(_tab_settings)
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
	var settings_scroll := ScrollContainer.new()
	settings_scroll.name = "SettingsPage"
	settings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	settings_scroll.visible = false
	col.add_child(settings_scroll)
	var settings_col := VBoxContainer.new()
	settings_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_col.add_theme_constant_override("separation", 12)
	settings_scroll.add_child(settings_col)
	settings = SettingsPanel.new(true)
	settings.benchmark_requested.connect(func() -> void: BenchmarkRunner.start(get_tree()))
	settings.unlock_changed.connect(func() -> void:
		# Rebuild the board so the jungle cards show the new state; come back to this tab.
		HuntBoard.open_tab_on_ready = "settings"
		SceneFlow.go_to_hunt_board(get_tree()))
	settings_col.add_child(settings)
	controls = ControlsPanel.new()
	settings_col.add_child(controls)
	benchmark_label = UiStyle.label("", 15, UiStyle.MUTED)
	benchmark_label.text = BenchmarkRunner.format_results(BenchmarkRunner.last_results, QualityProfile.tier()) \
			if not BenchmarkRunner.last_results.is_empty() else "No benchmark run yet. Results are also saved to benchmark.txt."
	settings_col.add_child(benchmark_label)
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
		if first == null and _start_buttons.has(biome.hunts[0].id if not biome.hunts.is_empty() else &""):
			first = _start_buttons.get(biome.hunts[0].id)
	if open_tab_on_ready != "":
		show_tab.call_deferred(open_tab_on_ready)
		open_tab_on_ready = ""
	elif not BenchmarkRunner.last_results.is_empty() and BenchmarkRunner.show_results_once:
		BenchmarkRunner.show_results_once = false
		show_tab.call_deferred("settings")
	elif first:
		first.grab_focus.call_deferred()


## Switch between the "hunt" and "forge" tabs.
func show_tab(tab: String) -> void:
	_hunt_page.visible = tab == "hunt"
	settings.get_parent().get_parent().visible = tab == "settings"
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


## Open on the board: content exists (unlocked) and its prerequisite hunt is done.
## `-- --unlock-all` opens everything for testing.
static func is_open(biome: BiomeDefinition, profile: PlayerProfile) -> bool:
	if not biome.unlocked:
		return false
	if "--unlock-all" in OS.get_cmdline_user_args() or biome.requires_hunt == &"" or GameSettings.get_unlock_all():
		return true
	return int(profile.hunts_completed.get(String(biome.requires_hunt), 0)) > 0


## Phase 13: a hunt inside an open jungle may need another hunt first (its second beast).
static func is_hunt_open(biome: BiomeDefinition, hunt: HuntDefinition, profile: PlayerProfile) -> bool:
	if not is_open(biome, profile):
		return false
	if hunt.requires_hunt == &"" or "--unlock-all" in OS.get_cmdline_user_args() or GameSettings.get_unlock_all():
		return true
	return int(profile.hunts_completed.get(String(hunt.requires_hunt), 0)) > 0


func _hunt_name(id: StringName) -> String:
	for b in biomes:
		for h in b.hunts:
			if h.id == id:
				return h.beast_name
	return String(id).capitalize()


func _biome_card(biome: BiomeDefinition) -> Control:
	var open := is_open(biome, PlayerProfile.load_profile())
	var accent := biome.accent if open else Color(0.35, 0.35, 0.35)
	var card := UiStyle.panel(Color(0.04, 0.05, 0.055, 0.95), accent * Color(1, 1, 1, 0.6))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)
	col.add_child(UiStyle.label(biome.display_name, 30, accent))
	col.add_child(UiStyle.label(biome.mood, 18, UiStyle.MUTED))
	var profile := PlayerProfile.load_profile()
	var secrets := SecretSet.for_biome(biome.id)
	if secrets:  # Phase 13: exploration progress per jungle.
		var done := secrets.is_complete(profile)
		col.add_child(UiStyle.label("Spirit shrines %d / %d%s" % [secrets.found_count(profile), secrets.secrets.size(),
				"  ·  %s" % secrets.blessing_name if done else ""], 18, Color(0.6, 0.95, 1.0) if done else UiStyle.MUTED))
	for hunt in biome.hunts:
		var hunt_open := open and is_hunt_open(biome, hunt, profile)
		col.add_child(UiStyle.label(hunt.full_name(), 22, UiStyle.BONE if hunt_open else UiStyle.MUTED))
		col.add_child(UiStyle.label("Element: %s   Weak to: %s" % [hunt.element, hunt.weakness], 18, UiStyle.MUTED))
		if hunt_open:
			col.add_child(UiStyle.label(hunt.description, 17, UiStyle.MUTED))
			var minutes := int((hunt.config.duration_seconds if hunt.config else ExpeditionConfig.MIN_DURATION_SECONDS) / 60.0)
			var b := UiStyle.button("Begin expedition  (%d:00)" % minutes, accent)
			b.pressed.connect(begin.bind(biome, hunt))
			col.add_child(b)
			_start_buttons[hunt.id] = b
		elif open:
			var lock := UiStyle.button("Locked — defeat %s first" % _hunt_name(hunt.requires_hunt), accent)
			lock.disabled = true
			col.add_child(lock)
	if not open:
		var note := biome.locked_note
		if biome.unlocked and biome.requires_hunt != &"":
			note = "defeat %s to unlock" % String(biome.requires_hunt).capitalize()
		var locked := UiStyle.button("Locked — %s" % note, accent)
		locked.disabled = true
		col.add_child(locked)
	return card
