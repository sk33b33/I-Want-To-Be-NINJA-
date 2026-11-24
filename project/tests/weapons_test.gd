extends TestCase
## Phase 13 part 2 (more weapons): four weapon types forged from the second beasts' parts — data
## and balance, what equipping changes (combo speed, hitbox reach, blade shape, trail), the two
## traits (part breaking, poison), the forge flow, and a gate where the bot wins with each.

const TEST_PROFILE := "user://test_profile_weapons.json"
const WEAPONS := {
	&"mantis_kama": [&"kama", &"mantis_scythe"],
	&"cinder_claws": [&"claws", &"cinder_tail"],
	&"venom_tanto": [&"tanto", &"toxin_sac"],
	&"gale_greatblades": [&"greatblade", &"gale_fang"],
}

var catalog: CraftingCatalog = load("res://data/crafting/catalog.tres")


func _gear(id: StringName) -> GearDefinition:
	return load("res://data/gear/%s.tres" % id) as GearDefinition


func _profile(gear: Array = [], materials: Dictionary = {}) -> void:
	PlayerProfile.path = TEST_PROFILE
	if FileAccess.file_exists(TEST_PROFILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PROFILE))
	var p := PlayerProfile.new()
	for id in gear:
		p.gear_owned.append(String(id))
		Forge.equip(p, catalog.find_gear(StringName(id)))
	for id in materials:
		p.add_material(StringName(id), int(materials[id]))
	p.save()


func _done() -> void:
	PlayerProfile.path = PlayerProfile.DEFAULT_PATH


func test_every_new_weapon_is_forgeable_from_its_beast_part_and_balanced() -> void:
	for gear_id: StringName in WEAPONS:
		var g := _gear(gear_id)
		check(g != null and g.slot == GearDefinition.Slot.WEAPON, "%s is a weapon" % gear_id)
		check(g.weapon_type != null and g.weapon_type.id == WEAPONS[gear_id][0], "%s is a %s" % [gear_id, WEAPONS[gear_id][0]])
		var recipe: RecipeDefinition = null
		for r in catalog.recipes:
			if r.result.id == gear_id:
				recipe = r
		check(recipe != null, "%s has a recipe in the forge" % gear_id)
		if recipe:
			check(recipe.inputs.has(load("res://data/items/%s.tres" % WEAPONS[gear_id][1])), "%s needs the beast part %s" % [gear_id, WEAPONS[gear_id][1]])
		var dps := g.weapon_type.dps_ratio()
		check(dps >= 0.85 and dps <= 1.15, "%s: damage x speed %.2f is within 15%% of the katana" % [gear_id, dps])
		check(g.stat_lines().size() >= 3, "%s explains how it plays" % gear_id)
		var mesh := ProceduralMeshes.new().call(g.weapon_type.blade_mesh, null) as ArrayMesh
		check(mesh != null and mesh.get_faces().size() > 0, "%s has its own blade shape" % gear_id)
	var types := {}
	for gear_id: StringName in WEAPONS:
		types[_gear(gear_id).weapon_type.blade_mesh] = true
	check(types.size() == 4, "four distinct blade shapes")


func test_equipping_a_weapon_changes_speed_reach_blades_and_trail() -> void:
	_profile([&"gale_greatblades"])
	var main := instantiate("res://scenes/main/main.tscn")
	await physics_frames(5)
	var player := main.get_node("Player") as PlayerController
	var combat := player.combat
	var type := _gear(&"gale_greatblades").weapon_type
	check(combat.weapon_type == type, "the greatblade type is equipped")
	var base := combat.config.light_combo[0]
	check(is_equal_approx(combat.light_combo[0].speed, base.speed * type.speed_multiplier), "light swing slowed to %.2f" % combat.light_combo[0].speed)
	check(is_equal_approx(combat.heavy_attack.damage, combat.config.heavy.damage * type.damage_multiplier), "heavy hits harder")
	check(base.speed == (load(base.resource_path) as AttackDefinition).speed, "the shared attack data is never modified")
	var shape := (combat.hitbox.get_child(0) as CollisionShape3D).shape as BoxShape3D
	check(shape.size.z > 1.9 * 1.3, "hitbox reaches further (%.2f m deep)" % shape.size.z)
	var mount := player.get_node("WeaponMount") as WeaponMount
	var length := mount.blades[0].mesh.get_aabb().size.y
	check(length > 1.0, "hand blades are the long greatblades (%.2f m)" % length)
	check(mount.sheathed_blades[0].mesh == mount.blades[0].mesh, "the sheathed pair matches")
	check(is_equal_approx(mount.trails[0].tip_override, type.trail_tip), "slash trail follows the longer blade")
	main.free()
	_nodes.erase(main)
	# Katana again: everything back to the config.
	_profile([&"thornfang_blades"])
	main = instantiate("res://scenes/main/main.tscn")
	await physics_frames(5)
	combat = (main.get_node("Player") as PlayerController).combat
	check(combat.weapon_type == null and combat.light_combo[0] == combat.config.light_combo[0], "blades without a type swing like the katana")
	_done()


func test_kama_breaks_parts_sooner() -> void:
	_profile()
	var main := instantiate("res://scenes/main/main.tscn")
	await physics_frames(5)
	var boss := main.get_node("Level/Boss") as BossController
	var part := boss.definition.parts[0]
	var info := DamageInfo.new()
	info.amount = 10.0
	info.part_multiplier = _gear(&"mantis_kama").weapon_type.part_damage_multiplier
	boss._on_part_hit(part.id, info)
	check(is_equal_approx(float(boss.part_damage[part.id]), 16.0), "a 10-damage kama hit counts 16 towards the break (%.1f)" % float(boss.part_damage[part.id]))
	_done()


func test_poison_ticks_refreshes_never_stacks_and_respects_resistance() -> void:
	var h := HealthComponent.new()
	h.max_health = 100.0
	add_node(h)
	await process_frames(1)
	h.poison(6.0, 5.0)
	await tree.create_timer(2.05).timeout
	check(h.current <= 88.5 and h.current >= 86.5, "6/s for ~2 s took ~12 (%.1f left)" % h.current)
	h.poison(3.0, 5.0)  # A weaker dose only refreshes the timer.
	check(h.poison_dps == 6.0 and h.poison_left == 5.0, "a new dose refreshes, never stacks or weakens")
	await tree.create_timer(5.3).timeout
	check(h.poison_left <= 0.0 and not h.is_processing(), "poison wears off and stops ticking")
	var after := h.current
	await tree.create_timer(1.0).timeout
	check(h.current == after, "no damage after it wears off")
	# Through a hurtbox: the beast's element table scales the dose (Gamakage is a poison beast).
	_profile()
	var main := instantiate("res://scenes/main/expedition_moonfen.tscn")
	(main.get_node("Expedition") as ExpeditionManager).hunt = load("res://data/hunts/gamakage.tres")
	await physics_frames(5)
	var boss := main.get_node("Level/Boss") as BossController
	var hurt := boss.get_node("BodyHurtbox") as Hurtbox
	var info := DamageInfo.new()
	info.amount = 1.0
	info.poison_dps = 6.0
	info.poison_seconds = 5.0
	hurt.receive(info)
	var m := hurt.elements.multiplier(&"poison") if hurt.elements else 1.0
	check(is_equal_approx(boss.get_health().poison_dps, 6.0 * m), "poison scaled by the beast's poison multiplier (%.2f)" % m)
	_done()


func test_forge_a_new_weapon_and_take_it_on_a_hunt() -> void:
	_profile([], {"toxin_sac": 1, "bog_toad_hide": 1, "spirit_moss": 2})
	var profile := PlayerProfile.load_profile()
	var recipe: RecipeDefinition = null
	for r in catalog.recipes:
		if r.result.id == &"venom_tanto":
			recipe = r
	check(Forge.can_craft(profile, recipe), "materials from Gamakage's hunt forge the Venom Tanto")
	check(Forge.craft(profile, recipe), "forged")
	Forge.equip(profile, recipe.result)
	profile.save()
	var main := instantiate("res://scenes/main/main.tscn")
	await physics_frames(5)
	var combat := (main.get_node("Player") as PlayerController).combat
	check(combat.weapon_type != null and combat.weapon_type.id == &"tanto", "the forged tanto is in hand next expedition")
	_done()


## Phase 13 gate (part 2): the bot wins a real fight with each new weapon (Kurogale, the first beast).
func test_gate_bot_defeats_kurogale_with_every_new_weapon() -> void:
	for gear_id: StringName in WEAPONS:
		_profile([gear_id])
		var main := instantiate("res://scenes/main/main.tscn")
		await physics_frames(10)
		var player := main.get_node("Player") as PlayerController
		var boss := main.get_node("Level/Boss") as BossController
		player.global_position = Vector3(0, 0.5, -104)
		await physics_frames(20)
		await BotHelpers.fight_boss(self, player, boss)
		check(boss.state == BossController.State.DEFEATED, "%s defeats Kurogale (hp %.0f)" % [gear_id, boss.get_health().current])
		_nodes.erase(main)
		main.free()
		await physics_frames(3)
	_done()
