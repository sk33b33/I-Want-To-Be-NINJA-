class_name PlayerController
extends CharacterBody3D
## Phase 1 ninja locomotion: camera-relative run/sprint, jump (coyote time, jump buffer,
## variable height) and fall recovery to the last safe ground.
## Implements docs/PHASES.md "Phase 1". Reads input actions only, so keyboard, gamepad and
## TouchControls all drive it the same way. All tuning lives in PlayerMovementConfig.

signal jumped
signal landed
signal respawned(at: Vector3)

@export var config: PlayerMovementConfig
@export var camera_rig_path: NodePath = ^"CameraRig"
## Set false to freeze player input (menus, cutscenes, tests).
@export var input_enabled: bool = true

var _camera_rig: CameraRig
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _safe_timer: float = 0.0
var _last_safe_position: Vector3
var _was_on_floor: bool = false

@onready var _visual: Node3D = $Visual


func _ready() -> void:
	_camera_rig = get_node_or_null(camera_rig_path) as CameraRig
	_last_safe_position = global_position


func _unhandled_input(event: InputEvent) -> void:
	# Buffer the press from the event so short taps between physics ticks are never lost.
	if input_enabled and event.is_action_pressed("jump"):
		_jump_buffer_timer = config.jump_buffer_time


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	var input := Vector2.ZERO
	if input_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := _input_to_world(input)

	_update_horizontal(wish, on_floor, delta)
	_update_vertical(on_floor, delta)
	move_and_slide()
	_after_move(delta)


## Teleport to the last safe ground (or `at`) with no momentum.
func respawn(at: Vector3 = _last_safe_position) -> void:
	global_position = at + Vector3.UP * config.respawn_height_offset
	velocity = Vector3.ZERO
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_safe_timer = 0.0
	if _camera_rig:
		_camera_rig.snap_to_target()
	respawned.emit(global_position)


## Mark a position as safe (spawn points, and later checkpoints).
func set_safe_position(at: Vector3) -> void:
	_last_safe_position = at


func get_safe_position() -> Vector3:
	return _last_safe_position


func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func _input_to_world(input: Vector2) -> Vector3:
	var basis := _camera_rig.get_yaw_basis() if _camera_rig else Basis.IDENTITY
	var dir := basis * Vector3(input.x, 0.0, input.y)
	# Keep analog magnitude (partial stick = slower), but never exceed 1.
	return dir.limit_length(1.0)


func _update_horizontal(wish: Vector3, on_floor: bool, delta: float) -> void:
	var has_input := wish.length_squared() > 0.0001
	var top_speed := config.sprint_speed if Input.is_action_pressed("sprint") else config.run_speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)

	if on_floor:
		var accel := config.ground_acceleration if has_input else config.ground_deceleration
		horizontal = horizontal.move_toward(wish * top_speed, accel * delta)
	elif has_input:
		# Airborne steering; with no input the ninja keeps momentum.
		horizontal = horizontal.move_toward(wish * top_speed, config.air_acceleration * delta)

	velocity.x = horizontal.x
	velocity.z = horizontal.z

	if horizontal.length_squared() > 0.01:
		var target_yaw := atan2(-horizontal.x, -horizontal.z)
		var weight := 1.0 - exp(-config.turn_sharpness * delta)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, weight)


func _update_vertical(on_floor: bool, delta: float) -> void:
	if on_floor:
		_coyote_timer = config.coyote_time
	else:
		_coyote_timer -= delta
	_jump_buffer_timer -= delta

	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = config.jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0  # No double jump from coyote time.
		jumped.emit()
		return

	if on_floor:
		return

	var g := config.gravity
	if velocity.y < 0.0:
		g *= config.fall_gravity_multiplier
	elif not Input.is_action_pressed("jump"):
		g *= config.jump_release_gravity_multiplier
	velocity.y = maxf(velocity.y - g * delta, -config.max_fall_speed)


func _after_move(delta: float) -> void:
	var now_on_floor := is_on_floor()
	if now_on_floor and not _was_on_floor:
		landed.emit()
	_was_on_floor = now_on_floor

	if now_on_floor:
		_safe_timer += delta
		if _safe_timer >= config.safe_ground_time:
			_last_safe_position = global_position
			_safe_timer = 0.0
	else:
		_safe_timer = 0.0

	if global_position.y < config.kill_height:
		respawn()
