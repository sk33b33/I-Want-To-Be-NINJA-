class_name DifficultyPreset
extends Resource
## One difficulty (Phase 12), as data: data/difficulty/<id>.tres. Applied by ExpeditionManager
## when an expedition starts. Deliberately has NO timer field: every difficulty keeps the
## 45-minute minimum countdown (tests enforce it).

@export var id: StringName = &"normal"
@export var display_name: String = "Normal"
@export var description: String = ""
## Multiplies all damage the hunter takes (bosses, enemies, hazards).
@export var damage_taken_multiplier: float = 1.0
## Multiplies boss health.
@export var boss_health_multiplier: float = 1.0
## Multiplies boss telegraph (warning) time. Never below 1.0: harder never means less warning.
@export_range(1.0, 2.0, 0.05) var telegraph_multiplier: float = 1.0
