class_name PlayerCombat
extends Node
## Player combat (docs/PHASES.md Phase 4): 3-hit light combo, heavy attack, dodge roll with
## i-frames, hit-stun, death + respawn at the last checkpoint, and lock-on.
## Like TraversalComponent, the controller calls physics_update() each tick; returning true means
## combat owns the body's movement this tick. Input is read as actions (touch/gamepad/keyboard).
##
## States and transitions:
##   READY  --light/heavy (on floor)--> ATTACK   --slice ends--> READY
##   ATTACK --light in cancel window--> ATTACK (next combo hit)  --dodge in cancel window--> DODGE
##   READY  --dodge (on floor)--> DODGE --time up--> READY
##   any but DEAD --hit taken--> HURT --hurt_time--> READY
##   any --health 0--> DEAD --respawn_delay--> READY (at checkpoint, full health)

signal state_changed(state: State)
signal attack_started(attack: AttackDefinition, combo_index: int)
signal dodge_started(direction: Vector3)
signal hurt(info: DamageInfo)
signal player_died
signal player_respawned
signal lock_target_changed(target: Node3D)
## Landed hit -> brief freeze (animator pauses for `seconds`).
signal hit_stopped(seconds: float)

enum State { READY, ATTACK, DODGE, HURT, DEAD }

@export var config: PlayerCombatConfig
@export var health_path: NodePath = ^"../Health"
@export var hitbox_path: NodePath = ^"../Visual/WeaponHitbox"
@export var hurtbox_path: NodePath = ^"../Hurtbox"

var state: State = State.READY
var lock_target: Node3D
var combo_index: int = 0
var current_attack: AttackDefinition

var body: PlayerController
var health: HealthComponent
var hitbox: Hitbox

var _t: float = 0.0
var _hit_stop: float = 0.0
var _attack_dir: Vector3 = Vector3.FORWARD
var _dodge_dir: Vector3 = Vector3.FORWARD
var _dodge_cooldown: float = 0.0
var _light_buffer: float = 0.0
var _heavy_buffer: float = 0.0
var _dodge_buffer: float = 0.0
var _sprint_press_time: float = -1.0
var _knockback: Vector3 = Vector3.ZERO
var _hit_active: bool = false


func _ready() -> void:
	body = get_parent() as PlayerController
	health = get_node_or_null(health_path) as HealthComponent
	hitbox = get_node_or_null(hitbox_path) as Hitbox
	if health:
		health.max_health = config.max_health
		health.reset()
		health.damaged.connect(_on_damaged)
		health.died.connect(_on_died)
	if hitbox:
		hitbox.hit_landed.connect(_on_hit_landed)
	body.respawned.connect(_on_body_respawned)


func _unhandled_input(event: InputEvent) -> void:
	if not body.input_enabled or state == State.DEAD:
		return
	if event.is_action_pressed("attack_light"):
		_light_buffer = config.input_buffer
	elif event.is_action_pressed("attack_heavy"):
		_heavy_buffer = config.input_buffer
	elif event.is_action_pressed("dodge"):
		_dodge_buffer = config.input_buffer
	elif event.is_action_pressed("lock_on"):
		toggle_lock()
	# Keyboard: a quick tap of Shift (the sprint key) is a dodge; holding it sprints.
	if event is InputEventKey and event.is_action("sprint"):
		var now := Time.get_ticks_msec() / 1000.0
		if event.is_pressed() and not event.is_echo():
			_sprint_press_time = now
		elif event.is_released() and _sprint_press_time >= 0.0:
			if now - _sprint_press_time <= config.keyboard_tap_time:
				_dodge_buffer = config.input_buffer
			_sprint_press_time = -1.0


## Returns true when combat moved the body this tick.
func physics_update(delta: float, _input: Vector2, wish: Vector3) -> bool:
	_light_buffer -= delta
	_heavy_buffer -= delta
	_dodge_buffer -= delta
	_dodge_cooldown -= delta
	_validate_lock()
	match state:
		State.DEAD:
			_t += delta
			_halt(delta)
			if _t >= config.respawn_delay:
				body.respawn()
			return true
		State.HURT:
			_t += delta
			_knockback = _knockback.move_toward(Vector3.ZERO, 18.0 * delta)
			_move(_knockback, delta)
			if _t >= config.hurt_time:
				_set_state(State.READY)
			return true
		State.DODGE:
			_update_dodge(delta)
			return true
		State.ATTACK:
			_update_attack(delta, wish)
			return true
	# READY: start actions only on solid ground and outside traversal.
	if not body.is_on_floor() or (body.traversal and body.traversal.state != TraversalComponent.State.NONE):
		return false
	if _dodge_buffer > 0.0 and _dodge_cooldown <= 0.0:
		_start_dodge(wish)
		return true
	if _light_buffer > 0.0 and not config.light_combo.is_empty():
		_start_attack(config.light_combo[0], 0, wish)
		return true
	if _heavy_buffer > 0.0 and config.heavy:
		_start_attack(config.heavy, -1, wish)
		return true
	return false


func is_busy() -> bool:
	return state != State.READY


func is_invulnerable() -> bool:
	return health != null and health.invulnerable


# ---------------------------------------------------------------- lock-on

func toggle_lock() -> void:
	if lock_target:
		set_lock_target(null)
	else:
		set_lock_target(find_lock_target())


func set_lock_target(target: Node3D) -> void:
	if target == lock_target:
		return
	lock_target = target
	lock_target_changed.emit(lock_target)


## Best target in range: closest to the camera's forward direction, then nearest.
func find_lock_target() -> Node3D:
	var best: Node3D = null
	var best_score := INF
	var forward := -body.get_camera_basis().z
	forward.y = 0.0
	forward = forward.normalized()
	for node in get_tree().get_nodes_in_group("lock_targets"):
		var t := node as Node3D
		if t == null or not _is_alive(t):
			continue
		var to := t.global_position - body.global_position
		var dist := to.length()
		if dist > config.lock_range or dist < 0.01:
			continue
		var flat := Vector3(to.x, 0.0, to.z).normalized()
		var angle := acos(clampf(forward.dot(flat), -1.0, 1.0))
		var score := angle * 2.0 + dist / config.lock_range
		if score < best_score:
			best_score = score
			best = t
	return best


func get_lock_point() -> Vector3:
	if lock_target == null:
		return Vector3.ZERO
	if lock_target.has_method("get_lock_point"):
		return lock_target.get_lock_point()
	return lock_target.global_position + Vector3.UP


func _validate_lock() -> void:
	if lock_target == null:
		return
	if not is_instance_valid(lock_target) or not _is_alive(lock_target) \
			or lock_target.global_position.distance_to(body.global_position) > config.lock_range * config.lock_break_factor:
		set_lock_target(null)


func _is_alive(t: Node) -> bool:
	return not t.has_method("is_alive") or t.is_alive()


# ---------------------------------------------------------------- attacks

func _start_attack(attack: AttackDefinition, index: int, wish: Vector3) -> void:
	_light_buffer = 0.0
	_heavy_buffer = 0.0
	current_attack = attack
	combo_index = index
	_t = 0.0
	_hit_active = false
	_attack_dir = _choose_direction(wish)
	body.face_direction(_attack_dir)
	_set_state(State.ATTACK)
	attack_started.emit(attack, index)


func _update_attack(delta: float, wish: Vector3) -> void:
	if _hit_stop > 0.0:
		_hit_stop -= delta
		_halt(delta)
		return
	_t += delta
	var a := current_attack
	var windup := a.windup_seconds()
	# Step forward during the windup to close small gaps; track the lock target until the hit.
	var step := Vector3.ZERO
	if _t < windup:
		if lock_target:
			_attack_dir = _flat_dir_to(get_lock_point())
			body.face_direction(_attack_dir)
		step = _attack_dir * a.lunge_speed
	_move(step, delta)

	if not _hit_active and _t >= windup and _t < windup + a.active_time:
		_hit_active = true
		var info := DamageInfo.new()
		info.amount = a.damage
		info.stagger = a.stagger
		info.knockback = a.knockback
		info.source = body
		info.attack_name = a.id
		hitbox.activate(info)
	elif _hit_active and _t >= windup + a.active_time:
		_hit_active = false
		hitbox.deactivate()

	var in_cancel := _t >= a.total_seconds() - a.cancel_window and _t >= windup + a.active_time
	if in_cancel:
		if _dodge_buffer > 0.0:
			hitbox.deactivate()
			_start_dodge(wish)
			return
		if _light_buffer > 0.0 and combo_index >= 0 and combo_index + 1 < config.light_combo.size():
			_start_attack(config.light_combo[combo_index + 1], combo_index + 1, wish)
			return
	if _t >= a.total_seconds():
		hitbox.deactivate()
		combo_index = 0
		_set_state(State.READY)


func _on_hit_landed(_hurtbox: Hurtbox, _info: DamageInfo) -> void:
	_hit_stop = config.hit_stop
	hit_stopped.emit(config.hit_stop)
	body.shake_camera(0.25)


# ---------------------------------------------------------------- dodge

func _start_dodge(wish: Vector3) -> void:
	_dodge_buffer = 0.0
	_light_buffer = 0.0
	_heavy_buffer = 0.0
	_t = 0.0
	var dir := Vector3(wish.x, 0.0, wish.z)
	# No stick input: roll backwards away from a locked target, else forward.
	if dir.length() < 0.2:
		dir = -_flat_dir_to(get_lock_point()) if lock_target else body.get_facing()
	_dodge_dir = dir.normalized()
	body.face_direction(_dodge_dir)
	_set_state(State.DODGE)
	dodge_started.emit(_dodge_dir)


func _update_dodge(delta: float) -> void:
	_t += delta
	var c := config
	health.invulnerable = _t >= c.iframe_start and _t <= c.iframe_end
	# Fast start, eased finish.
	var k := 1.0 - smoothstep(0.55, 1.0, _t / c.dodge_time)
	_move(_dodge_dir * c.dodge_speed * k, delta)
	if _t >= c.dodge_time:
		health.invulnerable = false
		_dodge_cooldown = c.dodge_cooldown
		_set_state(State.READY)


# ---------------------------------------------------------------- damage

func _on_damaged(info: DamageInfo) -> void:
	if state == State.DEAD or health.dead:
		return
	if hitbox:
		hitbox.deactivate()
	_hit_active = false
	_t = 0.0
	_knockback = info.push_direction(body.global_position) * info.knockback
	body.shake_camera(0.5)
	_set_state(State.HURT)
	hurt.emit(info)


func _on_died() -> void:
	if hitbox:
		hitbox.deactivate()
	_t = 0.0
	set_lock_target(null)
	_set_state(State.DEAD)
	player_died.emit()


func _on_body_respawned(_at: Vector3) -> void:
	if state == State.DEAD:
		health.reset()
		_set_state(State.READY)
		player_respawned.emit()


# ---------------------------------------------------------------- helpers

func _choose_direction(wish: Vector3) -> Vector3:
	if lock_target:
		return _flat_dir_to(get_lock_point())
	var flat := Vector3(wish.x, 0.0, wish.z)
	if flat.length() > 0.2:
		return flat.normalized()
	return body.get_facing()


func _flat_dir_to(point: Vector3) -> Vector3:
	var d := point - body.global_position
	d.y = 0.0
	return d.normalized() if d.length() > 0.01 else body.get_facing()


func _move(horizontal: Vector3, delta: float) -> void:
	body.velocity.x = horizontal.x
	body.velocity.z = horizontal.z
	if body.is_on_floor():
		body.velocity.y = -1.0
	else:
		body.velocity.y -= body.config.gravity * delta
	body.move_and_slide()


func _halt(delta: float) -> void:
	_move(Vector3.ZERO, delta)


func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	if state == State.DODGE and health:
		health.invulnerable = false
	state = new_state
	state_changed.emit(state)
