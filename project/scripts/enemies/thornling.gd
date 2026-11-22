class_name Thornling
extends CharacterBody3D
## Small original jungle beast with one readable attack (Phase 4 combat sparring partner).
## Telegraph: it rears up, its back spines glow red and a red strip on the ground shows the lunge
## path — readable from both camera modes. After lunging it pauses (the punish window).
##
## States: IDLE (wander near home) -> CHASE -> TELEGRAPH -> LUNGE -> RECOVER -> CHASE ...
##         any (alive) --poise broken--> STAGGER -> CHASE      any --health 0--> DEAD
##         CHASE --player beyond leash--> RETURN -> IDLE (heals)

signal state_changed(state: State)
signal telegraph_started(direction: Vector3)
signal died

enum State { IDLE, CHASE, TELEGRAPH, LUNGE, RECOVER, STAGGER, RETURN, DEAD }

@export var config: EnemyConfig

var state: State = State.IDLE
var home: Vector3

var _health: HealthComponent
var _hitbox: Hitbox
var _visual: Node3D
var _mesh: GeometryInstance3D
var _warning: GeometryInstance3D
var _health_bar: GeometryInstance3D
var _player: PlayerController
var _t: float = 0.0
var _poise_damage: float = 0.0
var _aim: Vector3 = Vector3.FORWARD
var _push: Vector3 = Vector3.ZERO
var _wander_target: Vector3
var _flash: float = 0.0
var _bar_timer: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("lock_targets")
	add_to_group("enemies")
	collision_layer = 8  # layer 4: enemy
	collision_mask = 1 | 2 | 8
	home = global_position
	_wander_target = home
	_rng.seed = hash(name)
	_health = $Health as HealthComponent
	_health.max_health = config.max_health
	_health.reset()
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	_hitbox = $Visual/LungeHitbox as Hitbox
	_visual = $Visual as Node3D
	_mesh = $Visual/Body as GeometryInstance3D
	_warning = $Warning as GeometryInstance3D
	_health_bar = $HealthBar as GeometryInstance3D
	_warning.visible = false
	_health_bar.visible = false


func is_alive() -> bool:
	return state != State.DEAD


func get_lock_point() -> Vector3:
	return global_position + Vector3.UP * 0.7


func get_health() -> HealthComponent:
	return _health


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as PlayerController
	_t += delta
	_flash = maxf(_flash - delta * 5.0, 0.0)
	_mesh.set_instance_shader_parameter("hit_flash", _flash)
	_update_health_bar(delta)
	var move := Vector3.ZERO
	match state:
		State.IDLE:
			move = _idle()
		State.CHASE:
			move = _chase()
		State.RETURN:
			move = _return_home()
		State.TELEGRAPH:
			_telegraph()
		State.LUNGE:
			move = _aim * config.lunge_speed
			if _t >= config.lunge_time:
				_hitbox.deactivate()
				_set_state(State.RECOVER)
		State.RECOVER:
			if _t >= config.recover_time:
				_set_state(State.CHASE)
		State.STAGGER:
			_push = _push.move_toward(Vector3.ZERO, 14.0 * delta)
			move = _push
			if _t >= config.stagger_time:
				_set_state(State.CHASE)
		State.DEAD:
			var k := clampf(1.0 - _t / config.death_fade_time, 0.0, 1.0)
			_visual.scale = Vector3.ONE * maxf(k, 0.01)
			if _t >= config.death_fade_time:
				queue_free()
			return
	velocity.x = move.x
	velocity.z = move.z
	velocity.y = -1.0 if is_on_floor() else velocity.y - 24.0 * delta
	move_and_slide()
	# Rear-up pose while telegraphing.
	var rear := 0.0
	if state == State.TELEGRAPH:
		rear = deg_to_rad(-25.0) * smoothstep(0.0, 0.3, _t / config.telegraph_time)
	_visual.rotation.x = lerpf(_visual.rotation.x, rear, 1.0 - exp(-12.0 * delta))


# ---------------------------------------------------------------- behaviour

func _player_alive_near(range_m: float) -> bool:
	return _player != null and _player.combat != null and _player.combat.state != PlayerCombat.State.DEAD \
			and _player.global_position.distance_to(global_position) <= range_m


func _idle() -> Vector3:
	if _player_alive_near(config.aggro_range):
		_set_state(State.CHASE)
		return Vector3.ZERO
	if global_position.distance_to(_wander_target) < 0.6 or _t > 6.0:
		var a := _rng.randf() * TAU
		_wander_target = home + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(0.5, config.wander_radius)
		_t = 0.0
	return _steer_to(_wander_target, config.move_speed * 0.35)


func _chase() -> Vector3:
	if home.distance_to(global_position) > config.leash_range or not _player_alive_near(config.leash_range):
		_set_state(State.RETURN)
		return Vector3.ZERO
	var dist := _player.global_position.distance_to(global_position)
	if dist <= config.attack_range:
		_set_state(State.TELEGRAPH)
		return Vector3.ZERO
	return _steer_to(_player.global_position, config.move_speed)


func _return_home() -> Vector3:
	if global_position.distance_to(home) < 1.0:
		_health.reset()
		_set_state(State.IDLE)
		return Vector3.ZERO
	return _steer_to(home, config.move_speed)


func _telegraph() -> void:
	var glow := smoothstep(0.0, 1.0, _t / config.telegraph_time)
	_mesh.set_instance_shader_parameter("spine_glow", glow)
	# Track the player until the aim locks, so a well-timed dodge still works.
	if _t < config.telegraph_time - config.aim_lock_time and _player:
		var d := _player.global_position - global_position
		d.y = 0.0
		if d.length() > 0.05:
			_aim = d.normalized()
	_face(_aim, 1.0)
	_warning.global_position = global_position + _aim * (config.lunge_speed * config.lunge_time * 0.5) + Vector3.UP * 0.05
	_warning.global_rotation = Vector3(0, atan2(-_aim.x, -_aim.z), 0)
	_warning.set_instance_shader_parameter("intensity", glow)
	if _t >= config.telegraph_time:
		_mesh.set_instance_shader_parameter("spine_glow", 0.0)
		_warning.visible = false
		var info := DamageInfo.new()
		info.amount = config.damage
		info.stagger = 100.0
		info.knockback = config.knockback
		info.source = self
		info.attack_name = &"thornling_lunge"
		_hitbox.activate(info)
		_set_state(State.LUNGE)


func _steer_to(target: Vector3, speed: float) -> Vector3:
	var d := target - global_position
	d.y = 0.0
	if d.length() < 0.1:
		return Vector3.ZERO
	var dir := d.normalized()
	_face(dir, get_physics_process_delta_time() * config.turn_sharpness)
	return dir * speed


func _face(dir: Vector3, weight: float) -> void:
	var yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, yaw, clampf(weight, 0.0, 1.0))


# ---------------------------------------------------------------- damage

func _on_damaged(info: DamageInfo) -> void:
	_flash = 1.0
	_bar_timer = 4.0
	if state == State.DEAD:
		return
	if state == State.IDLE or state == State.RETURN:
		_set_state(State.CHASE)
	_poise_damage += info.stagger
	if _poise_damage >= config.poise and state != State.LUNGE:
		_poise_damage = 0.0
		_push = info.push_direction(global_position) * config.stagger_knockback
		_hitbox.deactivate()
		_warning.visible = false
		_mesh.set_instance_shader_parameter("spine_glow", 0.0)
		_set_state(State.STAGGER)


func _on_died() -> void:
	_hitbox.deactivate()
	_warning.visible = false
	_health_bar.visible = false
	collision_layer = 0
	($Hurtbox as Hurtbox).set_deferred("monitorable", false)
	remove_from_group("lock_targets")
	_set_state(State.DEAD)
	died.emit()


func _update_health_bar(delta: float) -> void:
	_bar_timer -= delta
	_health_bar.visible = _bar_timer > 0.0 and state != State.DEAD
	if _health_bar.visible:
		_health_bar.set_instance_shader_parameter("fill", _health.fraction())


func _set_state(s: State) -> void:
	state = s
	_t = 0.0
	if s == State.TELEGRAPH:
		_warning.visible = true
		telegraph_started.emit(_aim)
	elif s != State.LUNGE:
		_warning.visible = false
	state_changed.emit(s)
