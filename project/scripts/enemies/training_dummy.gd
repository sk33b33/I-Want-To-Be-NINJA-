class_name TrainingDummy
extends StaticBody3D
## Practice post at the spawn clearing: takes hits, wobbles, shows damage, never dies (heals
## after a few seconds without being hit). Lock-on works on it.

@export var reset_after: float = 4.0

var total_damage: float = 0.0
var hits: int = 0

var _health: HealthComponent
var _visual: Node3D
var _wobble: float = 0.0
var _wobble_dir: Vector3 = Vector3.RIGHT
var _idle: float = 0.0


func _ready() -> void:
	add_to_group("lock_targets")
	_health = $Health as HealthComponent
	_health.damaged.connect(_on_damaged)
	_visual = $Visual as Node3D


func is_alive() -> bool:
	return true


func get_lock_point() -> Vector3:
	return global_position + Vector3.UP * 1.2


func _process(delta: float) -> void:
	_idle += delta
	if _idle > reset_after and _health.current < _health.max_health:
		_health.reset()
	_wobble = move_toward(_wobble, 0.0, delta * 2.5)
	var tilt := sin(Time.get_ticks_msec() / 1000.0 * 18.0) * _wobble * 0.25
	_visual.rotation = Vector3(_wobble_dir.z * tilt, 0, -_wobble_dir.x * tilt)


func _on_damaged(info: DamageInfo) -> void:
	hits += 1
	total_damage += info.amount
	_idle = 0.0
	_wobble = 1.0
	var d := info.push_direction(global_position)
	_wobble_dir = d if d != Vector3.ZERO else Vector3.RIGHT
	if _health.current <= 1.0:
		_health.reset()
