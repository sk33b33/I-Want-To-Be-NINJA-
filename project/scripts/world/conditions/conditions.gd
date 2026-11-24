class_name Conditions
extends RefCounted
## Phase 13 part 4: forecasts. The hunt board rolls one per jungle (shown on its card) and hands
## the chosen one to the expedition (`pending`); expeditions started any other way (tests, the
## benchmark) get none and keep the jungle's plain mood. GameSettings.varied_conditions off =
## always a clear day.

const DIR := "res://data/conditions/"

static var forecasts: Dictionary = {}  # biome_id -> forecast Dictionary
static var pending: Dictionary = {}
static var _rng := RandomNumberGenerator.new()


static func for_biome(biome_id: StringName) -> JungleConditions:
	var p := DIR + String(biome_id) + ".tres"
	return load(p) as JungleConditions if ResourceLoader.exists(p) else null


## The forecast shown for a jungle until it is hunted (then a new one is rolled).
static func forecast_for(biome_id: StringName) -> Dictionary:
	if not GameSettings.varied_conditions:
		return clear_day()
	if not forecasts.has(biome_id):
		var jc := for_biome(biome_id)
		forecasts[biome_id] = jc.roll(_rng) if jc else clear_day()
	return forecasts[biome_id]


static func clear_day() -> Dictionary:
	return {"time": load(DIR + "time_day.tres"), "weather": load(DIR + "weather_clear.tres"), "turn": null, "turn_at": 0.0}


## Called by the hunt board when an expedition begins.
static func begin(biome_id: StringName) -> void:
	pending = forecast_for(biome_id)
	forecasts.erase(biome_id)  # Next visit, a new forecast.


## Called once by the expedition at load.
static func take_pending() -> Dictionary:
	var p := pending
	pending = {}
	return p


static func describe(f: Dictionary) -> String:
	if f.is_empty():
		return ""
	var t := (f["time"] as TimeOfDay).display_name if f.get("time") else "Day"
	var w := (f["weather"] as WeatherDefinition).display_name if f.get("weather") else "Clear"
	var s := "%s · %s" % [t, w]
	if f.get("turn"):
		s += " (may turn to %s)" % (f["turn"] as WeatherDefinition).display_name
	return s
