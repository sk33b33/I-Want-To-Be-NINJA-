class_name LoreStone
extends Area3D
## A carved tablet: walking close shows its text once on the HUD (lore shrines, GDD sandbox systems).

signal read(title: String)

@export var title: String = ""
@export_multiline var text: String = ""

var was_read: bool = false


func _ready() -> void:
	add_to_group("lore_stones")
	_snap.call_deferred()
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(func(body: Node3D) -> void:
		if was_read or not body is PlayerController:
			return
		was_read = true
		var display := get_tree().get_first_node_in_group("lore_display")
		if display and display.has_method("show_lore"):
			display.show_lore(title, text)
		read.emit(title))


func _snap() -> void:
	var from := global_position + Vector3.UP * 6.0
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 30.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		global_position = hit["position"]
