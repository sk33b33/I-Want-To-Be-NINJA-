class_name ControlsPanel
extends VBoxContainer
## Rebind controls (Phase 12): one row per action with its keyboard/mouse and gamepad binding.
## Press a binding, then the new key / mouse button / gamepad button or stick direction.
## Taken bindings are swapped (InputRemap). Touch controls are fixed on-screen buttons (their
## size is a Settings option). Saved at once.

const LABELS := {&"move_forward": "Move forward", &"move_back": "Move back", &"move_left": "Move left",
		&"move_right": "Move right", &"jump": "Jump", &"sprint": "Sprint (tap: roll on keyboard)", &"dodge": "Roll",
		&"attack_light": "Light attack", &"attack_heavy": "Heavy attack", &"skill": "Talisman", &"draw_sword": "Draw / sheathe blades",
		&"lock_on": "Lock on", &"camera_toggle": "Switch camera", &"pause": "Pause"}
## Seconds to wait for the new binding before giving up.
const LISTEN_TIMEOUT := 6.0

var buttons: Dictionary = {}  # "action/kind" -> Button
var status: Label
var listening: Dictionary = {}  # {action, kind} while waiting for input
var _listen_t: float = 0.0


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	add_child(UiStyle.label("Controls", 26))
	status = UiStyle.label("Choose a binding, then press the new key or button.", 15, UiStyle.MUTED)
	add_child(status)
	for action in InputRemap.ACTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var l := UiStyle.label(LABELS.get(action, String(action)), 17)
		l.custom_minimum_size.x = 300
		row.add_child(l)
		for kind in [InputRemap.KEYBOARD, InputRemap.GAMEPAD]:
			var b := UiStyle.button("", UiStyle.MUTED)
			b.custom_minimum_size = Vector2(230, 44)
			b.pressed.connect(listen.bind(action, kind))
			row.add_child(b)
			buttons["%s/%s" % [action, kind]] = b
		add_child(row)
	var reset := UiStyle.button("Reset controls to defaults", UiStyle.WARNING)
	reset.pressed.connect(func() -> void:
		InputRemap.reset_to_defaults()
		status.text = "Controls reset to the defaults."
		refresh())
	add_child(reset)
	refresh()


func refresh() -> void:
	for action in InputRemap.ACTIONS:
		for kind in [InputRemap.KEYBOARD, InputRemap.GAMEPAD]:
			var b := buttons["%s/%s" % [action, kind]] as Button
			b.text = ("Keys: " if kind == InputRemap.KEYBOARD else "Pad: ") + InputRemap.describe(InputRemap.binding(action, kind))


## Start waiting for the next key/button for this action (kind = &"kb" or &"pad").
func listen(action: StringName, kind: StringName) -> void:
	listening = {"action": action, "kind": kind}
	_listen_t = 0.0
	(buttons["%s/%s" % [action, kind]] as Button).text = "Press a %s…" % ("key or mouse button" if kind == InputRemap.KEYBOARD else "gamepad button")
	status.text = "Waiting for %s… (%d s)" % [LABELS.get(action, action), int(LISTEN_TIMEOUT)]


## Feed an input event while listening (also called by tests). Returns true if it was used.
func capture(event: InputEvent) -> bool:
	if listening.is_empty() or not event.is_pressed() or event.is_echo():
		return false
	var kind: StringName = listening["kind"]
	if not InputRemap.is_kind(event, kind):
		return false
	if event is InputEventMouseButton and (event as InputEventMouseButton).device == InputEvent.DEVICE_ID_EMULATION:
		return false  # A touch, not a mouse.
	if event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) < 0.6:
		return false  # Stick resting / drifting.
	var action: StringName = listening["action"]
	listening = {}
	var swapped := InputRemap.rebind(action, event)
	GameSettings.save_settings()
	status.text = "%s: %s" % [LABELS.get(action, action), InputRemap.describe(InputRemap.binding(action, kind))]
	if swapped != &"":
		status.text += "  (swapped with %s)" % LABELS.get(swapped, swapped)
	refresh()
	return true


func _input(event: InputEvent) -> void:
	if capture(event):
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if listening.is_empty():
		return
	_listen_t += delta
	if _listen_t >= LISTEN_TIMEOUT:
		listening = {}
		status.text = "No input — binding unchanged."
		refresh()
