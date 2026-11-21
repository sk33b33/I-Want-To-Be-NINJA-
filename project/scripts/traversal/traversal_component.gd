class_name TraversalComponent
extends Node
## Ninja traversal on top of PlayerController (docs/PHASES.md Phase 2):
##   CLIMB  - on surfaces in the "climbable" physics layer: up/down/sideways, wall jump, drop.
##   HANG   - auto ledge grab on any solid ledge while airborne and pushing toward it.
##   MANTLE - scripted pull-up over a ledge (from HANG, or when a climb reaches the top).
## The controller calls physics_update() every tick; when it returns true this component owns
## the body's movement for that tick. All input arrives as actions, so touch/gamepad/keyboard
## behave the same (no extra buttons: climbing and grabbing are automatic).

signal state_changed(state: State)

enum State { NONE, CLIMB, HANG, MANTLE }

@export var config: TraversalConfig

var state: State = State.NONE
var body: PlayerController

var _wall_normal: Vector3 = Vector3.BACK
var _cooldown: float = 0.0
var _hang_time: float = 0.0
var _climb_velocity: Vector3 = Vector3.ZERO
var _mantle_from: Vector3
var _mantle_to: Vector3
var _mantle_t: float = 0.0


func _ready() -> void:
	body = get_parent() as PlayerController


## Returns true when traversal moved the body this tick.
func physics_update(delta: float, input: Vector2, wish: Vector3) -> bool:
	_cooldown -= delta
	match state:
		State.CLIMB:
			_update_climb(delta, input)
			return true
		State.HANG:
			_update_hang(delta, input)
			return true
		State.MANTLE:
			_update_mantle(delta)
			return true
	return _try_enter(wish)


## Cancel any traversal state (used on respawn).
func reset() -> void:
	_set_state(State.NONE)
	_cooldown = 0.0


func get_wall_normal() -> Vector3:
	return _wall_normal


## Current climbing velocity (for animation speed).
func get_climb_velocity() -> Vector3:
	return _climb_velocity


# ---------------------------------------------------------------- entering

func _try_enter(wish: Vector3) -> bool:
	if _cooldown > 0.0 or body.is_on_floor():
		return false
	var flat := Vector3(wish.x, 0.0, wish.z)
	if flat.length() < config.attach_input_threshold:
		return false
	var dir := flat.normalized()

	if body.velocity.y <= config.ledge_grab_max_up_speed:
		var ledge := _find_ledge(body.global_position, dir, config.ledge_min_above_feet, config.ledge_max_above_feet)
		if not ledge.is_empty():
			_start_hang(ledge)
			return true

	var chest := body.global_position + Vector3.UP * config.chest_height
	var hit := _ray(chest, chest + dir * (config.body_radius + config.reach), config.climbable_mask)
	if not hit.is_empty() and _is_wall(hit["normal"]):
		var n := _flat_normal(hit["normal"])
		if dir.dot(-n) > 0.5:
			_start_climb(hit["position"], n)
			return true
	return false


# ---------------------------------------------------------------- climbing

func _start_climb(point: Vector3, normal: Vector3) -> void:
	_wall_normal = normal
	var p := body.global_position
	var snap := point + normal * (config.body_radius + 0.05)
	body.global_position = Vector3(snap.x, p.y, snap.z)
	body.velocity = Vector3.ZERO
	body.face_direction(-normal)
	_set_state(State.CLIMB)


func _update_climb(delta: float, input: Vector2) -> void:
	var n := _wall_normal
	if body.consume_jump():
		if input.y > 0.5:
			_detach(n * 1.5)  # Back + jump: let go.
		else:
			_wall_jump(n)
		return

	var chest := body.global_position + Vector3.UP * config.chest_height
	var probe := config.body_radius + 0.6
	var chest_hit := _ray(chest, chest - n * probe, config.climbable_mask)
	if chest_hit.is_empty():
		# Chest is above the wall: pull up if there is a ledge, otherwise fall off.
		var ledge := _find_ledge(body.global_position, -n, 0.2, config.ledge_max_above_feet)
		if not ledge.is_empty():
			_start_mantle(ledge)
			return
		var knee := body.global_position + Vector3.UP * config.knee_height
		if _ray(knee, knee - n * probe, config.climbable_mask).is_empty():
			_detach(n * 0.5)
			return
	elif _is_wall(chest_hit["normal"]):
		n = _flat_normal(chest_hit["normal"])
		_wall_normal = n

	var right := (-n).cross(Vector3.UP).normalized()
	var side := input.x
	if absf(side) > 0.05:
		var side_probe := chest + right * signf(side) * (config.body_radius + 0.15)
		if _ray(side_probe, side_probe - n * probe, config.climbable_mask).is_empty():
			side = 0.0  # Edge of the climbable surface.
	var vertical := -input.y
	var up_speed := config.climb_up_speed if vertical > 0.0 else config.climb_down_speed
	_climb_velocity = right * side * config.climb_side_speed + Vector3.UP * vertical * up_speed
	body.velocity = _climb_velocity - n * config.wall_stick_speed
	body.move_and_slide()
	body.face_direction(-n)
	if vertical < 0.0 and body.is_on_floor():
		_detach(Vector3.ZERO)  # Climbed down to the ground.


func _wall_jump(n: Vector3) -> void:
	_set_state(State.NONE)
	_cooldown = config.regrab_cooldown
	body.velocity = n * config.wall_jump_push + Vector3.UP * config.wall_jump_up
	body.face_direction(n)
	body.notify_jumped()


func _detach(push: Vector3) -> void:
	_set_state(State.NONE)
	_cooldown = config.regrab_cooldown
	body.velocity = push
	body.clear_air_timers()


# ---------------------------------------------------------------- ledges

## Looks for a grabbable ledge in `dir` from `origin` (feet). Returns {} or
## {"top": edge point on the ledge top, "normal": outward wall normal, "wall": wall point}.
func _find_ledge(origin: Vector3, dir: Vector3, min_above: float, max_above: float) -> Dictionary:
	var ahead := origin + dir * (config.body_radius + 0.35)
	var down := _ray(ahead + Vector3.UP * (max_above + 0.1), ahead + Vector3.UP * (min_above - 0.05), config.world_mask)
	if down.is_empty() or (down["normal"] as Vector3).y < config.ledge_min_normal_y:
		return {}
	var top_y: float = (down["position"] as Vector3).y
	var probe_y := top_y - 0.12
	var from := Vector3(origin.x, probe_y, origin.z)
	var wall := _ray(from, from + dir * (config.body_radius + config.reach), config.world_mask)
	if wall.is_empty() or not _is_wall(wall["normal"]):
		return {}
	var n := _flat_normal(wall["normal"])
	var wall_point: Vector3 = wall["position"]
	var top := Vector3(wall_point.x, top_y, wall_point.z) - n * config.mantle_forward
	var head_from := top + Vector3.UP * 0.05
	if not _ray(head_from, head_from + Vector3.UP * config.ledge_headroom, config.world_mask).is_empty():
		return {}  # No room to stand on top.
	return {"top": top, "normal": n, "wall": wall_point}


func _start_hang(ledge: Dictionary) -> void:
	var n: Vector3 = ledge["normal"]
	var wall: Vector3 = ledge["wall"]
	var top: Vector3 = ledge["top"]
	_wall_normal = n
	var pos := wall + n * (config.body_radius + 0.02)
	body.global_position = Vector3(pos.x, top.y - config.hang_feet_below_ledge, pos.z)
	body.velocity = Vector3.ZERO
	body.face_direction(-n)
	_hang_time = 0.0
	_set_state(State.HANG)


func _update_hang(delta: float, input: Vector2) -> void:
	_hang_time += delta
	var n := _wall_normal
	var jump := body.consume_jump()
	if input.y > 0.5:
		if jump or _hang_time > 0.1:
			_detach(n * 1.0)  # Back (+ jump): drop.
		return
	if (jump or input.y < -0.5) and _hang_time > 0.12:
		var ledge := _find_ledge(body.global_position, -n, config.ledge_min_above_feet - 0.3, config.ledge_max_above_feet + 0.3)
		if not ledge.is_empty():
			_start_mantle(ledge)
		return
	if absf(input.x) > 0.2:
		# Shimmy along the ledge while it continues.
		var right := (-n).cross(Vector3.UP).normalized()
		var step := right * signf(input.x) * config.shimmy_speed * delta
		var probe_origin := body.global_position + step + right * signf(input.x) * config.body_radius
		var ledge := _find_ledge(probe_origin, -n, config.ledge_min_above_feet - 0.3, config.ledge_max_above_feet + 0.3)
		if not ledge.is_empty():
			body.global_position += step
	body.velocity = Vector3.ZERO


# ---------------------------------------------------------------- mantle

func _start_mantle(ledge: Dictionary) -> void:
	_wall_normal = ledge["normal"]
	_mantle_from = body.global_position
	_mantle_to = (ledge["top"] as Vector3) + Vector3.UP * 0.05
	_mantle_t = 0.0
	body.velocity = Vector3.ZERO
	body.face_direction(-_wall_normal)
	_set_state(State.MANTLE)


func _update_mantle(delta: float) -> void:
	_mantle_t = minf(_mantle_t + delta / config.mantle_time, 1.0)
	var rise := smoothstep(0.0, 0.65, _mantle_t)
	var over := smoothstep(0.45, 1.0, _mantle_t)
	var p := _mantle_from
	p.y = lerpf(_mantle_from.y, _mantle_to.y, rise)
	p.x = lerpf(_mantle_from.x, _mantle_to.x, over)
	p.z = lerpf(_mantle_from.z, _mantle_to.z, over)
	body.global_position = p
	body.velocity = Vector3.ZERO
	if _mantle_t >= 1.0:
		_set_state(State.NONE)
		_cooldown = config.regrab_cooldown
		body.clear_air_timers()


# ---------------------------------------------------------------- helpers

func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	if state != State.CLIMB:
		_climb_velocity = Vector3.ZERO
	state_changed.emit(state)


func _ray(from: Vector3, to: Vector3, mask: int) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, mask, [body.get_rid()])
	return body.get_world_3d().direct_space_state.intersect_ray(q)


func _is_wall(normal: Vector3) -> bool:
	return absf(normal.y) < config.wall_max_normal_y


func _flat_normal(normal: Vector3) -> Vector3:
	var n := Vector3(normal.x, 0.0, normal.z)
	return n.normalized() if n.length() > 0.001 else Vector3.BACK
