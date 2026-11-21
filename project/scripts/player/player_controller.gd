class_name PlayerController
extends CharacterBody3D
## Ninja locomotion: camera-relative run/sprint, jump (coyote time, jump buffer, variable
## height), fall recovery, and checkpoints. Traversal (climb, ledge grab, mantle) lives in the
## optional child TraversalComponent "Traversal" (Phase 2).
## Implements docs/PHASES.md Phases 1-2. Reads input actions only, so keyboard, gamepad and
## TouchControls all drive it the same way. All tuning lives in PlayerMovementConfig.

signal jumped
signal landed
signal respawned(at: Vector3)
signal checkpoint_reached(at: Transform3D)

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
var _checkpoint: Transform3D
var _has_checkpoint: bool = false

@onready var _visual: Node3D = $Visual
@onready var traversal: TraversalComponent = get_node_or_null("Traversal") as TraversalComponent


func _ready() -> void:
	add_to_group("player")
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

	if traversal and traversal.physics_update(delta, input, wish):
		_was_on_floor = false
		_after_move(delta)
		return

	_update_horizontal(wish, on_floor, delta)
	_update_vertical(on_floor, delta)
	move_and_slide()
	_after_move(delta)


## Teleport with no momentum: to `at` if given, else the last checkpoint, else the last safe ground.
func respawn(at: Variant = null) -> void:
	var target: Vector3 = _last_safe_position
	if at is Vector3:
		target = at
	elif _has_checkpoint:
		target = _checkpoint.origin
		face_direction(-_checkpoint.basis.z)
		if _camera_rig:
			_camera_rig.set_yaw(_checkpoint.basis.get_euler().y)
	if traversal:
		traversal.reset()
	global_position = target + Vector3.UP * config.respawn_height_offset
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


## Called by Checkpoint shrines. Falls respawn here from now on.
func set_checkpoint(at: Transform3D) -> void:
	_checkpoint = at
	_has_checkpoint = true
	_last_safe_position = at.origin
	checkpoint_reached.emit(at)


func has_checkpoint() -> bool:
	return _has_checkpoint


func get_checkpoint() -> Transform3D:
	return _checkpoint


## Turn the body visual to face `dir` instantly (used by traversal).
func face_direction(dir: Vector3) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() > 0.001:
		_visual.rotation.y = atan2(-flat.x, -flat.z)


## Returns true once per buffered jump press, consuming it (used by traversal).
func consume_jump() -> bool:
	if _jump_buffer_timer > 0.0:
		_jump_buffer_timer = 0.0
		return true
	return false


## Emit `jumped` for jumps started outside the controller (wall jumps).
func notify_jumped() -> void:
	_coyote_timer = 0.0
	jumped.emit()


## Forget coyote time / jump buffer (after letting go of a wall so no free ground jump fires).
func clear_air_timers() -> void:
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0


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
