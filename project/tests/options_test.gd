extends TestCase
## Phase 12 options: control remapping (keyboard/mouse + gamepad, swaps, persistence, reset),
## difficulty presets (never touch the 45:00 countdown), and the touch button size.

const SETTINGS := "user://test_settings_phase12.cfg"


func _fresh() -> void:
	GameSettings.path = SETTINGS
	if FileAccess.file_exists(SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	GameSettings.load_settings()
	PlayerProfile.path = "user://test_profile_phase12_options.json"


func _done() -> void:
	InputRemap.reset_to_defaults(false)
	GameSettings.difficulty = "normal"
	GameSettings.touch_scale = 1.0
	GameSettings.path = GameSettings.DEFAULT_PATH
	GameSettings.load_settings()
	PlayerProfile.path = PlayerProfile.DEFAULT_PATH


func _key(code: Key) -> InputEventKey:
	var k := InputEventKey.new()
	k.physical_keycode = code
	k.pressed = true
	return k


func _pad(button: JoyButton) -> InputEventJoypadButton:
	var b := InputEventJoypadButton.new()
	b.button_index = button
	b.pressed = true
	return b


# ---------------------------------------------------------------- remapping

func test_rebinding_jump_changes_the_action_and_keeps_the_gamepad() -> void:
	_fresh()
	InputRemap.rebind(&"jump", _key(KEY_K))
	check(InputRemap.describe(InputRemap.binding(&"jump", InputRemap.KEYBOARD)) == "K", "jump is K")
	check(InputRemap.binding(&"jump", InputRemap.GAMEPAD) is InputEventJoypadButton, "gamepad binding untouched")
	var space := _key(KEY_SPACE)
	check(not InputMap.event_is_action(space, &"jump"), "Space no longer jumps")
	check(InputMap.event_is_action(_key(KEY_K), &"jump"), "K jumps")
	_done()


func test_taking_a_used_key_swaps_the_two_actions() -> void:
	_fresh()
	var swapped := InputRemap.rebind(&"jump", _key(KEY_C))  # C is Roll.
	check(swapped == &"dodge", "reported the swap (%s)" % swapped)
	check(InputMap.event_is_action(_key(KEY_SPACE), &"dodge"), "Roll took Space")
	check(InputMap.event_is_action(_key(KEY_C), &"jump") and not InputMap.event_is_action(_key(KEY_C), &"dodge"), "C only jumps")
	for action in InputRemap.ACTIONS:
		check(InputRemap.binding(action, InputRemap.KEYBOARD) != null and InputRemap.binding(action, InputRemap.GAMEPAD) != null,
				"%s still has both bindings" % action)
	_done()


func test_movement_rebind_keeps_the_arrow_keys() -> void:
	_fresh()
	InputRemap.rebind(&"move_forward", _key(KEY_I))
	check(InputMap.event_is_action(_key(KEY_I), &"move_forward"), "I moves forward")
	check(InputMap.event_is_action(_key(KEY_UP), &"move_forward"), "Up arrow still moves forward")
	check(not InputMap.event_is_action(_key(KEY_W), &"move_forward"), "W freed")
	_done()


func test_bindings_survive_a_restart_and_reset_restores_defaults() -> void:
	_fresh()
	InputRemap.rebind(&"attack_heavy", _key(KEY_E))
	InputRemap.rebind(&"skill", _pad(JOY_BUTTON_LEFT_SHOULDER))
	GameSettings.save_settings()
	InputMap.load_from_project_settings()  # "Restart": defaults only...
	GameSettings.load_settings()            # ...then the saved settings.
	check(InputMap.event_is_action(_key(KEY_E), &"attack_heavy"), "keyboard rebind restored")
	check(InputMap.event_is_action(_pad(JOY_BUTTON_LEFT_SHOULDER), &"skill"), "gamepad rebind restored")
	InputRemap.reset_to_defaults()
	check(not InputMap.event_is_action(_key(KEY_E), &"attack_heavy") and InputRemap.is_default(), "defaults back")
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	check(not cfg.has_section("remap"), "reset saved")
	_done()


func test_controls_panel_rebinds_from_the_next_press() -> void:
	_fresh()
	var panel := ControlsPanel.new()
	add_node(panel)
	await process_frames(2)
	panel.listen(&"lock_on", InputRemap.GAMEPAD)
	check(not panel.capture(_key(KEY_T)), "a key is ignored while waiting for a gamepad button")
	var touch := InputEventMouseButton.new()
	touch.button_index = MOUSE_BUTTON_LEFT
	touch.pressed = true
	touch.device = InputEvent.DEVICE_ID_EMULATION
	panel.listen(&"lock_on", InputRemap.KEYBOARD)
	check(not panel.capture(touch), "a screen touch is not a mouse click")
	panel.listen(&"lock_on", InputRemap.GAMEPAD)
	check(panel.capture(_pad(JOY_BUTTON_Y)), "gamepad button taken")
	check((panel.buttons["lock_on/pad"] as Button).text.ends_with("Y"), "row shows Y")
	check(InputMap.event_is_action(_pad(JOY_BUTTON_Y), &"lock_on"), "Y locks on")
	_done()


func test_corrupt_remap_entry_never_leaves_an_action_unbound() -> void:
	_fresh()
	var f := FileAccess.open(SETTINGS, FileAccess.WRITE)
	f.store_string('[remap]\njump=[{"t": "bogus"}]\npause="nonsense"\n')
	f.close()
	GameSettings.load_settings()
	check(InputMap.event_is_action(_key(KEY_SPACE), &"jump"), "jump keeps its default")
	check(InputMap.event_is_action(_key(KEY_ESCAPE), &"pause"), "pause keeps its default")
	_done()


# ---------------------------------------------------------------- difficulty

func _start(difficulty: String) -> Node:
	GameSettings.set_difficulty(difficulty)
	return instantiate("res://scenes/main/main.tscn")


func test_difficulty_changes_damage_boss_health_and_warnings_but_never_the_timer() -> void:
	_fresh()
	var results := {}
	for d in ["easy", "normal", "hard"]:
		var main := _start(d)
		await physics_frames(5)
		var m := main.get_node("Expedition") as ExpeditionManager
		var p := main.get_node("Player") as PlayerController
		var boss := main.get_node("Level/Boss") as BossController
		var info := DamageInfo.new()
		info.amount = 10.0
		p.combat.health.apply_damage(info)
		results[d] = {"taken": p.combat.health.max_health - p.combat.health.current, "boss": boss.get_health().max_health,
				"tele": boss.telegraph_seconds(boss.definition.attacks[0]), "timer": m.timer.duration}
		check(m.timer.duration >= 2700.0, "%s keeps the 45:00 countdown (%.0f)" % [d, m.timer.duration])
		main.free()
		_nodes.erase(main)
	check(results["easy"]["taken"] < results["normal"]["taken"] and results["normal"]["taken"] < results["hard"]["taken"], "damage taken rises with difficulty")
	check(results["easy"]["boss"] < results["normal"]["boss"] and results["normal"]["boss"] < results["hard"]["boss"], "boss health rises with difficulty")
	check(results["easy"]["tele"] > results["normal"]["tele"], "easy warns longer")
	check(results["hard"]["tele"] >= results["normal"]["tele"], "hard never shortens the warning")
	check_near(results["normal"]["boss"], (load("res://data/bosses/kurogale.tres") as BossDefinition).max_health, 0.01, "normal = the data")
	_done()


func test_difficulty_files_never_lower_warnings() -> void:
	for d in ["easy", "normal", "hard"]:
		var p := load("res://data/difficulty/%s.tres" % d) as DifficultyPreset
		check(p.telegraph_multiplier >= 1.0, "%s warnings >= the designed time" % d)
		check(not "timer" in str(p.get_property_list().map(func(x: Dictionary) -> String: return x["name"])), "%s has no timer setting" % d)


# ---------------------------------------------------------------- touch

func test_touch_buttons_grow_with_the_size_setting_and_stay_on_screen() -> void:
	_fresh()
	var tc := TouchControls.new()
	tc.force_visible = true
	add_node(tc)
	tc.size = Vector2(1280, 720)
	await process_frames(2)
	var small := tc.call("_button_radius", tc.get("_buttons")[0]) as float
	GameSettings.set_touch_scale(1.4)
	var big := tc.call("_button_radius", tc.get("_buttons")[0]) as float
	check(big > small * 1.3, "bigger buttons (%.0f -> %.0f px)" % [small, big])
	for b: Dictionary in tc.get("_buttons"):
		var c := tc.call("_button_center", b) as Vector2
		var r := tc.call("_button_radius", b) as float
		check(c.x - r >= 0.0 and c.y - r >= 0.0 and c.x + r <= 1280.0 and c.y + r <= 720.0, "%s fits on screen at the largest size" % b["label"])
	_done()
