class_name ItemDefinition
extends Resource
## A crafting material or trophy (boss parts, hides...). Recipes arrive in Phase 7.

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var color: Color = Color(0.8, 0.8, 0.7)
@export_enum("Common", "Uncommon", "Rare") var rarity: int = 0
