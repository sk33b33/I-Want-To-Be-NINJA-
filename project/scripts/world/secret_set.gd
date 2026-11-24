class_name SecretSet
extends Resource
## A jungle's hidden spirit shrines (data/secrets/<biome>.tres). Finding all of them grants the
## jungle's Shrine Blessing (permanent max health), applied at every expedition start.

const DIR := "res://data/secrets/"

@export var biome_id: StringName
@export var blessing_name: String = "Shrine Blessing"
@export var blessing_health: float = 10.0
@export var secrets: Array[SecretDefinition] = []
## Each relic found gives this item once.
@export var relic_item: ItemDefinition


func found_count(profile: PlayerProfile) -> int:
	var n := 0
	for s in secrets:
		if profile.has_secret(s.id):
			n += 1
	return n


func is_complete(profile: PlayerProfile) -> bool:
	return not secrets.is_empty() and found_count(profile) == secrets.size()


func find(secret_id: StringName) -> SecretDefinition:
	for s in secrets:
		if s.id == secret_id:
			return s
	return null


## Every jungle's set (sorted by file name).
static func all_sets() -> Array[SecretSet]:
	var out: Array[SecretSet] = []
	if not DirAccess.dir_exists_absolute(DIR):
		return out
	var files := Array(DirAccess.get_files_at(DIR))
	files.sort()
	for f: String in files:
		if f.ends_with(".tres"):
			var s := load(DIR + f) as SecretSet
			if s:
				out.append(s)
	return out


static func for_biome(biome_id: StringName) -> SecretSet:
	for s in all_sets():
		if s.biome_id == biome_id:
			return s
	return null


## Sum of the blessings of every completed jungle.
static func blessing_health_total(profile: PlayerProfile) -> float:
	var total := 0.0
	for s in all_sets():
		if s.is_complete(profile):
			total += s.blessing_health
	return total
