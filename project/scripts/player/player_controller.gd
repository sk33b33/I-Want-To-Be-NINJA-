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
## Active SurfaceZones. Typed as Area3D on purpose: SurfaceZone references PlayerController,
## and a two-way script type reference is a cycle Godot cannot free at exit.
var _surface_zones: Array[Area3D] = []

@onready var _visual: Node3D = $Visual
@onready var traversal: TraversalComponent = get_node_or_null("Traversal") as TraversalComponent
@onready var combat: PlayerCombat = get_node_or_null("Combat") as PlayerCombat


func _ready() -> void:
	add_to_group("player")
	_camera_rig = get_node_or_null(camera_rig_path) as CameraRig
	if combat and _camera_rig:
		combat.lock_target_changed.connect(func(t: Node3D) -> void:
			_camera_rig.set_lock_target(t, combat.get_lock_point))
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

	# Combat actions in progress (attack, dodge, hurt, death) take priority over everything.
	if combat and combat.is_busy():
		if traversal and traversal.state != TraversalComponent.State.NONE:
			traversal.reset()
		combat.physics_update(delta, input, wish)
		_after_move(delta)
		return
	if traversal and traversal.physics_update(delta, input, wish):
		_was_on_floor = false
		_after_move(delta)
		return
	if combat and combat.physics_update(delta, input, wish):
		_after_move(delta)
		return

	_update_horizontal(wish, on_floor, delta)
	_update_vertical(on_floor, delta)
	move_and_slide()
	if combat and combat.lock_target:
		face_direction(combat.get_lock_point() - global_position)  # Strafe around the target.
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


## Current facing of the body visual (flat, unit length).
func get_facing() -> Vector3:
	var f := -_visual.global_basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.001 else Vector3.FORWARD


## Yaw-only camera basis (identity without a camera rig).
func get_camera_basis() -> Basis:
	return _camera_rig.get_yaw_basis() if _camera_rig else Basis.IDENTITY


func shake_camera(trauma: float) -> void:
	if _camera_rig:
		_camera_rig.add_shake(trauma)


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


## SurfaceZones (mud, poison, currents) register themselves while the player stands in them.
func add_surface_zone(zone: Area3D) -> void:
	if not _surface_zones.has(zone):
		_surface_zones.append(zone)


func remove_surface_zone(zone: Area3D) -> void:
	_surface_zones.erase(zone)


## Slowest active zone wins (standing on mud and in poison does not stack the slow).
func surface_speed_multiplier() -> float:
	var m := 1.0
	for z in _surface_zones:
		m = minf(m, float(z.get("speed_multiplier")))
	return m


## Least grip wins (wet stone). Scales ground acceleration and braking.
func surface_traction() -> float:
	var t := 1.0
	for z in _surface_zones:
		t = minf(t, float(z.get("traction")))
	return t


func surface_blocks_jump() -> bool:
	for z in _surface_zones:
		if z.get("blocks_jump"):
			return true
	return false


func surface_current() -> Vector3:
	var c := Vector3.ZERO
	for z in _surface_zones:
		c += z.get("current") as Vector3
	return c


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
	top_speed *= surface_speed_multiplier()
	var drift := surface_current()
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)

	if on_floor:
		var accel := config.ground_acceleration if has_input else config.ground_deceleration
		accel *= surface_traction()
		# A current moves the target velocity, so standing still in a stream drifts with it.
		horizontal = horizontal.move_toward(wish * top_speed + drift, accel * delta)
	elif has_input or drift != Vector3.ZERO:
		# Airborne steering; with no input the ninja keeps momentum.
		horizontal = horizontal.move_toward(wish * top_speed + drift, config.air_acceleration * delta)

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

	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0 and not surface_blocks_jump():
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
