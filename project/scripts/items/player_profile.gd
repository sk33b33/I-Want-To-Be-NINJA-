class_name PlayerProfile
extends RefCounted
## The player's persistent materials (and later gear). Saved as JSON in user://.
## Not a singleton: load it where needed, change it, save it. Tests point `path` elsewhere.

const DEFAULT_PATH := "user://profile.json"
const VERSION := 1

static var path: String = DEFAULT_PATH

## item id (String) -> count
var materials: Dictionary = {}
var hunts_completed: Dictionary = {}


static func load_profile() -> PlayerProfile:
	var p := PlayerProfile.new()
	if not FileAccess.file_exists(path):
		return p
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return p
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		p.materials = (data as Dictionary).get("materials", {})
		p.hunts_completed = (data as Dictionary).get("hunts_completed", {})
	return p


func save() -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"version": VERSION, "materials": materials, "hunts_completed": hunts_completed}, "  "))
	return true


func add_material(id: StringName, count: int = 1) -> void:
	var key := String(id)
	materials[key] = int(materials.get(key, 0)) + count


func count(id: StringName) -> int:
	return int(materials.get(String(id), 0))


func record_hunt(hunt_id: StringName) -> void:
	var key := String(hunt_id)
	hunts_completed[key] = int(hunts_completed.get(key, 0)) + 1
