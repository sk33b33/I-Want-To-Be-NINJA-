class_name Hurtbox
extends Area3D
## Where something can be hit. Routes hits to a HealthComponent (and, from Phase 5, to a
## breakable part via `part_id`). Lives on physics layer 6 "hurtbox".

signal hit_received(info: DamageInfo)
## Emitted when a hit arrives during invulnerability (e.g. a perfectly timed dodge).
signal hit_evaded(info: DamageInfo)
## Emitted for hurtboxes with a part_id after the hit lands (Phase 5 part breaks).
signal part_hit(part_id: StringName, info: DamageInfo)

@export var team: StringName = &"enemy"
@export var health_path: NodePath
## Breakable part this hurtbox belongs to (Phase 5). Empty = main body.
@export var part_id: StringName = &""
## Optional elemental weaknesses/resistances of the owner.
@export var elements: ElementProfile

var health: HealthComponent


func _ready() -> void:
	collision_layer = 32  # layer 6: hurtbox
	collision_mask = 0
	monitoring = false
	monitorable = true
	health = get_node_or_null(health_path) as HealthComponent


## Called by a Hitbox. Returns true when the hit landed.
func receive(info: DamageInfo) -> bool:
	if health == null or health.dead:
		return false
	info.hit_position = global_position
	if health.invulnerable:
		hit_evaded.emit(info)
		return false
	if elements:
		info.amount *= elements.multiplier(info.element)
	if not health.apply_damage(info):
		return false
	hit_received.emit(info)
	if part_id != &"":
		part_hit.emit(part_id, info)
	var fx := get_tree().get_first_node_in_group("combat_fx")
	if fx and fx.has_method("spawn_hit"):
		fx.spawn_hit(global_position + Vector3.UP * 0.3, info.amount, team == &"player")
	return true
