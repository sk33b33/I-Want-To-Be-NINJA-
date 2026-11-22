class_name CameraRig
extends Node3D
## Orbit camera with smooth blending between third-person and top-down modes.
## Implements docs/GAME_DESIGN.md "Camera". Camera mode is a player option, not a game mode:
## both modes share the same yaw, so movement stays camera-relative via get_yaw_basis().
##
## Node layout: CameraRig (yaw) -> Pivot (pitch) -> SpringArm3D (distance + collision) -> Camera3D.

signal mode_changed(mode: Mode)

enum Mode { THIRD_PERSON, TOP_DOWN }

@export var config: CameraRigConfig
## Node the rig follows (normally the player). Defaults to the parent.
@export var target_path: NodePath = ^".."

var mode: Mode = Mode.THIRD_PERSON

var _target: Node3D
var _yaw: float = 0.0
var _tp_pitch: float = 0.0
var _td_distance: float = 0.0
## Current blended values (what is actually applied this frame).
var _pitch: float = 0.0
var _distance: float = 0.0
var _lock_target: Node3D
var _lock_point: Callable
var _shake: float = 0.0
var _shake_time: float = 0.0

@onready var _pivot: Node3D = $Pivot
@onready var _arm: SpringArm3D = $Pivot/SpringArm3D
@onready var camera: Camera3D = $Pivot/SpringArm3D/Camera3D


func _ready() -> void:
	# Detach from the parent's transform so player rotation never spins the camera.
	top_level = true
	_target = get_node_or_null(target_path) as Node3D
	_yaw = global_rotation.y
	_tp_pitch = deg_to_rad(config.tp_default_pitch_deg)
	_td_distance = config.td_distance
	_pitch = _tp_pitch
	_distance = config.tp_distance
	_arm.margin = config.collision_margin
	camera.fov = config.fov
	snap_to_target()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_toggle"):
		toggle_mode()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.device == InputEvent.DEVICE_ID_EMULATION:
			return  # Touch-emulated click; touch look is handled by TouchControls.
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _uses_mouse_capture():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(-config.td_zoom_step)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(config.td_zoom_step)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.device != InputEvent.DEVICE_ID_EMULATION and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			add_look_input(mm.relative * config.mouse_sensitivity)


func _process(delta: float) -> void:
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if stick != Vector2.ZERO:
		add_look_input(stick * deg_to_rad(config.stick_speed_deg) * delta)

	if _lock_target and is_instance_valid(_lock_target):
		# Turn so the locked target stays ahead of the player.
		var point: Vector3 = _lock_point.call() if _lock_point.is_valid() else _lock_target.global_position
		var dir := point - global_position
		if Vector2(dir.x, dir.z).length() > 0.5:
			var want := atan2(-dir.x, -dir.z)
			_yaw = lerp_angle(_yaw, want, 1.0 - exp(-config.lock_camera_sharpness * delta))

	if _target:
		var follow_weight := 1.0 - exp(-config.follow_sharpness * delta)
		global_position = global_position.lerp(_target_point(), follow_weight)

	var blend_weight := 1.0 - exp(-config.mode_blend_sharpness * delta)
	_pitch = lerpf(_pitch, _target_pitch(), blend_weight)
	_distance = lerpf(_distance, _target_distance(), blend_weight)
	_apply()
	_apply_shake(delta)


## Rotate the camera. x = yaw (radians, positive turns right), y = pitch (positive looks down).
func add_look_input(look: Vector2) -> void:
	_yaw -= look.x
	if mode == Mode.THIRD_PERSON:
		var dir := 1.0 if config.invert_y else -1.0
		_tp_pitch = clampf(_tp_pitch + look.y * dir,
				deg_to_rad(config.tp_min_pitch_deg), deg_to_rad(config.tp_max_pitch_deg))


## Touch-drag look, in screen pixels. Wired from TouchControls.look_dragged.
func add_touch_look(relative: Vector2) -> void:
	add_look_input(relative * config.touch_sensitivity)


func zoom(amount: float) -> void:
	if mode == Mode.TOP_DOWN:
		_td_distance = clampf(_td_distance + amount, config.td_min_distance, config.td_max_distance)


func toggle_mode() -> void:
	set_mode(Mode.TOP_DOWN if mode == Mode.THIRD_PERSON else Mode.THIRD_PERSON)


func set_mode(new_mode: Mode) -> void:
	if new_mode == mode:
		return
	mode = new_mode
	mode_changed.emit(mode)


## Keep `target` framed (lock-on). `point` returns the world point to look at; null clears.
func set_lock_target(target: Node3D, point: Callable = Callable()) -> void:
	_lock_target = target
	_lock_point = point


## Add camera shake (0..1 "trauma"; decays quickly). Gentle by design.
func add_shake(trauma: float) -> void:
	if not GameSettings.screen_shake:
		return  # Comfort option (pause menu).
	_shake = clampf(_shake + trauma, 0.0, 1.0)


func set_yaw(yaw: float) -> void:
	_yaw = yaw
	_apply()


## Flat (yaw-only) basis used by the player to turn stick input into world directions.
func get_yaw_basis() -> Basis:
	return Basis(Vector3.UP, _yaw)


## True while pitch/distance are still easing toward the current mode's targets.
func is_blending() -> bool:
	return absf(_pitch - _target_pitch()) > 0.01 or absf(_distance - _target_distance()) > 0.05


## Jump straight to the target (used on spawn and respawn to avoid a long swoop).
func snap_to_target() -> void:
	if _target:
		global_position = _target_point()
	_apply()


func get_pitch() -> float:
	return _pitch


func get_distance() -> float:
	return _distance


func _target_point() -> Vector3:
	return _target.global_position + Vector3.UP * config.pivot_height


func _target_pitch() -> float:
	return _tp_pitch if mode == Mode.THIRD_PERSON else deg_to_rad(config.td_pitch_deg)


func _target_distance() -> float:
	return config.tp_distance if mode == Mode.THIRD_PERSON else _td_distance


func _apply() -> void:
	rotation = Vector3(0.0, _yaw, 0.0)
	_pivot.rotation = Vector3(_pitch, 0.0, 0.0)
	_arm.spring_length = _distance


func _apply_shake(delta: float) -> void:
	_shake = maxf(_shake - delta * 2.5, 0.0)
	_shake_time += delta * 40.0
	var s := _shake * _shake * config.shake_strength
	camera.h_offset = sin(_shake_time * 1.3) * s
	camera.v_offset = cos(_shake_time * 1.7) * s


func _uses_mouse_capture() -> bool:
	return not DisplayServer.is_touchscreen_available() and not Input.emulate_touch_from_mouse
