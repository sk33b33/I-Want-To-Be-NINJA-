extends SceneTree
## Phase 13 part 4: times of day, weathers and each jungle's weighted table
## (data/conditions/*.tres). Colours multiply the jungle's JungleMood. Night stays readable:
## blue moonlight, exposure kept up. Tune the data files freely; re-running overwrites them.
##   godot --headless --path project -s ../tools/generate_conditions.gd

const TIMES := {
	"day": {"display_name": "Day"},
	"dawn": {"display_name": "Dawn", "sun_elevation": 12.0, "sun_turn": 70.0, "sun_color": Color(1.25, 0.85, 0.7),
		"sun_energy": 0.9, "ambient_color": Color(1.05, 0.95, 1.0), "fog_color": Color(1.3, 1.05, 1.0),
		"sky_zenith": Color(1.0, 0.9, 1.1), "sky_horizon": Color(1.6, 1.15, 1.0), "sky_glow": Color(1.6, 1.1, 0.8)},
	"dusk": {"display_name": "Dusk", "sun_elevation": 9.0, "sun_turn": -70.0, "sun_color": Color(1.35, 0.7, 0.45),
		"sun_energy": 0.95, "ambient_color": Color(1.05, 0.9, 0.95), "fog_color": Color(1.35, 0.95, 0.8),
		"sky_zenith": Color(0.9, 0.75, 1.0), "sky_horizon": Color(1.8, 1.0, 0.7), "sky_glow": Color(1.9, 0.9, 0.6)},
	"night": {"display_name": "Night", "sun_elevation": 35.0, "sun_turn": 160.0, "sun_color": Color(0.65, 0.8, 1.35),
		"sun_energy": 0.8, "ambient_color": Color(0.8, 0.9, 1.25), "exposure": 1.1, "fog_color": Color(0.7, 0.8, 1.15),
		"sky_zenith": Color(0.55, 0.6, 0.9), "sky_horizon": Color(0.6, 0.7, 1.0), "sky_glow": Color(0.6, 0.7, 1.2)},
}
const WEATHERS := {
	"clear": {"display_name": "Clear", "fog_density": 0.85},
	"mist": {"display_name": "Mist", "fog_density": 1.9, "fog_height_density": 2.0, "fog_color": Color(1.15, 1.15, 1.15), "wetness": 0.2},
	"rain": {"display_name": "Rain", "fog_density": 1.3, "rain": 0.8, "wetness": 0.8, "wind": 1.6, "sky": 0.8},
	"storm": {"display_name": "Storm", "fog_density": 1.45, "rain": 1.0, "wetness": 1.0, "wind": 2.4, "sky": 0.65,
		"lightning_interval": Vector2(4.0, 10.0)},
	"ashfall": {"display_name": "Ash haze", "fog_density": 1.7, "fog_height_density": 1.6, "fog_color": Color(1.2, 1.1, 1.05), "wind": 1.3},
}
## biome: [times {id: weight}, weathers {id: weight}, turn_chance, turn_to]
const JUNGLES := {
	"verdant_canopy": [{"day": 3, "dawn": 2, "dusk": 2, "night": 1}, {"clear": 3, "mist": 2, "rain": 2}, 0.35, "rain"],
	"emberwild": [{"day": 3, "dusk": 2, "night": 2}, {"clear": 3, "ashfall": 3}, 0.3, "ashfall"],
	"moonfen": [{"night": 3, "dusk": 2, "dawn": 1}, {"mist": 3, "clear": 2, "rain": 1}, 0.3, "rain"],
	"stormcrag": [{"day": 2, "dusk": 2, "night": 1}, {"rain": 3, "storm": 2, "mist": 1}, 0.4, "storm"],
}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/conditions"))
	for id: String in TIMES:
		var t := TimeOfDay.new()
		t.id = StringName(id)
		for k: String in TIMES[id]:
			t.set(k, TIMES[id][k])
		ResourceSaver.save(t, "res://data/conditions/time_%s.tres" % id)
	for id: String in WEATHERS:
		var w := WeatherDefinition.new()
		w.id = StringName(id)
		for k: String in WEATHERS[id]:
			w.set(k, WEATHERS[id][k])
		ResourceSaver.save(w, "res://data/conditions/weather_%s.tres" % id)
	for biome: String in JUNGLES:
		var row: Array = JUNGLES[biome]
		var jc := JungleConditions.new()
		jc.biome_id = StringName(biome)
		var tw := PackedFloat32Array()
		for id: String in row[0]:
			jc.times.append(load("res://data/conditions/time_%s.tres" % id))
			tw.append(float(row[0][id]))
		jc.time_weights = tw
		var ww := PackedFloat32Array()
		for id: String in row[1]:
			jc.weathers.append(load("res://data/conditions/weather_%s.tres" % id))
			ww.append(float(row[1][id]))
		jc.weather_weights = ww
		jc.turn_chance = row[2]
		jc.turn_to = load("res://data/conditions/weather_%s.tres" % row[3])
		ResourceSaver.save(jc, "res://data/conditions/%s.tres" % biome)
		print("conditions ", biome)
	quit()
