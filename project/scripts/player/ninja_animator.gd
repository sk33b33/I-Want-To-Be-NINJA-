class_name NinjaAnimator
extends Node
## Drives the ninja model's AnimationPlayer from PlayerController state (presentation only:
## it never changes movement). States: IDLE, RUN, SPRINT, AIR, LAND, CLIMB, HANG, MANTLE.
## Implements docs/PHASES.md Phase 1 player feedback using assets/models/ninja/ninja.glb.

enum State { IDLE, RUN, SPRINT, AIR, LAND, CLIMB, HANG, MANTLE }

@export var player_path: NodePath = ^".."
@export var animation_player_path: NodePath
@export var config: NinjaAnimationConfig

var state: State = State.IDLE

var _player: PlayerController
var _anim: AnimationPlayer
var _air_clip: StringName
var _land_timer: float = 0.0
var _idle_name: StringName = &"Idle"


func _ready() -> void:
	_player = get_node(player_path) as PlayerController
	_anim = get_node_or_null(animation_player_path) as AnimationPlayer
	if _anim == null:
		push_warning("NinjaAnimator: no AnimationPlayer found; animations disabled.")
		set_physics_process(false)
		return
	_prepare_clips()
	_player.jumped.connect(_on_jumped)
	_player.landed.connect(_on_landed)
	if _player.traversal:
		_player.traversal.state_changed.connect(_on_traversal_state)
	_play(_idle_name)


func _physics_process(delta: float) -> void:
	if _player.traversal and _player.traversal.state != TraversalComponent.State.NONE:
		if state == State.CLIMB:
			var climb_speed := _player.traversal.get_climb_velocity().length()
			_anim.speed_scale = clampf(climb_speed / config.climb_reference_speed, 0.0, 1.5)
		return
	var speed := _player.get_horizontal_speed()
	var on_floor := _player.is_on_floor()
	match state:
		State.AIR:
			if _anim.current_animation == config.jump_clip and _anim.current_animation_position >= config.jump_hold_time:
				_anim.pause()
			elif _anim.current_animation == config.sprint_jump_clip and _anim.current_animation_position >= config.flip_end_time:
				_anim.pause()
			if on_floor:
				_on_landed()
		State.LAND:
			_land_timer -= delta
			if speed > config.idle_speed_threshold or _land_timer <= 0.0:
				_enter_ground_state(speed)
		_:
			if not on_floor:
				_start_fall()
			else:
				_enter_ground_state(speed)


## Current clip name (for tests and debugging).
func current_clip() -> StringName:
	return _anim.current_animation if _anim else &""


func _enter_ground_state(speed: float) -> void:
	if speed < config.idle_speed_threshold:
		_set_state(State.IDLE, _idle_name, 1.0)
	elif Input.is_action_pressed("sprint") and speed > config.run_reference_speed:
		_set_state(State.SPRINT, config.sprint_clip, clampf(speed / config.sprint_reference_speed, 0.7, 1.5))
	else:
		_set_state(State.RUN, config.run_clip, clampf(speed / config.run_reference_speed, 0.5, 1.6))


func _set_state(new_state: State, clip: StringName, speed_scale: float) -> void:
	_anim.speed_scale = speed_scale
	if state != new_state or _anim.current_animation != clip:
		state = new_state
		_play(clip)


func _on_traversal_state(traversal_state: TraversalComponent.State) -> void:
	_anim.speed_scale = 1.0
	match traversal_state:
		TraversalComponent.State.CLIMB:
			state = State.CLIMB
			if _anim.has_animation(config.climb_clip):
				_anim.get_animation(config.climb_clip).loop_mode = Animation.LOOP_LINEAR
			_play(config.climb_clip, 0.1)
		TraversalComponent.State.HANG:
			state = State.HANG
			_play(config.hang_clip, 0.08)
			_anim.seek(config.hang_pose_time, true)
			_anim.pause()
		TraversalComponent.State.MANTLE:
			state = State.MANTLE
			_play(config.mantle_clip, 0.08)
			_anim.seek(config.mantle_start_time, true)
		TraversalComponent.State.NONE:
			if state != State.AIR:  # A wall jump already switched to AIR.
				state = State.AIR
				_start_fall()


func _on_jumped() -> void:
	state = State.AIR
	_anim.speed_scale = 1.0
	var flip := Input.is_action_pressed("sprint") and _player.get_horizontal_speed() > config.run_reference_speed \
			and _anim.has_animation(config.sprint_jump_clip)
	_air_clip = config.sprint_jump_clip if flip else config.jump_clip
	_play(_air_clip, 0.08)
	_anim.seek(config.flip_takeoff_time if flip else config.jump_takeoff_time, true)


func _start_fall() -> void:
	state = State.AIR
	_anim.speed_scale = 1.0
	_air_clip = config.jump_clip
	_play(config.jump_clip, 0.2)
	_anim.seek(config.jump_hold_time, true)
	_anim.pause()


func _on_landed() -> void:
	if state != State.AIR:
		return
	if _player.get_horizontal_speed() > config.idle_speed_threshold:
		_enter_ground_state(_player.get_horizontal_speed())
		return
	state = State.LAND
	_anim.speed_scale = 1.0
	_play(config.jump_clip, 0.08)
	_anim.seek(config.jump_land_time, true)
	_land_timer = 0.35


func _play(clip: StringName, blend: float = -1.0) -> void:
	_anim.play(clip, config.blend_time if blend < 0.0 else blend)


## Loop locomotion clips, build the idle pose, and strip root motion from jump clips.
func _prepare_clips() -> void:
	for clip in [config.run_clip, config.sprint_clip]:
		if _anim.has_animation(clip):
			_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	for clip in [config.jump_clip, config.sprint_jump_clip]:
		if _anim.has_animation(clip):
			_flatten_hips(_anim.get_animation(clip))
	if config.idle_clip != &"" and _anim.has_animation(config.idle_clip):
		_idle_name = config.idle_clip
		_anim.get_animation(_idle_name).loop_mode = Animation.LOOP_LINEAR
	elif _anim.has_animation(config.idle_pose_clip):
		var lib := _anim.get_animation_library(&"")
		if not lib.has_animation(_idle_name):
			lib.add_animation(_idle_name, _pose_from(_anim.get_animation(config.idle_pose_clip), config.idle_pose_time))


## Mixamo armature is Z-up and scaled 0.01: hips bone-space y = forward, -z = up (centimetres).
func _flatten_hips(anim: Animation) -> void:
	var track := anim.find_track(config.hips_bone_track, Animation.TYPE_POSITION_3D)
	if track < 0:
		return
	var start: Vector3 = anim.track_get_key_value(track, 0)
	var max_up_cm := config.max_hips_height * 100.0
	for k in anim.track_get_key_count(track):
		var p: Vector3 = anim.track_get_key_value(track, k)
		p.x = start.x
		p.y = start.y  # Remove forward root motion.
		p.z = maxf(p.z, -max_up_cm)  # Clamp vertical rise.
		anim.track_set_key_value(track, k, p)


## A looping single-pose animation sampled from `source` at `time`, with a slow breathing sway.
func _pose_from(source: Animation, time: float) -> Animation:
	var pose := Animation.new()
	pose.length = 2.4
	pose.loop_mode = Animation.LOOP_LINEAR
	for t in source.get_track_count():
		var type := source.track_get_type(t)
		var path := source.track_get_path(t)
		var nt := pose.add_track(type)
		pose.track_set_path(nt, path)
		match type:
			Animation.TYPE_POSITION_3D:
				var p := source.position_track_interpolate(t, time)
				pose.position_track_insert_key(nt, 0.0, p)
				if str(path).ends_with("mixamorig_Hips"):
					pose.position_track_insert_key(nt, 1.2, p + Vector3(0, 0, 1.2))  # Hips dip 1.2 cm.
				pose.position_track_insert_key(nt, 2.4, p)
			Animation.TYPE_ROTATION_3D:
				var r := source.rotation_track_interpolate(t, time)
				pose.rotation_track_insert_key(nt, 0.0, r)
				pose.rotation_track_insert_key(nt, 2.4, r)
			Animation.TYPE_SCALE_3D:
				pose.scale_track_insert_key(nt, 0.0, source.scale_track_interpolate(t, time))
			_:
				pose.remove_track(nt)
	return pose
