class_name Pickup
extends Area3D
## A gatherable material on an optional path (docs/GAME_DESIGN.md "Optional side paths reward
## supplies, lore, or crafting resources"). Touch to collect; the ExpeditionManager records it.

signal collected(item: ItemDefinition, count: int)

@export var item: ItemDefinition
@export var count: int = 1
## Drop onto the ground below when the level loads (off for pickups placed on ledges/bridges).
@export var snap_to_ground: bool = true

var taken: bool = false
var _t: float = 0.0
var _base_y: float = 0.0

@onready var _visual: Node3D = $Visual


func _ready() -> void:
	add_to_group("pickups")
	collision_layer = 0
	collision_mask = 2  # player
	body_entered.connect(_on_body_entered)
	if snap_to_ground:
		_snap.call_deferred()
	_t = randf() * TAU


func _snap() -> void:
	var from := global_position + Vector3.UP * 6.0
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 30.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		global_position = (hit["position"] as Vector3) + Vector3.UP * 0.05


func _process(delta: float) -> void:
	if taken:
		_visual.scale = _visual.scale.move_toward(Vector3.ZERO, delta * 4.0)
		if _visual.scale.length() < 0.01:
			queue_free()
		return
	_t += delta
	_visual.rotation.y += delta * 0.8
	_visual.position.y = 0.25 + sin(_t * 2.0) * 0.08


func _on_body_entered(body: Node3D) -> void:
	if taken or not body is PlayerController:
		return
	taken = true
	var manager := get_tree().get_first_node_in_group("expedition") as ExpeditionManager
	if manager:
		manager.collect(item, count)
	collected.emit(item, count)
