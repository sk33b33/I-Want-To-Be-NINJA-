class_name RecipeDefinition
extends Resource
## Forge recipe: materials in, one piece of gear out.

@export var id: StringName
@export var result: GearDefinition
## Materials consumed (ItemDefinition) and how many of each, in matching order.
@export var inputs: Array[ItemDefinition] = []
@export var counts: PackedInt32Array = PackedInt32Array()


func cost_of(item: ItemDefinition) -> int:
	var i := inputs.find(item)
	return counts[i] if i >= 0 and i < counts.size() else 0
