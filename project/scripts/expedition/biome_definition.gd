class_name BiomeDefinition
extends Resource
## A jungle region on the hunt board (docs/GAME_DESIGN.md "Biomes"), with its hunts.

@export var id: StringName
@export var display_name: String = ""
@export var mood: String = ""
## Scene played for this biome's expeditions (must contain an ExpeditionManager).
@export_file("*.tscn") var expedition_scene: String = ""
@export var hunts: Array[HuntDefinition] = []
@export var unlocked: bool = false
## Shown on locked biomes, e.g. "Arrives in Phase 8".
@export var locked_note: String = ""
## Card accent colour on the hunt board.
@export var accent: Color = Color(0.3, 0.8, 0.7)
