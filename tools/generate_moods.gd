extends SceneTree
## Art pass stage 3: writes data/mood/<jungle>.tres (JungleMood) — lighting, fog, grade, light
## shafts and water per jungle, graded toward docs/concept-art/. Hand-tune the .tres files freely;
## re-running this tool overwrites them.
##   godot --headless --path project -s ../tools/generate_moods.gd

const MOODS := {
	# Golden back-light through teal mist, turquoise water (concept: verdant_canopy.jpg).
	"verdant_canopy": {"sun_color": Color(1.0, 0.8, 0.55), "sun_energy": 1.5,
		"ambient_color": Color(0.2, 0.3, 0.3), "ambient_energy": 4.3, "exposure": 1.5,
		"fog_color": Color(0.22, 0.28, 0.26), "fog_density": 0.014, "fog_sky_affect": 0.3,
		"fog_height": 0.5, "fog_height_density": 0.06, "fog_sun_scatter": 0.2,
		"saturation": 1.05, "contrast": 1.15, "shadow_tint": Color(0.0, 0.035, 0.045), "highlight_tint": Color(1.0, 0.96, 0.86),
		"shaft_color": Color(1.0, 0.8, 0.45), "shaft_strength": 0.09, "shaft_width": 4.5,
		"water_shallow": Color(0.1, 0.45, 0.42), "water_deep": Color(0.01, 0.1, 0.12)},
	# Ash haze cut by orange fire (concept: emberwild.jpg).
	"emberwild": {"sun_color": Color(1.0, 0.6, 0.4), "sun_energy": 1.1,
		"ambient_color": Color(0.3, 0.22, 0.2), "ambient_energy": 3.6, "exposure": 1.45,
		"fog_color": Color(0.3, 0.25, 0.23), "fog_density": 0.02, "fog_sky_affect": 0.4,
		"fog_height": 0.0, "fog_height_density": 0.05, "fog_sun_scatter": 0.15,
		"saturation": 1.0, "contrast": 1.18, "shadow_tint": Color(0.03, 0.02, 0.03), "highlight_tint": Color(1.0, 0.88, 0.75),
		"shaft_color": Color(1.0, 0.5, 0.2), "shaft_strength": 0.05, "shaft_width": 3.0,
		"water_shallow": Color(0.16, 0.12, 0.08), "water_deep": Color(0.07, 0.05, 0.035)},
	# Deep blue with magenta/cyan glow (concept: moonfen.jpg).
	"moonfen": {"sun_color": Color(0.6, 0.6, 1.0), "sun_energy": 1.0,
		"ambient_color": Color(0.19, 0.18, 0.36), "ambient_energy": 4.0, "exposure": 1.5,
		"fog_color": Color(0.2, 0.12, 0.32), "fog_density": 0.02, "fog_sky_affect": 0.4,
		"fog_height": 0.5, "fog_height_density": 0.08, "fog_sun_scatter": 0.1,
		"saturation": 1.1, "contrast": 1.15, "shadow_tint": Color(0.01, 0.02, 0.06), "highlight_tint": Color(1.0, 0.88, 0.98),
		"shaft_color": Color(0.6, 0.4, 1.0), "shaft_strength": 0.05, "shaft_width": 3.0,
		"water_shallow": Color(0.14, 0.1, 0.32), "water_deep": Color(0.025, 0.02, 0.06)},
	# Slate storm light, greener jungle, turquoise water (concept: stormcrag.jpg).
	"stormcrag": {"sun_color": Color(0.75, 0.85, 1.0), "sun_energy": 1.3,
		"ambient_color": Color(0.22, 0.28, 0.3), "ambient_energy": 4.2, "exposure": 1.5,
		"fog_color": Color(0.24, 0.28, 0.32), "fog_density": 0.02, "fog_sky_affect": 0.5,
		"fog_height": 0.0, "fog_height_density": 0.05, "fog_sun_scatter": 0.05,
		"saturation": 1.0, "contrast": 1.18, "shadow_tint": Color(0.0, 0.03, 0.04), "highlight_tint": Color(0.95, 1.0, 1.0),
		"shaft_color": Color(0.7, 0.85, 1.0), "shaft_strength": 0.04, "shaft_width": 3.0,
		"water_shallow": Color(0.1, 0.4, 0.42), "water_deep": Color(0.02, 0.08, 0.1)},
}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/mood"))
	for id: String in MOODS:
		var m := JungleMood.new()
		for k: String in MOODS[id]:
			m.set(k, MOODS[id][k])
		ResourceSaver.save(m, "res://data/mood/%s.tres" % id)
		print("mood ", id)
	quit()
