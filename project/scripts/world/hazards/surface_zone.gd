class_name SurfaceZone
extends Area3D
## Ground that changes how the hunter moves while they stand in it (Moonfen, Phase 9):
## mud (slow, no jumping), poison pools (damage over time) and stream currents (push sideways).
## The PlayerController asks its active zones for the combined effect each frame, so the
## movement code never needs to know what kind of ground it is.

## Multiplies run/sprint speed (mud 0.45; 1.0 = no slow).
@export var speed_multiplier: float = 1.0
## Mud: the feet are stuck, jumping is impossible until you wade out.
@export var blocks_jump: bool = false
## World-space push in m/s (a stream current). Applied on the ground and in the air.
@export var current: Vector3 = Vector3.ZERO
## Grip on the ground (Stormcrag rain-slick stone 0.35): scales how fast you speed up and stop.
@export var traction: float = 1.0
@export var damage_per_tick: float = 0.0
@export var tick_time: float = 0.5
@export var element: StringName = &""
@export var attack_name: StringName = &"surface"

var _inside: Array[PlayerController] = []
var _t: float = 0.0


func _ready() -> void:
	add_to_group("surface_zones")
	collision_layer = 0
	collision_mask = 2  # player
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)


func _on_entered(b: Node3D) -> void:
	var p := b as PlayerController
	if p and not _inside.has(p):
		_inside.append(p)
		p.add_surface_zone(self)


func _on_exited(b: Node3D) -> void:
	var p := b as PlayerController
	if p:
		_inside.erase(p)
		p.remove_surface_zone(self)


func _exit_tree() -> void:
	for p in _inside:
		if is_instance_valid(p):
			p.remove_surface_zone(self)
	_inside.clear()


func has_player(p: PlayerController) -> bool:
	return _inside.has(p)


func _physics_process(delta: float) -> void:
	if damage_per_tick <= 0.0 or _inside.is_empty():
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
			info.element = element
			info.attack_name = attack_name
			p.combat.health.apply_damage(info)
