extends SceneTree
## One-off: adds Phase 4/5 combat input actions and physics layer names to project.godot.
## Usage (repo root): godot --headless --path project -s ../tools/generate_phase4_input.gd


func _initialize() -> void:
	_action("attack_light", [_mouse(MOUSE_BUTTON_LEFT), _joy(JOY_BUTTON_X)])
	_action("attack_heavy", [_mouse(MOUSE_BUTTON_RIGHT), _joy(JOY_BUTTON_Y)])
	_action("dodge", [_key(KEY_C), _joy(JOY_BUTTON_B)])
	_action("lock_on", [_key(KEY_Q), _mouse(MOUSE_BUTTON_MIDDLE), _joy(JOY_BUTTON_RIGHT_STICK)])
	_action("skill", [_key(KEY_F), _joy(JOY_BUTTON_RIGHT_SHOULDER)])  # Phase 5: Ember Talisman
	ProjectSettings.set_setting("layer_names/3d_physics/layer_4", "enemy")
	ProjectSettings.set_setting("layer_names/3d_physics/layer_5", "hitbox")
	ProjectSettings.set_setting("layer_names/3d_physics/layer_6", "hurtbox")
	var err := ProjectSettings.save()
	print("SAVED" if err == OK else "SAVE FAILED %d" % err)
	quit(0)


func _action(name: String, events: Array) -> void:
	ProjectSettings.set_setting("input/" + name, {"deadzone": 0.5, "events": events})


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.device = -1
	e.physical_keycode = code
	return e


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.device = -1
	e.button_index = button
	return e


func _joy(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = -1
	e.button_index = button
	return e
