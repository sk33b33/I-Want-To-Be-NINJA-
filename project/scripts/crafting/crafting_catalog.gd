class_name CraftingCatalog
extends Resource
## Everything the forge knows: recipes (and through them, gear) plus item names for display.

@export var recipes: Array[RecipeDefinition] = []
@export var items: Array[ItemDefinition] = []


func find_gear(gear_id: StringName) -> GearDefinition:
	for r in recipes:
		if r.result and r.result.id == gear_id:
			return r.result
	return null


func find_item(item_id: StringName) -> ItemDefinition:
	for it in items:
		if it.id == item_id:
			return it
	return null
