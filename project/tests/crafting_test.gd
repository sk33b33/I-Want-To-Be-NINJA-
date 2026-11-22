extends TestCase
## Phase 7: forge rules, persistence, gear effects in the expedition, and the gate — a boss part
## reward is crafted into gear, equipped, survives a reload and changes the hunt.

const TEST_PROFILE := "user://test_profile_phase7.json"

var catalog: CraftingCatalog = load("res://data/crafting/catalog.tres")


func _fresh(materials: Dictionary = {}) -> PlayerProfile:
	PlayerProfile.path = TEST_PROFILE
	if FileAccess.file_exists(TEST_PROFILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PROFILE))
	var p := PlayerProfile.new()
	for id in materials:
		p.add_material(StringName(id), int(materials[id]))
	p.save()
	return p


func _done() -> void:
	PlayerProfile.path = PlayerProfile.DEFAULT_PATH


func _recipe(gear_id: StringName) -> RecipeDefinition:
	for r in catalog.recipes:
		if r.result.id == gear_id:
			return r
	return null


func test_catalog_has_three_recipes_using_hunt_materials() -> void:
	check(catalog.recipes.size() == 3, "three recipes")
	var slots := {}
	for r in catalog.recipes:
		slots[r.result.slot] = true
		check(r.inputs.size() == r.counts.size() and not r.inputs.is_empty(), "%s lists its costs" % r.id)
		check(not r.result.stat_lines().is_empty(), "%s does something readable" % r.id)
	check(slots.size() == 3, "one weapon, one armor, one charm")
	check(_recipe(&"thornfang_blades").inputs.has(load("res://data/items/thornback_antler.tres")), "blades need the boss part")


func test_cannot_forge_without_materials() -> void:
	var p := _fresh({"thornback_antler": 1})  # Missing the ruin shard.
	var r := _recipe(&"thornfang_blades")
	check(not Forge.can_craft(p, r), "not craftable")
	check(Forge.missing(p, r).get(&"ruin_shard", 0) == 1, "reports the missing shard")
	check(not Forge.craft(p, r), "craft refused")
	check(p.count(&"thornback_antler") == 1, "nothing consumed")
	_done()


func test_forging_consumes_materials_once_and_only_once() -> void:
	var p := _fresh({"thornback_antler": 2, "ruin_shard": 2})
	var r := _recipe(&"thornfang_blades")
	check(Forge.craft(p, r), "forged")
	check(p.owns(&"thornfang_blades"), "owned")
	check(p.count(&"thornback_antler") == 1 and p.count(&"ruin_shard") == 1, "consumed exactly one of each")
	check(not Forge.craft(p, r), "cannot forge the same gear twice")
	check(p.count(&"thornback_antler") == 1, "second attempt consumed nothing")
	_done()


func test_equip_requires_ownership_and_replaces_the_slot() -> void:
	var p := _fresh({"glowcap": 5, "ruin_shard": 1, "kurogale_hide": 1})
	var charm := _recipe(&"ember_charm").result
	check(not Forge.equip(p, charm), "cannot equip unowned gear")
	Forge.craft(p, _recipe(&"ember_charm"))
	check(Forge.equip(p, charm), "equipped after forging")
	check(p.equipped_id("Charm") == &"ember_charm", "in the charm slot")
	_done()


func test_profile_round_trip_and_old_saves_still_load() -> void:
	var p := _fresh({"thornback_antler": 1, "ruin_shard": 1})
	Forge.craft(p, _recipe(&"thornfang_blades"))
	Forge.equip(p, _recipe(&"thornfang_blades").result)
	p.save()
	var loaded := PlayerProfile.load_profile()
	check(loaded.owns(&"thornfang_blades"), "owned gear persists")
	check(loaded.equipped_id("Weapon") == &"thornfang_blades", "equipped gear persists")
	check(loaded.count(&"thornback_antler") == 0, "spent materials stay spent")
	# A version-1 save (Phase 5/6) has no gear fields.
	var f := FileAccess.open(TEST_PROFILE, FileAccess.WRITE)
	f.store_string('{"version": 1, "materials": {"glowcap": 3}, "hunts_completed": {"kurogale": 1}}')
	f.close()
	var old := PlayerProfile.load_profile()
	check(old.count(&"glowcap") == 3 and old.gear_owned.is_empty() and old.equipped.is_empty(), "v1 save loads with empty gear")
	_done()


func test_forge_panel_crafts_equips_and_saves() -> void:
	_fresh({"kurogale_hide": 1, "glowcap": 2})
	var board := instantiate("res://scenes/ui/hunt_board.tscn") as HuntBoard
	await process_frames(2)
	board.show_tab("forge")
	await process_frames(2)
	var btns: Dictionary = board.forge.buttons[&"barkhide_garb"]
	check(not (btns["craft"] as Button).disabled, "Forge button enabled when affordable")
	check((board.forge.buttons[&"thornfang_blades"]["craft"] as Button).disabled, "blades greyed out without the antler")
	(btns["craft"] as Button).pressed.emit()
	await process_frames(2)
	btns = board.forge.buttons[&"barkhide_garb"]
	check((btns["craft"] as Button).disabled and (btns["craft"] as Button).text == "Owned", "shows Owned")
	(btns["equip"] as Button).pressed.emit()
	await process_frames(2)
	var saved := PlayerProfile.load_profile()
	check(saved.owns(&"barkhide_garb") and saved.equipped_id("Armor") == &"barkhide_garb", "crafted + equipped and saved")
	check(saved.count(&"kurogale_hide") == 0, "hide spent")
	_done()


func _expedition_with(gear_ids: Array) -> Node:
	var p := _fresh({})
	for id in gear_ids:
		p.gear_owned.append(String(id))
		Forge.equip(p, catalog.find_gear(StringName(id)))
	p.save()
	return instantiate("res://scenes/main/main.tscn")


func test_thornfang_blades_hit_harder_and_turn_green() -> void:
	var main := _expedition_with([&"thornfang_blades"])
	var player := main.get_node("Player") as PlayerController
	await physics_frames(10)
	check_near(player.combat.blade_damage_multiplier, 1.25, 0.001, "blade damage +25%")
	var mount := player.get_node("WeaponMount") as WeaponMount
	check(mount.current_tint().g > mount.current_tint().r, "blades tinted thorn-green")
	var dummy := main.get_node("Level/Enemies/TrainingDummy") as TrainingDummy
	player.global_position = dummy.global_position + Vector3(0, 0.1, 1.6)
	player.face_direction(Vector3.FORWARD)
	await physics_frames(10)
	press("attack_light")
	await physics_frames(3)
	release("attack_light")
	await physics_frames(60)
	check_near(dummy.total_damage, 10.0 * 1.25, 0.01, "light hit deals 12.5 (got %.2f)" % dummy.total_damage)
	_done()


func test_barkhide_garb_adds_health_and_reduces_damage() -> void:
	var main := _expedition_with([&"barkhide_garb"])
	var player := main.get_node("Player") as PlayerController
	await physics_frames(10)
	var h := player.combat.health
	check_near(h.max_health, 125.0, 0.01, "max health 125")
	check_near(h.current, 125.0, 0.01, "starts full")
	var info := DamageInfo.new()
	info.amount = 20.0
	h.apply_damage(info)
	check_near(h.current, 125.0 - 17.0, 0.01, "20 damage becomes 17")
	_done()


func test_ember_charm_shortens_the_talisman_cooldown() -> void:
	var main := _expedition_with([&"ember_charm"])
	var player := main.get_node("Player") as PlayerController
	await physics_frames(10)
	check_near(player.combat.effective_skill_cooldown(), 2.5, 0.001, "4.0 s - 1.5 s")
	check_near(player.combat.skill_damage_multiplier, 1.3, 0.001, "talisman +30%")
	_done()


func test_no_gear_means_starter_stats() -> void:
	var main := _expedition_with([])
	var player := main.get_node("Player") as PlayerController
	await physics_frames(10)
	check_near(player.combat.blade_damage_multiplier, 1.0, 0.001, "starter blades")
	check_near(player.combat.health.max_health, 100.0, 0.001, "base health")
	check_near(player.combat.health.damage_taken_multiplier, 1.0, 0.001, "no armor")
	_done()


## Phase 7 gate: a boss part reward (from a won hunt) is forged into gear, equipped, survives a
## "restart" (profile reloaded from disk) and is in effect in the next expedition.
func test_gate_part_reward_to_equipped_gear_survives_reload() -> void:
	_fresh({})
	# 1) Win a hunt: break the antlers and defeat Kurogale (rewards saved by the expedition).
	var hunt := instantiate("res://scenes/main/main.tscn")
	var boss := hunt.get_node("Level/Boss") as Kurogale
	await physics_frames(5)
	(hunt.get_node("Player") as PlayerController).global_position = Vector3(0, 0.5, -104)
	await physics_frames(10)
	var antler := boss.get_node("Visual/AntlerHurtbox") as Hurtbox
	for i in 9:
		var a := DamageInfo.new()
		a.amount = 30.0
		antler.receive(a)
	var kill := DamageInfo.new()
	kill.amount = 9999.0
	(boss.get_node("BodyHurtbox") as Hurtbox).receive(kill)
	await physics_frames(10)
	hunt.queue_free()
	await process_frames(2)
	var after_hunt := PlayerProfile.load_profile()
	check(after_hunt.count(&"thornback_antler") == 1, "the hunt saved the antler")
	# Add a Ruin Shard as if gathered on the route.
	after_hunt.add_material(&"ruin_shard", 1)
	after_hunt.save()
	# 2) Forge and equip in the dojo.
	var board := instantiate("res://scenes/ui/hunt_board.tscn") as HuntBoard
	await process_frames(2)
	check(board.forge.craft(_recipe(&"thornfang_blades")), "forged from the antler")
	check(board.forge.equip(_recipe(&"thornfang_blades").result), "equipped")
	board.queue_free()
	await process_frames(2)
	# 3) "Restart": everything comes back from disk.
	var reloaded := PlayerProfile.load_profile()
	check(reloaded.owns(&"thornfang_blades") and reloaded.equipped_id("Weapon") == &"thornfang_blades", "persisted")
	check(reloaded.count(&"thornback_antler") == 0, "antler was consumed")
	# 4) Next expedition uses it.
	var next := instantiate("res://scenes/main/main.tscn")
	await physics_frames(10)
	var player := next.get_node("Player") as PlayerController
	check_near(player.combat.blade_damage_multiplier, 1.25, 0.001, "forged blades in effect")
	var names: Array = player.combat.equipped_gear.map(func(g: GearDefinition) -> StringName: return g.id)
	check(names.has(&"thornfang_blades"), "loadout lists the blades")
	_done()
