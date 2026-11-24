class_name JungleConditions
extends Resource
## Phase 13 part 4: which times of day and weathers a jungle can have (weighted), and whether the
## weather can turn during a hunt. data/conditions/<biome>.tres.

@export var biome_id: StringName
@export var times: Array[TimeOfDay] = []
@export var time_weights: PackedFloat32Array = PackedFloat32Array()
@export var weathers: Array[WeatherDefinition] = []
@export var weather_weights: PackedFloat32Array = PackedFloat32Array()
## Chance that the weather turns to `turn_to` during the hunt (only from a different weather).
@export_range(0.0, 1.0) var turn_chance: float = 0.0
@export var turn_to: WeatherDefinition
## Seconds into the hunt when it may turn (random in this range).
@export var turn_after: Vector2 = Vector2(240, 600)


static func _pick(items: Array, weights: PackedFloat32Array, rng: RandomNumberGenerator) -> Resource:
	if items.is_empty():
		return null
	var total := 0.0
	for i in items.size():
		total += weights[i] if i < weights.size() else 1.0
	var r := rng.randf() * total
	for i in items.size():
		r -= weights[i] if i < weights.size() else 1.0
		if r <= 0.0:
			return items[i]
	return items[-1]


## A forecast: {"time": TimeOfDay, "weather": WeatherDefinition, "turn": WeatherDefinition or null,
## "turn_at": seconds}.
func roll(rng: RandomNumberGenerator) -> Dictionary:
	var w := _pick(weathers, weather_weights, rng) as WeatherDefinition
	var turn: WeatherDefinition = null
	if turn_to and w != turn_to and rng.randf() < turn_chance:
		turn = turn_to
	return {"time": _pick(times, time_weights, rng), "weather": w, "turn": turn,
			"turn_at": rng.randf_range(turn_after.x, turn_after.y)}
