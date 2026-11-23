extends TestCase
## Slash trails (owner request): a fading ribbon behind the blades during light and heavy attacks,
## not during the wind-up, never for the talisman; heavy is wider and brighter; colour follows the
## forged blade element.


func _player() -> PlayerController:
	make_floor()
	return make_player(Vector3(0, 0.05, 0))


func _trails(p: PlayerController) -> Array[WeaponTrail]:
	return (p.get_node("WeaponMount") as WeaponMount).trails


## Run an attack and record the most trail slices and widest/brightest values seen.
func _swing(p: PlayerController, action: String) -> Dictionary:
	var out := {"max_samples": 0, "max_vertices": 0, "width": 0.0, "brightness": 0.0, "samples_at_start": -1}
	BotHelpers.tap(self, action)
	for i in 120:
		await tree.process_frame
		var tr := _trails(p)[0]
		if out["samples_at_start"] < 0 and p.combat.state == PlayerCombat.State.ATTACK:
			out["samples_at_start"] = tr.sample_count()
		out["max_samples"] = maxi(out["max_samples"], tr.sample_count())
		out["max_vertices"] = maxi(out["max_vertices"], tr.last_vertex_count)
		if tr.sample_count() > 0:
			out["width"] = maxf(out["width"], tr.current_width)
			out["brightness"] = maxf(out["brightness"], tr.current_color.get_luminance())
	return out


func test_light_attack_leaves_a_trail_that_fades() -> void:
	var p := _player()
	await physics_frames(40)
	check(_trails(p).size() == 2, "a trail per blade")
	var r: Dictionary = await _swing(p, "attack_light")
	check(r["samples_at_start"] == 0, "nothing during the start of the wind-up")
	check(r["max_samples"] >= 4 and r["max_vertices"] >= 8, "a ribbon was drawn (%d slices)" % r["max_samples"])
	await process_frames(30)
	await physics_frames(30)
	check(_trails(p)[0].sample_count() == 0 and _trails(p)[0].last_vertex_count == 0, "faded away after the swing")


func test_heavy_trail_is_wider_and_brighter_than_light() -> void:
	var p := _player()
	await physics_frames(40)
	var light: Dictionary = await _swing(p, "attack_light")
	await physics_frames(60)
	var heavy: Dictionary = await _swing(p, "attack_heavy")
	check(heavy["max_samples"] > 0, "heavy draws a trail")
	check(heavy["width"] > light["width"], "heavy is wider (%.2f vs %.2f)" % [heavy["width"], light["width"]])
	check(heavy["brightness"] > light["brightness"], "heavy is brighter")


func test_talisman_throw_draws_no_trail() -> void:
	var p := _player()
	await physics_frames(40)
	var r: Dictionary = await _swing(p, "skill")
	check(r["max_samples"] == 0, "no slash trail for the talisman (%d)" % r["max_samples"])


func test_trail_colour_follows_the_blade_element() -> void:
	var p := _player()
	await physics_frames(40)
	p.combat.blade_element = &"fire"
	await _swing(p, "attack_light")
	var c := _trails(p)[0].current_color
	check(c.r > c.b * 1.5, "fire blades leave an orange trail (%s)" % c)
	p.combat.blade_element = &""
