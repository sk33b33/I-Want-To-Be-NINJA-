class_name NinjaAnimator
extends Node
## Drives the ninja model's AnimationPlayer from PlayerController state (presentation only:
## it never changes movement). States: IDLE, RUN, SPRINT, AIR, LAND, CLIMB, HANG, MANTLE.
## Implements docs/PHASES.md Phase 1 player feedback using assets/models/ninja/ninja.glb.

enum State { IDLE, RUN, SPRINT, AIR, LAND, CLIMB, HANG, MANTLE, COMBAT, DEAD }

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
	if _player.combat:
		var c := _player.combat
		c.attack_started.connect(_on_attack_started)
		c.dodge_started.connect(_on_dodge_started)
		c.hurt.connect(_on_hurt)
		c.player_died.connect(_on_player_died)
		c.player_respawned.connect(func() -> void: _set_state(State.IDLE, _idle_name, 1.0))
		c.hit_stopped.connect(_on_hit_stopped)
	_play(_idle_name)


func _physics_process(delta: float) -> void:
	if _freeze > 0.0:
		_freeze -= delta
		if _freeze <= 0.0:
			_anim.speed_scale = _frozen_speed
	if _player.combat and _player.combat.is_busy():
		_update_combat()
		return
	if state == State.COMBAT or state == State.DEAD:
		state = State.LAND  # Hand back to locomotion.
		_enter_ground_state(_player.get_horizontal_speed())
		return
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


var _freeze: float = 0.0
var _frozen_speed: float = 1.0
var _slice_end: float = INF


func _update_combat() -> void:
	# Hold the last frame of a clip slice instead of running into the next move.
	if _anim.current_animation_position >= _slice_end and _anim.speed_scale > 0.0:
		_anim.pause()


func _play_slice(clip: StringName, from: float, to: float, speed: float, blend: float) -> void:
	state = State.COMBAT
	_freeze = 0.0
	_anim.play(clip, blend)
	_anim.seek(from, true)
	_anim.speed_scale = speed
	_slice_end = to


func _on_attack_started(attack: AttackDefinition, _index: int) -> void:
	_play_slice(attack.clip, attack.clip_start, attack.clip_end, attack.speed, 0.06)


func _on_dodge_started(_dir: Vector3) -> void:
	var speed := config.roll_end_time / maxf(_player.combat.config.dodge_time, 0.05)
	_play_slice(config.roll_clip, 0.0, config.roll_end_time, speed, 0.05)


func _on_hurt(_info: DamageInfo) -> void:
	var speed := config.hurt_end_time / maxf(_player.combat.config.hurt_time, 0.05)
	_play_slice(config.hurt_clip, 0.0, config.hurt_end_time, speed, 0.05)


func _on_player_died() -> void:
	_play_slice(config.death_clip, 0.0, INF, 1.0, 0.1)
	state = State.DEAD


func _on_hit_stopped(seconds: float) -> void:
	if _freeze <= 0.0:
		_frozen_speed = _anim.speed_scale
	_freeze = seconds
	_anim.speed_scale = 0.0


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
	for clip in config.strip_forward_motion:
		if _anim.has_animation(clip):
			_strip_forward(_anim.get_animation(clip))
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


## Remove travel along the ground (bone-space x/y) but keep the vertical motion (crouch, fall).
func _strip_forward(anim: Animation) -> void:
	var track := anim.find_track(config.hips_bone_track, Animation.TYPE_POSITION_3D)
	if track < 0:
		return
	var start: Vector3 = anim.track_get_key_value(track, 0)
	for k in anim.track_get_key_count(track):
		var p: Vector3 = anim.track_get_key_value(track, k)
		anim.track_set_key_value(track, k, Vector3(start.x, start.y, p.z))


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
