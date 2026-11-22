class_name StormShelter
extends Area3D
## The space under a rock overhang: StormCaller never targets (or hits) a hunter standing here.


func _ready() -> void:
	add_to_group("storm_shelters")
	collision_layer = 0
	collision_mask = 2
