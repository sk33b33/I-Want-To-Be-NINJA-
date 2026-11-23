extends TestCase
## Regression (owner's Galaxy S20, Mali-G77): the Godot app crashed a few seconds into every
## expedition; the first lightning flash is due at 5 s. The atmosphere wrote the sky shader every
## frame (each write makes the renderer re-bake the sky). Sky writes must only happen when the
## value changes, and phones (Low) keep the sky still and skip sky reflections entirely.


func _done() -> void:
	QualityProfile.force_tier(&"")
	PlayerProfile.path = PlayerProfile.DEFAULT_PATH


func _start(tier: StringName) -> Node:
	QualityProfile.force_tier(tier)
	PlayerProfile.path = "user://test_profile_sky.json"
	return instantiate("res://scenes/main/main.tscn")


func test_sky_is_not_rewritten_every_frame() -> void:
	var main := _start(&"high")
	var atmos := main.get_node("Level/Atmosphere") as BiomeAtmosphere
	atmos.set("_next_flash", 999.0)  # No lightning during this test.
	await process_frames(5)
	var before := atmos.sky_updates
	await process_frames(120)
	check(atmos.sky_updates - before == 0, "no sky writes without lightning (%d in 120 frames)" % (atmos.sky_updates - before))
	_done()


func test_phones_keep_the_sky_still_and_skip_sky_reflections() -> void:
	var main := _start(&"low")
	var atmos := main.get_node("Level/Atmosphere") as BiomeAtmosphere
	var sun := main.get_node("Level/Moonlight") as DirectionalLight3D
	await process_frames(5)
	var env := (main.get_node("Level/WorldEnvironment") as WorldEnvironment).environment
	check(env.reflected_light_source == Environment.REFLECTION_SOURCE_DISABLED, "no sky reflections on Low")
	var base := sun.light_energy
	var before := atmos.sky_updates
	atmos.set("_next_flash", 0.0)  # Lightning now.
	var brightest := 0.0
	for i in 30:
		await process_frames(1)
		brightest = maxf(brightest, sun.light_energy)
	check(atmos.sky_updates - before == 0, "the sky never changes during a flash on Low (%d writes)" % (atmos.sky_updates - before))
	check(brightest > base * 1.2, "lightning still flashes through the moonlight")
	_done()


func test_lightning_still_lights_the_sky_on_high() -> void:
	var main := _start(&"high")
	var atmos := main.get_node("Level/Atmosphere") as BiomeAtmosphere
	await process_frames(5)
	var before := atmos.sky_updates
	atmos.set("_next_flash", 0.0)
	await process_frames(30)
	check(atmos.sky_updates - before > 0, "sky flashes on High")
	_done()
