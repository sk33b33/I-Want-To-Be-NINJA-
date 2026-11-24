extends TestCase
## Phase 13 part 3 (secrets & exploration): three hidden spirit shrines per jungle — data, safe
## placement, every relic reachable by a bot with the real controls, saved at once, never twice,
## found shrines stay found, a complete jungle grants its Shrine Blessing, and the hints/counts.

const TEST_PROFILE := "user://test_profile_secrets.json"
const SCENES := {
	&"verdant_canopy": "res://scenes/main/main.tscn",
	&"emberwild": "res://scenes/main/expedition_emberwild.tscn",
	&"moonfen": "res://scenes/main/expedition_moonfen.tscn",
	&"stormcrag": "res://scenes/main/expedition_stormcrag.tscn",
}
const HAZARDS := ["LavaZone", "SurfaceZone", "GustZone", "FogZone", "StormCaller", "BossArenaTrigger"]


func _profile(secrets: Array = []) -> void:
	PlayerProfile.path = TEST_PROFILE
	for f in [TEST_PROFILE, TEST_PROFILE + ".bak"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	var p := PlayerProfile.new()
	for id in secrets:
		p.add_secret(StringName(id))
	p.save()


func _done() -> void:
	PlayerProfile.path = PlayerProfile.DEFAULT_PATH


func _spots(main: Node) -> SecretSpots:
	return main.find_children("*", "SecretSpots", true, false)[0] as SecretSpots


func test_every_jungle_has_three_hinted_secrets_and_a_blessing() -> void:
	var sets := SecretSet.all_sets()
	check(sets.size() == 4, "four jungles have secrets (%d)" % sets.size())
	var ids := {}
	for s in sets:
		check(SCENES.has(s.biome_id), "%s is a jungle" % s.biome_id)
		check(s.secrets.size() == 3, "%s has three secrets" % s.biome_id)
		check(s.blessing_health > 0.0 and s.relic_item != null, "%s has a blessing and a relic" % s.biome_id)
		for d in s.secrets:
			check(not ids.has(d.id), "%s is a unique id" % d.id)
			ids[d.id] = true
			check(d.hint.length() > 20, "%s has a hint" % d.id)
	var charm := load("res://data/crafting/catalog.tres") as CraftingCatalog
	check(charm.find_gear(&"spirit_charm") != null, "the Spirit Charm is in the forge")


func test_every_shrine_stands_on_safe_flat_ground_clear_of_other_things() -> void:
	_profile()
	for biome: StringName in SCENES:
		var main := instantiate(SCENES[biome])
		await physics_frames(3)
		var spots := _spots(main)
		check(spots.secret_set != null and spots.secret_set.biome_id == biome, "%s scene has its secrets" % biome)
		var terrain := main.find_children("*", "BiomeTerrain", true, false)[0] as BiomeTerrain
		var space := (main as Node3D).get_world_3d().direct_space_state
		var own: Array[RID] = []
		for site in spots.sites:
			for b in site.find_children("*", "StaticBody3D", true, false):
				own.append((b as StaticBody3D).get_rid())
		for b in terrain.find_children("*", "StaticBody3D", true, false):
			own.append((b as StaticBody3D).get_rid())
		for site in spots.sites:
			var p := site.global_position
			var hs: Array[float] = []
			for o in [Vector2(-2, -2), Vector2(2, -2), Vector2(-2, 2), Vector2(2, 2)]:
				hs.append(terrain.get_height(p.x + o.x, p.z + o.y))
			check(hs.max() - hs.min() < 2.5, "%s: ground is not too steep (%.1f m)" % [site.secret.id, hs.max() - hs.min()])
			check(p.y > (main.get_node("Player") as PlayerController).config.kill_height + 5.0, "%s: well above the kill height" % site.secret.id)
			var q := PhysicsPointQueryParameters3D.new()
			q.position = p + Vector3.UP * 0.5
			q.collide_with_areas = true
			q.collide_with_bodies = false
			for hit in space.intersect_point(q, 32):
				var s := (hit["collider"] as Node).get_script() as Script
				check(s == null or not HAZARDS.has(s.get_global_name()), "%s: not inside a hazard (%s)" % [site.secret.id, (hit["collider"] as Node).name])
			var box := BoxShape3D.new()
			box.size = Vector3(6.5, 3.0, 6.5)
			var sq := PhysicsShapeQueryParameters3D.new()
			sq.shape = box
			sq.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * 1.8)
			sq.collision_mask = 1
			sq.exclude = own
			var blockers := space.intersect_shape(sq, 8).map(func(h: Dictionary) -> String: return (h["collider"] as Node).name)
			check(blockers.is_empty(), "%s: nothing else stands on the shrine %s" % [site.secret.id, blockers])
		main.free()
		_nodes.erase(main)
	_done()


## Phase 13 gate (part 3): every relic can be reached and taken with the real controls.
func test_gate_bot_reaches_and_takes_every_relic() -> void:
	for biome: StringName in SCENES:
		_profile()
		var main := instantiate(SCENES[biome])
		await physics_frames(5)
		var player := main.get_node("Player") as PlayerController
		player.combat.health.invulnerable = true  # Wildlife may wander in; this tests reachability.
		var found: Array[StringName] = []
		(main.get_node("Expedition") as ExpeditionManager).secret_found.connect(
				func(s: SecretDefinition, _c: bool) -> void: found.append(s.id))
		for site in _spots(main).sites:
			# From the route a little nearer the spawn (as a player would spot the beam ahead).
			player.respawn(Vector3(0, 0.3, site.global_position.z + 6.0))
			await physics_frames(3)
			var relic := site.relic.global_position
			var ok: bool
			if site.secret.kind == SecretDefinition.Kind.NOOK:
				var g := site.secret.gap_direction.normalized()
				var outside := site.global_position + Vector3(g.x, 0, g.y) * 5.0
				await BotHelpers.walk_toward(self, player, outside,
						func() -> bool: return Vector2(player.global_position.x - outside.x, player.global_position.z - outside.z).length() < 0.8, 900)
			ok = await BotHelpers.walk_toward(self, player, relic, func() -> bool: return site.taken, 1800)
			check(ok, "%s: bot took the relic (ended at %s)" % [site.secret.id, player.global_position.round()])
		check(found.size() == 3, "%s: three shrines found (%s)" % [biome, found])
		var profile := PlayerProfile.load_profile()
		check(profile.count(&"spirit_relic") == 3, "%s: three relics saved at once (%d)" % [biome, profile.count(&"spirit_relic")])
		check(SecretSet.for_biome(biome).is_complete(profile), "%s: set complete" % biome)
		main.free()
		_nodes.erase(main)
		await physics_frames(2)
	_done()


func test_found_shrines_stay_found_and_never_reward_twice() -> void:
	var set_data := SecretSet.for_biome(&"verdant_canopy")
	var first := set_data.secrets[0]
	_profile([first.id])
	var main := instantiate(SCENES[&"verdant_canopy"])
	await physics_frames(3)
	var site := _spots(main).sites[0]
	check(site.taken and not site.beam.visible, "a shrine found before shows no beam or relic")
	var m := main.get_node("Expedition") as ExpeditionManager
	m.find_secret(first, set_data)
	check(PlayerProfile.load_profile().count(&"spirit_relic") == 0, "finding it again gives nothing")
	m.find_secret(set_data.secrets[1], set_data)
	m.abandon()
	var p := PlayerProfile.load_profile()
	check(p.has_secret(set_data.secrets[1].id) and p.count(&"spirit_relic") == 1, "a shrine found mid-hunt is kept after abandoning")
	_done()


func test_a_complete_jungle_grants_its_blessing_and_shows_progress() -> void:
	var set_data := SecretSet.for_biome(&"verdant_canopy")
	_profile(set_data.secrets.map(func(d: SecretDefinition) -> StringName: return d.id))
	var main := instantiate(SCENES[&"verdant_canopy"])
	await physics_frames(3)
	var player := main.get_node("Player") as PlayerController
	check(is_equal_approx(player.combat.health.max_health, player.combat.config.max_health + set_data.blessing_health),
			"Blessing of the Canopy: +%d max health (%.0f)" % [int(set_data.blessing_health), player.combat.health.max_health])
	main.free()
	_nodes.erase(main)
	_profile([set_data.secrets[0].id])
	main = instantiate(SCENES[&"verdant_canopy"])
	await physics_frames(3)
	var menu := main.find_children("*", "PauseMenu", true, false)[0] as PauseMenu
	menu.open()
	check(menu.secrets_label.text.contains("1 / 3"), "pause menu counts the shrines")
	check(not menu.secrets_label.text.contains(set_data.secrets[0].hint) and menu.secrets_label.text.contains(set_data.secrets[1].hint),
			"pause menu hints only the missing ones")
	menu.close()
	main.free()
	_nodes.erase(main)
	var board := instantiate("res://scenes/ui/hunt_board.tscn")
	await process_frames(3)
	var labels := board.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	check(labels.any(func(t: String) -> bool: return t.begins_with("Spirit shrines 1 / 3")), "hunt board shows shrine progress")
	_done()
