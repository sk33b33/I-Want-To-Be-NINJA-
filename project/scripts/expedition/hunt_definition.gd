class_name HuntDefinition
extends Resource
## One huntable beast on the hunt board. Combat stats arrive with the boss in Phase 5.

@export var id: StringName
@export var beast_name: String = ""
@export var epithet: String = ""
@export var element: String = ""
@export var weakness: String = ""
@export_multiline var description: String = ""
## Signature attacks, shown on the hunt board as a hint.
@export var signature: String = ""
@export var config: ExpeditionConfig


func full_name() -> String:
	return beast_name if epithet == "" else "%s, %s" % [beast_name, epithet]
