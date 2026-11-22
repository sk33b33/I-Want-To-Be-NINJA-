class_name BossController
extends CharacterBody3D
## Generic data-driven boss (docs/PHASES.md Phases 5 and 8). Every behaviour comes from
## BossDefinition / BossAttackDefinition / BossPartDefinition; a boss is "data + a scene".
## Every attack telegraphs before it can hurt (see BossAttackDefinition.counterplay).
##
## States: DORMANT --awaken--> INTRO --> STALK --pick attack--> TELEGRAPH --> ATTACK --> RECOVER
##         --> STALK ...;  poise broken --> STAGGER;  part breaks --> PART_BREAK;
##         dash hits a wall (stuns_on_wall) --> STUNNED;  health 0 --> DEFEATED (final).
## During RECOVER / STAGGER / STUNNED / PART_BREAK the head is lowered: head parts within reach.

signal awakened
signal state_changed(state: State)
signal attack_telegraphed(attack: BossAttackDefinition)
signal attack_started(attack: BossAttackDefinition)
signal part_broken(part: BossPartDefinition)
signal enraged
signal defeated

enum State { DORMANT, INTRO, STALK, TELEGRAPH, ATTACK, RECOVER, STAGGER, PART_BREAK, STUNNED, DEFEATED }

@export var definition: BossDefinition
## Difficulty: multiplies every telegraph (>= 1.0; DifficultyPreset.telegraph_multiplier).
var telegraph_scale: float = 1.0
## Seed for attack selection (deterministic tests); 0 = random.
@export var ai_seed: int = 0

var state: State = State.DORMANT
var current_attack: BossAttackDefinition
var is_enraged: bool = false
var arena_center: Vector3
## part id -> damage taken
var part_damage: Dictionary = {}
## part id -> true once broken (a part can only break, and reward, once)
var broken_parts: Dictionary = {}

var _health: HealthComponent
var _player: PlayerController
var _t: float = 0.0
var _state_length: float = 0.0
var _poise_damage: float = 0.0
var _cooldowns: Dictionary = {}
var _aim: Vector3 = Vector3.FORWARD
var _flash: float = 0.0
var _rng := RandomNumberGenerator.new()
var _pitch_target: float = 0.0
var _hitboxes: Array[Hitbox] = []
var _warnings: Array[GeometryInstance3D] = []
var _glow_meshes_body: Array[GeometryInstance3D] = []
var _glow_meshes_parts: Array[GeometryInstance3D] = []

@onready var _visual: Node3D = $Visual


func _ready() -> void:
	add_to_group("lock_targets")
	add_to_group("bosses")
	collision_layer = 8  # enemy
	# World only: the player is blocked by the boss (player mask includes enemies), but the boss
	# never treats the player as ground — otherwise it could stand on the ninja and ride along.
	collision_mask = 1
	platform_floor_layers = 1
	arena_center = global_position
	if ai_seed != 0:
		_rng.seed = ai_seed
	_health = $Health as HealthComponent
	_health.max_health = definition.max_health
	_health.reset()
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	for node in find_children("*", "Area3D", true, false):
		if node is Hurtbox:
			(node as Hurtbox).elements = definition.elements
			(node as Hurtbox).part_hit.connect(_on_part_hit)
		elif node is Hitbox:
			_hitboxes.append(node as Hitbox)
	var body := get_node_or_null(definition.body_mesh_node) as GeometryInstance3D
	if body:
		_glow_meshes_body.append(body)
	for part in definition.parts:
		var intact := get_node_or_null(part.intact_node) as GeometryInstance3D
		if intact:
			_glow_meshes_parts.append(intact)
		var broken := get_node_or_null(part.broken_node) as Node3D
		if broken:
			broken.visible = false
	for a in definition.attacks:
		var w := get_node_or_null(a.warning_node) as GeometryInstance3D
		if w and not _warnings.has(w):
			_warnings.append(w)
	_hide_warnings()


# ---------------------------------------------------------------- public API

func awaken() -> void:
	if state == State.DORMANT:
		_set_state(State.INTRO, definition.intro_time)
		awakened.emit()


func is_alive() -> bool:
	return state != State.DEFEATED


func get_lock_point() -> Vector3:
	var o := definition.lock_offset
	return global_position + global_basis.x * o.x + Vector3.UP * o.y + global_basis.z * o.z


func get_health() -> HealthComponent:
	return _health


func is_part_broken(part_id: StringName) -> bool:
	return broken_parts.has(part_id)


## Total telegraph seconds for an attack right now (shorter when enraged).
func telegraph_seconds(attack: BossAttackDefinition) -> float:
	return attack.telegraph_time * telegraph_scale * (definition.enrage_tempo if is_enraged else 1.0)


func state_time() -> float:
	return _t


## Debug/test hook: start telegraphing a specific attack right now (ignores range and cooldown).
func debug_force_attack(attack_id: StringName) -> void:
	var a := definition.get_attack(attack_id)
	if a and state != State.DEFEATED:
		if state == State.DORMANT:
			awaken()
		_start_telegraph(a)


# ---------------------------------------------------------------- main loop

func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as PlayerController
	_t += delta
	for k in _cooldowns.keys():
		_cooldowns[k] = float(_cooldowns[k]) - delta
	_flash = maxf(_flash - delta * 5.0, 0.0)
	for m in _glow_meshes_body + _glow_meshes_parts:
		m.set_instance_shader_parameter("hit_flash", _flash)

	var move := Vector3.ZERO
	match state:
		State.INTRO:
			_pitch_target = 0.35 * sin(clampf(_t / _state_length, 0.0, 1.0) * PI)  # Rearing roar.
			if _t >= _state_length:
				_set_state(State.STALK, definition.attack_interval)
		State.STALK:
			move = _stalk(delta)
		State.TELEGRAPH:
			_update_telegraph()
		State.ATTACK:
			move = _update_attack(delta)
		State.RECOVER, State.STAGGER, State.PART_BREAK, State.STUNNED:
			if _t >= _state_length:
				_set_state(State.STALK, _tempo(definition.attack_interval))
		State.DEFEATED:
			_visual.rotation.z = lerpf(_visual.rotation.z, deg_to_rad(80.0), 1.0 - exp(-2.0 * delta))
			_visual.position.y = lerpf(_visual.position.y, -0.6, 1.0 - exp(-1.5 * delta))
			return
	match state:
		State.RECOVER, State.STAGGER, State.STUNNED, State.PART_BREAK:
			_pitch_target = definition.head_down_pitch  # The opening.
		State.STALK, State.ATTACK, State.DORMANT:
			_pitch_target = 0.0
	_visual.rotation.x = lerpf(_visual.rotation.x, _pitch_target, 1.0 - exp(-8.0 * delta))
	velocity.x = move.x
	velocity.z = move.z
	velocity.y = -1.0 if is_on_floor() else velocity.y - 24.0 * delta
	move_and_slide()
	_keep_in_arena()
	if state == State.ATTACK and current_attack and current_attack.kind == BossAttackDefinition.Kind.DASH \
			and current_attack.stuns_on_wall and _t > 0.12 and _hit_a_wall():
		_deactivate_hitboxes()
		_set_state(State.STUNNED, current_attack.stun_time)


# ---------------------------------------------------------------- behaviour

func _player_in_arena() -> bool:
	return _player != null and _player.combat != null and _player.combat.state != PlayerCombat.State.DEAD \
			and _flat(_player.global_position - arena_center).length() < definition.arena_radius + 4.0


func _stalk(delta: float) -> Vector3:
	if not _player_in_arena():
		# The hunter left or fell: return to the centre and wait (no healing).
		return _walk_to(arena_center, 0.0)
	var to := _flat(_player.global_position - global_position)
	var dist := to.length()
	_face(to, definition.turn_sharpness * delta)
	if _t >= _state_length:
		var attack := _pick_attack(dist)
		if attack:
			_start_telegraph(attack)
			return Vector3.ZERO
	if dist > definition.stalk_distance + 1.0:
		return to.normalized() * definition.walk_speed
	if dist < definition.stalk_distance - 2.0:
		return -to.normalized() * definition.walk_speed * 0.4
	return Vector3.ZERO


func _pick_attack(dist: float) -> BossAttackDefinition:
	var valid: Array[BossAttackDefinition] = []
	var total := 0.0
	for a in definition.attacks:
		if a.enraged_only and not is_enraged:
			continue
		if float(_cooldowns.get(a.id, 0.0)) > 0.0:
			continue
		if dist < a.min_range or dist > a.max_range:
			continue
		valid.append(a)
		total += a.weight
	if valid.is_empty():
		return null
	var roll := _rng.randf() * total
	for a in valid:
		roll -= a.weight
		if roll <= 0.0:
			return a
	return valid.back()


func _start_telegraph(attack: BossAttackDefinition) -> void:
	current_attack = attack
	_cooldowns[attack.id] = attack.cooldown
	_aim = _flat(_player.global_position - global_position).normalized() if _player else -global_basis.z
	_set_state(State.TELEGRAPH, telegraph_seconds(attack))
	var w := get_node_or_null(attack.warning_node) as GeometryInstance3D
	if w:
		w.visible = true
	if attack.kind == BossAttackDefinition.Kind.ERUPTIONS:
		_spawn_eruptions(attack)
	attack_telegraphed.emit(attack)


func _update_telegraph() -> void:
	var a := current_attack
	var k := clampf(_t / _state_length, 0.0, 1.0)
	if a.tracks_player and _t < _state_length - 0.3 and _player:
		_aim = _flat(_player.global_position - global_position).normalized()
	_face(_aim, 0.25)
	var glow := smoothstep(0.0, 1.0, k)
	for w in _warnings:
		w.set_instance_shader_parameter("intensity", glow)
	match a.glow:
		BossAttackDefinition.Glow.BODY:
			_set_glow(_glow_meshes_body, glow)
		BossAttackDefinition.Glow.PARTS:
			_set_glow(_glow_meshes_parts, glow)
	_pitch_target = lerpf(0.0, a.telegraph_pitch, glow) + a.telegraph_wobble * sin(_t * 18.0)
	if _t >= _state_length:
		_begin_attack()


func _begin_attack() -> void:
	_hide_warnings()
	_set_glow(_glow_meshes_body, 0.0)
	_set_glow(_glow_meshes_parts, 0.0)
	var a := current_attack
	_set_state(State.ATTACK, a.active_time)
	var info := DamageInfo.new()
	info.amount = a.damage
	if a.weakened_by_part != &"" and is_part_broken(a.weakened_by_part):
		info.amount *= a.weakened_scale
	info.knockback = a.knockback
	info.stagger = 100.0
	info.element = a.element
	info.source = self
	info.attack_name = a.id
	var hb := get_node_or_null(a.hitbox_node) as Hitbox
	if hb:
		hb.activate(info)
	attack_started.emit(a)


func _update_attack(delta: float) -> Vector3:
	var a := current_attack
	var move := Vector3.ZERO
	if a.kind == BossAttackDefinition.Kind.DASH:
		if a.dash_homing > 0.0 and _player:
			var want := _flat(_player.global_position - global_position).normalized()
			_aim = _aim.slerp(want, clampf(a.dash_homing * delta, 0.0, 1.0)).normalized()
			_face(_aim, 0.5)
		move = _aim * a.move_speed
	if _t >= _state_length:
		_deactivate_hitboxes()
		_set_state(State.RECOVER, _tempo(a.recovery_time))
	return move


func _spawn_eruptions(attack: BossAttackDefinition) -> void:
	if attack.eruption_scene == null or _player == null:
		return
	var center := _player.global_position
	for o in attack.eruption_offsets:
		var e := attack.eruption_scene.instantiate() as RootSnare
		get_parent().add_child(e)
		e.global_position = Vector3(center.x + o.x, center.y, center.z + o.z)
		e.setup(self, telegraph_seconds(attack), attack.active_time, attack.damage, attack.knockback)


# ---------------------------------------------------------------- damage

func _on_damaged(info: DamageInfo) -> void:
	_flash = 1.0
	if state == State.DORMANT:
		awaken()
	if not is_enraged and _health.fraction() <= definition.enrage_at and _health.current > 0.0:
		is_enraged = true
		enraged.emit()
	if state == State.ATTACK or state == State.DEFEATED or state == State.PART_BREAK:
		return
	_poise_damage += info.stagger
	if _poise_damage >= definition.poise:
		_poise_damage = 0.0
		_interrupt()
		_set_state(State.STAGGER, definition.stagger_time)


func _on_part_hit(part_id: StringName, info: DamageInfo) -> void:
	if broken_parts.has(part_id) or state == State.DEFEATED:
		return
	var part := definition.get_part(part_id)
	if part == null:
		return
	part_damage[part_id] = float(part_damage.get(part_id, 0.0)) + info.amount
	if float(part_damage[part_id]) >= part.break_health:
		broken_parts[part_id] = true
		var intact := get_node_or_null(part.intact_node) as Node3D
		var broken := get_node_or_null(part.broken_node) as Node3D
		if intact:
			intact.visible = false
		if broken:
			broken.visible = true
		_interrupt()
		_set_state(State.PART_BREAK, part.break_stagger_time)
		part_broken.emit(part)


func _on_died() -> void:
	_interrupt()
	collision_layer = 0
	remove_from_group("lock_targets")
	_set_state(State.DEFEATED, definition.death_time)
	defeated.emit()


func _interrupt() -> void:
	_deactivate_hitboxes()
	_hide_warnings()
	_set_glow(_glow_meshes_body, 0.0)
	_set_glow(_glow_meshes_parts, 0.0)
	for e in get_tree().get_nodes_in_group("root_snares"):
		if (e as RootSnare).owner_boss == self:
			e.queue_free()


# ---------------------------------------------------------------- helpers

func _set_glow(meshes: Array[GeometryInstance3D], value: float) -> void:
	for m in meshes:
		m.set_instance_shader_parameter("spine_glow", value)


func _tempo(seconds: float) -> float:
	return seconds * (definition.enrage_tempo if is_enraged else 1.0)


func _walk_to(target: Vector3, stop: float) -> Vector3:
	var to := _flat(target - global_position)
	if to.length() <= stop + 0.5:
		return Vector3.ZERO
	_face(to, definition.turn_sharpness * get_physics_process_delta_time())
	return to.normalized() * definition.walk_speed


func _face(dir: Vector3, weight: float) -> void:
	if dir.length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(weight, 0.0, 1.0))


func _keep_in_arena() -> void:
	var off := _flat(global_position - arena_center)
	if off.length() > definition.arena_radius:
		var p := arena_center + off.normalized() * definition.arena_radius
		global_position = Vector3(p.x, global_position.y, p.z)


func _hit_a_wall() -> bool:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_collider() is PlayerController:
			continue
		if absf(c.get_normal().y) < 0.5:
			return true
	# The arena edge counts as a wall for dashes as well.
	return _flat(global_position - arena_center).length() >= definition.arena_radius - 0.05


func _deactivate_hitboxes() -> void:
	for hb in _hitboxes:
		hb.deactivate()


func _hide_warnings() -> void:
	for w in _warnings:
		w.visible = false


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _set_state(s: State, length: float = 0.0) -> void:
	state = s
	_t = 0.0
	_state_length = length
	state_changed.emit(s)
