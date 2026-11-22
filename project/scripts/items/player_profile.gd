class_name PlayerProfile
extends RefCounted
## The player's persistent materials (and later gear). Saved as JSON in user://.
## Not a singleton: load it where needed, change it, save it. Tests point `path` elsewhere.
## Saving is crash-safe (Phase 12): write `<path>.tmp`, keep the previous good file as
## `<path>.bak`, then move the temp file into place. Loading checks every field's type; a file
## that cannot be read is set aside as `<path>.corrupt` and the backup is loaded instead.

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
	if not FileAccess.file_exists(path):
		var from_backup := _read(path + ".bak")
		return from_backup if from_backup else PlayerProfile.new()
	var p := _read(path)
	if p:
		return p
	# Unreadable (torn write, disk error, hand edit): keep it for inspection, use the backup.
	DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".corrupt"))
	push_warning("PlayerProfile: %s was unreadable; moved to .corrupt and loaded the backup" % path)
	var backup := _read(path + ".bak")
	return backup if backup else PlayerProfile.new()


## Parse one save file; null if it is missing or not a valid profile.
static func _read(file_path: String) -> PlayerProfile:
	if not FileAccess.file_exists(file_path):
		return null
	var f := FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		return null
	var data: Variant = JSON.parse_string(f.get_as_text())
	if not data is Dictionary:
		return null
	var d := data as Dictionary
	var p := PlayerProfile.new()
	p.materials = _dict(d.get("materials"))
	p.hunts_completed = _dict(d.get("hunts_completed"))
	var owned: Variant = d.get("gear_owned")
	p.gear_owned = (owned as Array).filter(func(v: Variant) -> bool: return v is String) if owned is Array else []
	p.equipped = _dict(d.get("equipped"))
	return p


static func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


func save() -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"version": VERSION, "materials": materials, "hunts_completed": hunts_completed,
			"gear_owned": gear_owned, "equipped": equipped}, "  "))
	f.close()
	var real := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path) and _read(path) != null:
		DirAccess.copy_absolute(real, real + ".bak")  # Last good save.
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), real) == OK


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
