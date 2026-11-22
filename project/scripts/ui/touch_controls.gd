class_name TouchControls
extends Control
## On-screen phone controls: a floating virtual joystick on the left side of the screen,
## a drag-to-look area on the right, and Jump / Sprint / Camera buttons.
## Sends the same input actions as keyboard/gamepad (as InputEventAction), so gameplay code
## never needs to know about touch. Camera look is emitted as `look_dragged`.
##
## Shown automatically on touchscreen devices. On desktop, run with `-- --touch` to test it
## with the mouse (touch is emulated from the mouse in that mode).

signal look_dragged(relative: Vector2)

## Fraction of the screen width (from the left) that starts the joystick.
@export_range(0.1, 0.9) var joystick_zone: float = 0.4
## Joystick radius as a fraction of the screen's shorter side.
@export var joystick_radius_ratio: float = 0.11
## Button radius as a fraction of the screen's shorter side.
@export var button_radius_ratio: float = 0.075
@export var force_visible: bool = false

const MOVE_ACTIONS := ["move_left", "move_right", "move_forward", "move_back"]

var _buttons: Array[Dictionary] = [
	# Bottom-right combat cluster (anchors in button-radius units from the bottom-right corner).
	{"action": "attack_light", "label": "ATK", "anchor": Vector2(-2.0, -2.0), "scale": 1.35, "touch": -1},
	{"action": "attack_heavy", "label": "HVY", "anchor": Vector2(-4.9, -1.5), "scale": 1.0, "touch": -1},
	{"action": "jump", "label": "JUMP", "anchor": Vector2(-1.7, -5.2), "scale": 1.05, "touch": -1},
	{"action": "dodge", "label": "ROLL", "anchor": Vector2(-4.6, -4.2), "scale": 0.95, "touch": -1},
	{"action": "sprint", "label": "DASH", "anchor": Vector2(-7.5, -2.7), "scale": 0.85, "touch": -1},
	{"action": "lock_on", "label": "LOCK", "anchor": Vector2(-1.4, -7.9), "scale": 0.75, "touch": -1},
	{"action": "skill", "label": "CHARM", "anchor": Vector2(-4.0, -6.9), "scale": 0.8, "touch": -1},
	# Top-right system buttons.
	{"action": "camera_toggle", "label": "CAM", "anchor": Vector2(-3.2, 1.2), "scale": 0.6, "touch": -1, "top": true},
	{"action": "pause", "label": "II", "anchor": Vector2(-1.2, 1.2), "scale": 0.6, "touch": -1, "top": true},
]

var _stick_touch: int = -1
var _stick_center: Vector2
var _stick_knob: Vector2
var _look_touches: Dictionary = {}  # touch index -> true


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var forced := force_visible or "--touch" in OS.get_cmdline_user_args()
	if forced:
		Input.emulate_touch_from_mouse = true
	visible = forced or DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	set_process_input(visible)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_on_touch_down(touch.index, touch.position)
		else:
			_on_touch_up(touch.index)
		queue_redraw()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _stick_touch:
			_update_stick(drag.position)
			queue_redraw()
		elif _look_touches.has(drag.index):
			look_dragged.emit(drag.relative)


func _on_touch_down(index: int, pos: Vector2) -> void:
	for button in _buttons:
		if pos.distance_to(_button_center(button)) <= _button_radius(button):
			button["touch"] = index
			_send_action(button["action"], true, 1.0)
			return
	if pos.x < size.x * joystick_zone and _stick_touch == -1:
		_stick_touch = index
		_stick_center = pos
		_stick_knob = pos
	else:
		_look_touches[index] = true


func _on_touch_up(index: int) -> void:
	for button in _buttons:
		if button["touch"] == index:
			button["touch"] = -1
			_send_action(button["action"], false, 0.0)
	if index == _stick_touch:
		_stick_touch = -1
		for action in MOVE_ACTIONS:
			_send_action(action, false, 0.0)
	_look_touches.erase(index)


func _update_stick(pos: Vector2) -> void:
	var radius := _stick_radius()
	var offset := (pos - _stick_center).limit_length(radius)
	_stick_knob = _stick_center + offset
	var v := offset / radius  # -1..1 on each axis; screen up = forward.
	_send_axis("move_left", "move_right", v.x)
	_send_axis("move_forward", "move_back", v.y)


func _send_axis(negative: String, positive: String, value: float) -> void:
	_send_action(negative, value < 0.0, maxf(-value, 0.0))
	_send_action(positive, value > 0.0, maxf(value, 0.0))


func _send_action(action: String, pressed: bool, strength: float) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = strength
	Input.parse_input_event(ev)


func _short_side() -> float:
	return minf(size.x, size.y)


func _stick_radius() -> float:
	return _short_side() * joystick_radius_ratio * GameSettings.touch_scale


func _button_radius(button: Dictionary) -> float:
	return _short_side() * button_radius_ratio * float(button["scale"]) * GameSettings.touch_scale


func _button_center(button: Dictionary) -> Vector2:
	var unit := _short_side() * button_radius_ratio * GameSettings.touch_scale  # Spacing grows with the buttons.
	var anchor := button["anchor"] as Vector2
	if button.get("top", false):
		return Vector2(size.x + anchor.x * unit, anchor.y * unit)  # Measured from the top-right corner.
	return size + anchor * unit


func _draw() -> void:
	var font := get_theme_default_font()
	if _stick_touch != -1:
		draw_circle(_stick_center, _stick_radius(), Color(1, 1, 1, 0.12))
		draw_arc(_stick_center, _stick_radius(), 0.0, TAU, 48, Color(1, 1, 1, 0.5), 3.0)
		draw_circle(_stick_knob, _stick_radius() * 0.45, Color(1, 1, 1, 0.55))
	else:
		# Hint where the joystick lives.
		var hint := Vector2(size.x * 0.16, size.y * 0.72)
		draw_arc(hint, _stick_radius(), 0.0, TAU, 48, Color(1, 1, 1, 0.25), 2.0)
	for button in _buttons:
		var center := _button_center(button)
		var radius := _button_radius(button)
		var held: bool = button["touch"] != -1
		draw_circle(center, radius, Color(0.85, 0.15, 0.15, 0.55) if held else Color(0, 0, 0, 0.35))
		draw_arc(center, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.7), 3.0)
		var text: String = button["label"]
		var font_size := int(radius * 0.45)
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(font, center + Vector2(-text_size.x * 0.5, font_size * 0.35), text,
				HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
