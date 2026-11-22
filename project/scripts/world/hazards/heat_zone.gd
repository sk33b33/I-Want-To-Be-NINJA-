class_name HeatZone
extends Area3D
## Scorching ground: standing in it burns a little every tick. There is always a cooler way
## around (Emberwild route choice). Visual shimmer is a child mesh.

@export var damage_per_tick: float = 4.0
@export var tick_time: float = 0.5

var _inside: Array[PlayerController] = []
var _t: float = 0.0


func _ready() -> void:
	add_to_group("heat_zones")
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(func(b: Node3D) -> void:
		if b is PlayerController and not _inside.has(b):
			_inside.append(b))
	body_exited.connect(func(b: Node3D) -> void: _inside.erase(b))


func _physics_process(delta: float) -> void:
	if _inside.is_empty():
		_t = 0.0
		return
	_t += delta
	if _t < tick_time:
		return
	_t -= tick_time
	for p in _inside:
		if p.combat and p.combat.health and not p.combat.health.dead:
			var info := DamageInfo.new()
			info.amount = damage_per_tick
			info.element = &"fire"
			info.attack_name = &"heat"
			p.combat.health.apply_damage(info)
