class_name PlayerProfile
extends RefCounted
## The player's persistent materials (and later gear). Saved as JSON in user://.
## Not a singleton: load it where needed, change it, save it. Tests point `path` elsewhere.

const DEFAULT_PATH := "user://profile.json"
const VERSION := 2  # v2 (Phase 7) adds gear_owned / equipped; v1 files still load.

static var path: String = DEFAULT_PATH

## item id (String) -> count
var materials: Dictionary = {}
var hunts_completed: Dictionary = {}
## Gear ids the player has forged.
var gear_owned: Array = []
## Slot name ("Weapon"/"Armor"/"Charm") -> gear id.
var equipped: Dictionary = {}


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
		p.gear_owned = (data as Dictionary).get("gear_owned", [])
		p.equipped = (data as Dictionary).get("equipped", {})
	return p


func save() -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"version": VERSION, "materials": materials, "hunts_completed": hunts_completed,
			"gear_owned": gear_owned, "equipped": equipped}, "  "))
	return true


func add_material(id: StringName, count: int = 1) -> void:
	var key := String(id)
	materials[key] = maxi(int(materials.get(key, 0)) + count, 0)
	if int(materials[key]) == 0:
		materials.erase(key)


func owns(gear_id: StringName) -> bool:
	return gear_owned.has(String(gear_id))


func equipped_id(slot_name: String) -> StringName:
	return StringName(equipped.get(slot_name, ""))


func count(id: StringName) -> int:
	return int(materials.get(String(id), 0))


func record_hunt(hunt_id: StringName) -> void:
	var key := String(hunt_id)
	hunts_completed[key] = int(hunts_completed.get(key, 0)) + 1
