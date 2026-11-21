extends Node
## Phase 0 gate: an empty scene that boots, prints BOOT_OK and quits.
## Run: godot --headless --path project res://scenes/tests/boot_test.tscn


func _ready() -> void:
	print("BOOT_OK Godot %s" % Engine.get_version_info()["string"])
	get_tree().quit.call_deferred(0)
