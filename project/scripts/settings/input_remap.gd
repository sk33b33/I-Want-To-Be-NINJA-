class_name InputRemap
extends RefCounted
## Control remapping (Phase 12). Each action has a *primary* keyboard/mouse binding and a primary
## gamepad binding that the player can change; extra defaults (arrow keys for movement, Q + middle
## mouse for lock-on) stay. Binding a key that another action uses SWAPS the two, so no action is
## ever left without a key. Changes are saved in user://settings.cfg [controls] on top of the
## project defaults; "reset" reloads the defaults. Gameplay still reads actions only.

const ACTIONS: Array[StringName] = [&"move_forward", &"move_back", &"move_left", &"move_right", &"jump",
		&"sprint", &"dodge", &"attack_light", &"attack_heavy", &"skill", &"draw_sword", &"lock_on", &"camera_toggle", &"pause"]
const KEYBOARD := &"kb"
const GAMEPAD := &"pad"
const JOY_BUTTON_NAMES := ["A", "B", "X", "Y", "Back", "Guide", "Start", "Left stick press", "Right stick press",
		"LB", "RB", "D-pad up", "D-pad down", "D-pad left", "D-pad right"]
const JOY_AXIS_NAMES := ["Left stick X", "Left stick Y", "Right stick X", "Right stick Y", "LT", "RT"]

## Actions changed since the defaults (saved).
static var _changed: Dictionary = {}


static func is_kind(e: InputEvent, kind: StringName) -> bool:
	if kind == KEYBOARD:
		return e is InputEventKey or e is InputEventMouseButton
	return e is InputEventJoypadButton or e is InputEventJoypadMotion


## The action's primary binding of a kind (null if none).
static func binding(action: StringName, kind: StringName) -> InputEvent:
	for e in InputMap.action_get_events(action):
		if is_kind(e, kind):
			return e
	return null


## Bind `event` as the action's primary binding of its kind. Returns the action it was taken
## from (now holding this action's old binding), or &"".
static func rebind(action: StringName, event: InputEvent) -> StringName:
	var kind := KEYBOARD if is_kind(event, KEYBOARD) else GAMEPAD
	var clean := _clean(event)
	var old := binding(action, kind)
	var swapped := &""
	for other in ACTIONS:
		if other == action:
			continue
		for e in InputMap.action_get_events(other):
			if same(e, clean):
				_replace(other, e, old)
				swapped = other
				break
		if swapped != &"":
			break
	_replace(action, old, clean)
	return swapped


static func reset_to_defaults(save_now: bool = true) -> void:
	InputMap.load_from_project_settings()
	_changed.clear()
	if save_now:
		GameSettings.save_settings()


static func is_default() -> bool:
	return _changed.is_empty()


static func save_to(cfg: ConfigFile) -> void:
	if cfg.has_section("remap"):
		cfg.erase_section("remap")
	for action: StringName in _changed:
		cfg.set_value("remap", String(action), InputMap.action_get_events(action).map(serialize))


static func load_from(cfg: ConfigFile) -> void:
	InputMap.load_from_project_settings()
	_changed.clear()
	if not cfg.has_section("remap"):
		return
	for key in cfg.get_section_keys("remap"):
		var action := StringName(key)
		if not ACTIONS.has(action) or not InputMap.has_action(action):
			continue
		var list: Variant = cfg.get_value("remap", key, [])
		if not list is Array:
			continue
		var events: Array[InputEvent] = []
		for d: Variant in list:
			var e := deserialize(d)
			if e:
				events.append(e)
		if events.is_empty():
			continue  # Never leave an action unbound because of a bad file.
		InputMap.action_erase_events(action)
		for e in events:
			InputMap.action_add_event(action, e)
		_changed[action] = true


static func serialize(e: InputEvent) -> Dictionary:
	if e is InputEventKey:
		return {"t": "key", "pk": int((e as InputEventKey).physical_keycode), "k": int((e as InputEventKey).keycode)}
	if e is InputEventMouseButton:
		return {"t": "mouse", "b": int((e as InputEventMouseButton).button_index)}
	if e is InputEventJoypadButton:
		return {"t": "joyb", "b": int((e as InputEventJoypadButton).button_index)}
	if e is InputEventJoypadMotion:
		return {"t": "joya", "a": int((e as InputEventJoypadMotion).axis), "v": signf((e as InputEventJoypadMotion).axis_value)}
	return {}


static func deserialize(d: Variant) -> InputEvent:
	if not d is Dictionary:
		return null
	var m := d as Dictionary
	match String(m.get("t", "")):
		"key":
			var k := InputEventKey.new()
			k.physical_keycode = int(m.get("pk", 0)) as Key
			k.keycode = int(m.get("k", 0)) as Key
			return k if k.physical_keycode != KEY_NONE or k.keycode != KEY_NONE else null
		"mouse":
			var b := InputEventMouseButton.new()
			b.button_index = int(m.get("b", 1)) as MouseButton
			return b
		"joyb":
			var j := InputEventJoypadButton.new()
			j.button_index = int(m.get("b", 0)) as JoyButton
			return j
		"joya":
			var a := InputEventJoypadMotion.new()
			a.axis = int(m.get("a", 0)) as JoyAxis
			a.axis_value = 1.0 if float(m.get("v", 1.0)) >= 0.0 else -1.0
			return a
	return null


static func same(a: InputEvent, b: InputEvent) -> bool:
	if a == null or b == null:
		return false
	return serialize(a) == serialize(b) and not serialize(a).is_empty()


## Player-facing name of a binding.
static func describe(e: InputEvent) -> String:
	if e == null:
		return "—"
	if e is InputEventKey:
		var k := e as InputEventKey
		return OS.get_keycode_string(k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode)
	if e is InputEventMouseButton:
		return {1: "Left mouse", 2: "Right mouse", 3: "Middle mouse"}.get(int((e as InputEventMouseButton).button_index), "Mouse %d" % int((e as InputEventMouseButton).button_index))
	if e is InputEventJoypadButton:
		var i := int((e as InputEventJoypadButton).button_index)
		return JOY_BUTTON_NAMES[i] if i < JOY_BUTTON_NAMES.size() else "Button %d" % i
	if e is InputEventJoypadMotion:
		var m := e as InputEventJoypadMotion
		var n: String = JOY_AXIS_NAMES[int(m.axis)] if int(m.axis) < JOY_AXIS_NAMES.size() else "Axis %d" % int(m.axis)
		if int(m.axis) >= 4:
			return n
		return "%s %s" % [n, "+" if m.axis_value > 0.0 else "−"]
	return "?"


## A plain, comparable copy of a pressed event (no modifiers/position/pressure).
static func _clean(e: InputEvent) -> InputEvent:
	return deserialize(serialize(e))


static func _replace(action: StringName, old: InputEvent, new: InputEvent) -> void:
	var events := InputMap.action_get_events(action)
	var out: Array[InputEvent] = []
	var placed := false
	for e in events:
		if old != null and not placed and same(e, old):
			if new:
				out.append(new)
			placed = true
		else:
			out.append(e)
	if not placed and new:
		out.insert(0, new)
	InputMap.action_erase_events(action)
	for e in out:
		InputMap.action_add_event(action, e)
	_changed[action] = true
