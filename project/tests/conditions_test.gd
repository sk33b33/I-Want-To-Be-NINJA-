extends TestCase
## Phase 13 part 4 (day/night & weather): data, what a forecast changes, that nothing changes
## without one, that the sky is written only at load (Mali crash rule), the stepped mid-hunt
## weather turn, the hunt-board forecast reaching the expedition, and the "always clear" setting.

const VERDANT := "res://scenes/main/main.tscn"


func _forecast(time_id: String, weather_id: String, turn_id: String = "", turn_at: float = 0.0) -> Dictionary:
	return {"time": load("res://data/conditions/time_%s.tres" % time_id),
			"weather": load("res://data/conditions/weather_%s.tres" % weather_id),
			"turn": load("res://data/conditions/weather_%s.tres" % turn_id) if turn_id != "" else null, "turn_at": turn_at}


func _start(f: Dictionary, scene: String = VERDANT) -> Node:
	PlayerProfile.path = "user://test_profile_conditions.json"
	Conditions.pending = f
	return instantiate(scene)


func _done() -> void:
	PlayerProfile.path = PlayerProfile.DEFAULT_PATH
	Conditions.pending = {}
	Conditions.forecasts.clear()
	QualityProfile.force_tier(&"")


func test_every_jungle_has_varied_readable_conditions() -> void:
	for biome in [&"verdant_canopy", &"emberwild", &"moonfen", &"stormcrag"]:
		var jc := Conditions.for_biome(biome)
		check(jc != null and jc.times.size() >= 2 and jc.weathers.size() >= 2, "%s has several times and weathers" % biome)
		for t in jc.times:
			check(t.exposure >= 1.0 and t.ambient_energy >= 1.0, "%s %s never darkens the picture" % [biome, t.id])
		if biome == &"emberwild":
			check(jc.weathers.all(func(w: WeatherDefinition) -> bool: return w.rain == 0.0) and jc.turn_to.rain == 0.0, "it never rains on the lava jungle")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seen := {}
	for i in 60:
		var f := Conditions.for_biome(&"verdant_canopy").roll(rng)
		seen[(f["time"] as TimeOfDay).id] = true
	check(seen.size() >= 3, "rolls give a variety of times (%s)" % seen.keys())


func test_no_forecast_keeps_the_plain_mood_and_resets_the_weather() -> void:
	ConditionsDirector.applied = {"wetness": 1.0, "wind_boost": 3.0}  # As if the last hunt was a storm.
	var main := _start({})
	await physics_frames(3)
	var mood := load("res://data/mood/verdant_canopy.tres") as JungleMood
	var sun := main.get_node("Level/Moonlight") as DirectionalLight3D
	check(sun.light_color.is_equal_approx(mood.sun_color), "sun colour is the mood's")
	check(ConditionsDirector.applied["wetness"] == 0.0 and ConditionsDirector.applied["wind_boost"] == 1.0, "wet ground and wind reset")
	_done()


func test_dusk_rain_changes_sun_sky_fog_rain_and_ground() -> void:
	var mood := load("res://data/mood/verdant_canopy.tres") as JungleMood
	var main := _start(_forecast("dusk", "rain"))
	await physics_frames(3)
	var dusk := load("res://data/conditions/time_dusk.tres") as TimeOfDay
	var rain := load("res://data/conditions/weather_rain.tres") as WeatherDefinition
	var sun := main.get_node("Level/Moonlight") as DirectionalLight3D
	var env := (main.get_node("Level/WorldEnvironment") as WorldEnvironment).environment
	check(sun.light_color.is_equal_approx(mood.sun_color * dusk.sun_color), "dusk-coloured sun")
	check(is_equal_approx(rad_to_deg(-sun.global_rotation.x), dusk.sun_elevation), "low sun (%.1f°)" % rad_to_deg(-sun.global_rotation.x))
	check(is_equal_approx(env.fog_density, mood.fog_density * rain.fog_density), "rain thickens the fog")
	var rains := main.find_children("*", "RainFX", true, false)
	check(rains.size() == 1 and (rains[0] as RainFX).emitting and (rains[0] as RainFX).visible, "it rains in the Verdant Canopy")
	check(is_equal_approx(float(ConditionsDirector.applied["wetness"]), rain.wetness), "the ground is wet")
	check(is_equal_approx(env.tonemap_exposure, float(env.get_meta(&"base_exposure")) * GameSettings.brightness), "the brightness slider still applies")
	_done()


func test_the_sky_is_tinted_once_and_never_compounds() -> void:
	var main := _start(_forecast("dusk", "clear"))
	await physics_frames(3)
	var sky := (main.get_node("Level/WorldEnvironment") as WorldEnvironment).environment.sky.sky_material as ShaderMaterial
	var first: Variant = sky.get_shader_parameter("zenith")
	main.free()
	_nodes.erase(main)
	main = _start(_forecast("dusk", "clear"))
	await physics_frames(3)
	check(sky.get_shader_parameter("zenith") == first, "a second dusk expedition tints the shared sky the same, not twice")
	main.free()
	_nodes.erase(main)
	main = _start(_forecast("day", "clear"))
	await physics_frames(3)
	check(sky.get_shader_parameter("zenith") == sky.get_meta("zenith"), "a clear day gives the sky its own colours back")
	_done()


func test_weather_turns_in_a_few_steps_without_touching_the_sky() -> void:
	for tier in [&"high", &"low"]:
		QualityProfile.force_tier(tier)
		var main := _start(_forecast("day", "clear", "storm", 0.5))
		await physics_frames(3)
		var m := main.get_node("Expedition") as ExpeditionManager
		var env := (main.get_node("Level/WorldEnvironment") as WorldEnvironment).environment
		var sky := env.sky.sky_material as ShaderMaterial
		var zenith: Variant = sky.get_shader_parameter("zenith")
		var fog_before := env.fog_density
		var turned := [false]
		m.conditions.weather_turned.connect(func(_w: WeatherDefinition) -> void: turned[0] = true)
		Engine.time_scale = 8.0
		await tree.create_timer(36.0).timeout  # Game time: about 4.5 s real at 8x.
		Engine.time_scale = 1.0
		var steps := ConditionsDirector.TURN_STEPS if tier == &"high" else 1
		check(turned[0] and m.conditions.turned, "%s: the weather turned" % tier)
		check(m.conditions.turn_steps_done == steps, "%s: in %d steps (%d)" % [tier, steps, m.conditions.turn_steps_done])
		check(env.fog_density > fog_before and is_equal_approx(float(ConditionsDirector.applied["wind_boost"]), 2.4), "%s: storm fog and wind arrived" % tier)
		check(sky.get_shader_parameter("zenith") == zenith, "%s: the sky was not touched during the turn" % tier)
		var rain := main.find_children("*", "RainFX", true, false)
		check(rain.size() == 1 and (rain[0] as RainFX).emitting, "%s: rain started" % tier)
		main.free()
		_nodes.erase(main)
	_done()


func test_the_board_forecast_is_the_expedition_weather_and_clear_setting_works() -> void:
	GameSettings.varied_conditions = true
	Conditions.forecasts[&"verdant_canopy"] = _forecast("night", "mist")
	var board := instantiate("res://scenes/ui/hunt_board.tscn")
	await process_frames(3)
	var labels := board.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	check(labels.has("Forecast: Night · Mist"), "the Verdant card shows its forecast")
	board.free()
	_nodes.erase(board)
	Conditions.begin(&"verdant_canopy")
	check(not Conditions.forecasts.has(&"verdant_canopy"), "a new forecast is rolled for the next visit")
	var main := _start(Conditions.pending)
	await physics_frames(3)
	var m := main.get_node("Expedition") as ExpeditionManager
	check((m.conditions.time.id == &"night") and (m.conditions.weather.id == &"mist"), "the expedition gets the forecast that was shown")
	main.free()
	_nodes.erase(main)
	GameSettings.varied_conditions = false
	var f := Conditions.forecast_for(&"stormcrag")
	check((f["time"] as TimeOfDay).id == &"day" and (f["weather"] as WeatherDefinition).id == &"clear" and f["turn"] == null, "'Always clear day' gives a clear day")
	GameSettings.varied_conditions = true
	_done()
