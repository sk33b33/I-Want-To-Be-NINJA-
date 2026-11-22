class_name FireTalisman
extends Node3D
## Ember Talisman projectile: a thrown paper charm that bursts into fire on the first enemy it
## touches (fire element: Kurogale is weak to it). Stops at walls/terrain; expires after `lifetime`.

@export var speed: float = 22.0
@export var lifetime: float = 1.2

var direction: Vector3 = Vector3.FORWARD
var _t: float = 0.0
var _info: DamageInfo
var _done: bool = false

@onready var _hitbox: Hitbox = $Hitbox


func launch(from: Vector3, dir: Vector3, info: DamageInfo) -> void:
	global_position = from
	direction = dir.normalized()
	_info = info
	_info.element = &"fire"
	_hitbox.hit_landed.connect(func(_h: Hurtbox, _i: DamageInfo) -> void: _burst())
	_hitbox.activate(_info)


func _physics_process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var step := direction * speed * delta
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + step, 1)
	if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		_burst()
		return
	global_position += step
	if _t >= lifetime:
		_burst()


func _burst() -> void:
	if _done:
		return
	_done = true
	_hitbox.deactivate()
	var fx := get_tree().get_first_node_in_group("combat_fx")
	if fx and fx.has_method("spawn_burst"):
		fx.spawn_burst(global_position, Color(1.0, 0.5, 0.1))
	queue_free()
