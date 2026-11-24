extends TestCase
## Phase 8: Emberwild — distinct hazards (vents, heat, sinking stones, crumbling basalt, lava),
## the Ashen Oni-Tortoise (fire, weak to water), the Mist Charm, unlocking, and the gate: a full
## Emberwild hunt.

const TEST_PROFILE := "user://test_profile_phase8.json"
const SCENE := "res://scenes/main/expedition_emberwild.tscn"


func _profile(gear: Array = [], hunts: Dictionary = {}) -> void:
	PlayerProfile.path = TEST_PROFILE
	if FileAccess.file_exists(TEST_PROFILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PROFILE))
	var p := PlayerProfile.new()
	var catalog: CraftingCatalog = load("res://data/crafting/catalog.tres")
	for id in gear:
		p.gear_owned.append(String(id))
		Forge.equip(p, catalog.find_gear(StringName(id)))
	p.hunts_completed = hunts
	p.save()


func _done() -> void:
	PlayerProfile.path = PlayerProfile.DEFAULT_PATH


# ---------------------------------------------------------------- hazards

func test_fire_vent_warns_before_it_erupts_and_hurts() -> void:
	make_floor()
	var p := make_player(Vector3(0, 0.05, 0))
	var vent := instantiate("res://scenes/world/fire_vent.tscn") as FireVent
	vent.global_position = Vector3(0, 0, 0)
	await physics_frames(2)
	var saw_warning_first := false
	var hp := p.combat.health.current
	for i in 400:
		await tree.physics_frame
		if vent.phase == FireVent.Phase.WARNING and p.combat.health.current == hp:
			saw_warning_first = true
		if p.combat.health.current < hp:
			break
	check(saw_warning_first, "a warning phase came before any damage")
	check(p.combat.health.current < hp, "the eruption hurt a player standing on it")


func test_heat_zone_burns_over_time_only_inside() -> void:
	make_floor()
	var p := make_player(Vector3(0, 0.05, 0))
	var heat := HeatZone.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 3, 4)
	col.shape = box
	heat.add_child(col)
	add_node(heat)
	heat.global_position = Vector3(0, 1, 0)
	await physics_frames(70)
	check(p.combat.health.current < 100.0, "burned while standing in it (%.0f)" % p.combat.health.current)
	var hp := p.combat.health.current
	p.global_position = Vector3(10, 0.05, 0)
	await physics_frames(70)
	check_near(p.combat.health.current, hp, 0.01, "no burning outside")


func test_sinking_stone_cycle_drops_a_standing_player() -> void:
	make_floor(Vector3(40, 1, 40), Vector3(0, -30, 0))  # Far below.
	var stone := instantiate("res://scenes/world/sinking_stone.tscn") as SinkingStone
	stone.global_position = Vector3(0, 0, 0)
	await physics_frames(2)
	var p := make_player(Vector3(0, 0.1, 0))
	await physics_frames(20)
	check(stone.is_safe() and p.is_on_floor(), "standing on the raised stone")
	var saw := {}
	for i in int(stone.cycle_length() * 60.0):
		await tree.physics_frame
		saw[stone.phase] = true
		if stone.phase == SinkingStone.Phase.SUNK:
			break
	check(saw.has(SinkingStone.Phase.WARNING), "warned before sinking")
	check(p.global_position.y < -1.5, "the player went down with it (y=%.2f)" % p.global_position.y)


func test_crumbling_basalt_breaks_then_reforms() -> void:
	make_floor(Vector3(40, 1, 40), Vector3(0, -20, 0))
	var plat := instantiate("res://scenes/world/crumble_platform.tscn") as CrumblePlatform
	plat.global_position = Vector3(0, 0, 0)
	await physics_frames(2)
	var p := make_player(Vector3(0, 0.2, 0))
	await physics_frames(10)
	check(plat.phase != CrumblePlatform.Phase.SOLID, "started crumbling under the player")
	await physics_frames(int(plat.shake_time * 60.0) + 30)
	check(plat.phase == CrumblePlatform.Phase.FALLEN and p.global_position.y < -1.0, "broke and dropped the player")
	await physics_frames(int(plat.reform_time * 60.0) + 10)
	check(plat.phase == CrumblePlatform.Phase.SOLID, "reformed")


func test_lava_burns_and_returns_the_player_to_the_checkpoint() -> void:
	_profile()
	var main := instantiate(SCENE)
	var p := main.get_node("Player") as PlayerController
	await physics_frames(10)
	var cp := main.get_node("Level/Checkpoints/CheckpointLava") as Checkpoint
	cp.activate(p)
	var lava := main.get_node("Level/Hazards/LavaRiver") as LavaZone
	var burns := [0]
	lava.burned.connect(func(_pl: PlayerController) -> void: burns[0] += 1)
	p.global_position = Vector3(0, -2.0, -60)
	await physics_frames(10)
	check(burns[0] == 1, "lava burned once")
	check(p.combat.health.current < p.combat.health.max_health, "took fire damage")
	check(p.global_position.distance_to(cp.global_position) < 1.5, "back at the lava checkpoint")
	_done()


func test_emberwild_has_every_distinct_hazard_and_its_own_look() -> void:
	_profile()
	var main := instantiate(SCENE)
	await physics_frames(3)
	var tree_ := main.get_tree()
	# The original route's hazards (the long route adds more of each, under RouteBuilder).
	var original := func(group: String) -> int:
		return tree_.get_nodes_in_group(group).filter(func(n: Node) -> bool: return main.get_node("Level/Hazards").is_ancestor_of(n)).size()
	check(original.call("fire_vents") == 4, "4 fire vents on the original route")
	check(tree_.get_nodes_in_group("heat_zones").size() == 1, "a heat zone")
	check(original.call("sinking_stones") == 4, "4 sinking stones on the original route")
	check(tree_.get_nodes_in_group("crumble_platforms").size() == 3, "crumbling shortcut")
	check(main.get_node_or_null("Level/Hazards/LavaRiver") is LavaZone, "lava river")
	var boss := main.get_node("Level/Boss") as BossController
	check(boss.definition.id == &"ashen_oni_tortoise", "the Ashen Oni-Tortoise waits in the arena")
	check((main.get_node("Expedition") as ExpeditionManager).hunt.id == &"ashen_oni_tortoise", "its hunt")
	_done()


# ---------------------------------------------------------------- boss + elements

func test_tortoise_is_weak_to_water_and_shrugs_off_fire() -> void:
	var def := load("res://data/bosses/ashen_oni_tortoise.tres") as BossDefinition
	check_near(def.elements.multiplier(&"water"), 1.5, 0.001, "water x1.5")
	check_near(def.elements.multiplier(&"fire"), 0.25, 0.001, "fire x0.25")
	check(def.attacks.size() == 4, "four attacks")
	var kinds := {}
	for a in def.attacks:
		kinds[a.kind] = true
		check(a.telegraph_time >= 1.0 and a.counterplay != "", "%s telegraphs and documents counterplay" % a.id)
	check(kinds.size() == 4, "uses all four attack kinds")


func test_mist_charm_turns_the_talisman_to_water() -> void:
	_profile([&"mist_charm"])
	var main := instantiate(SCENE)
	var p := main.get_node("Player") as PlayerController
	await physics_frames(10)
	check(p.combat.skill_element() == &"water", "talisman element is water")
	var boss := main.get_node("Level/Boss") as BossController
	var hurt := boss.get_node("BodyHurtbox") as Hurtbox
	var info := DamageInfo.new()
	info.amount = 20.0
	info.element = p.combat.skill_element()
	hurt.receive(info)
	check_near(boss.get_health().max_health - boss.get_health().current, 30.0, 0.01, "water hits for 1.5x")
	_done()


func test_every_tortoise_attack_warns_before_it_hurts() -> void:
	make_floor(Vector3(80, 1, 80))
	var boss := instantiate("res://scenes/bosses/ashen_oni_tortoise.tscn") as BossController
	boss.global_position = Vector3(0, 0.05, 0)
	boss.rotation.y = PI
	boss.arena_center = Vector3.ZERO
	var p := make_player(Vector3(0, 0.05, 4))
	await physics_frames(10)
	boss.awaken()
	await physics_frames(int(boss.definition.intro_time * 60.0) + 5)
	for id in [&"shell_slam", &"lava_burst", &"shell_spin"]:
		p.combat.health.reset()
		# Earlier attacks knock the player (and the boss follows): recentre both inside the arena,
		# otherwise the arena edge legitimately stops the spin.
		boss.global_position = Vector3(0, 0.05, 0)
		p.global_position = boss.global_position + Vector3(0, 0.05, 4.0 if id == &"shell_slam" else 9.0)
		await physics_frames(5)
		boss.debug_force_attack(id)
		var expected := boss.definition.get_attack(id).telegraph_time
		var t := 0.0
		var hit_at := -1.0
		for i in int((expected + 2.5) * 60.0):
			await tree.physics_frame
			t += 1.0 / 60.0
			if hit_at < 0.0 and p.combat.health.current < p.combat.health.max_health:
				hit_at = t
		check(hit_at > 0.0, "%s connected with a player who stood still" % id)
		check(hit_at >= expected - 0.02, "%s warned first (%.2f / %.2f)" % [id, hit_at, expected])
		await physics_frames(150)


func test_horns_break_once_and_reward_once() -> void:
	_profile()
	var main := instantiate(SCENE)
	var m := main.get_node("Expedition") as ExpeditionManager
	var boss := main.get_node("Level/Boss") as BossController
	await physics_frames(5)
	(main.get_node("Player") as PlayerController).global_position = Vector3(0, 0.5, -104)
	await physics_frames(10)
	var horns := boss.get_node("Visual/HornHurtbox") as Hurtbox
	for i in 12:
		var a := DamageInfo.new()
		a.amount = 30.0
		horns.receive(a)
	check(boss.is_part_broken(&"horns"), "horns broken")
	check(int(m.run_rewards.get(&"oni_horn", 0)) == 1, "one Oni Horn")
	check(not (boss.get_node("Visual/Horns") as Node3D).visible and (boss.get_node("Visual/HornStubs") as Node3D).visible, "stubs shown")
	_done()


# ---------------------------------------------------------------- progression

func test_emberwild_unlocks_after_kurogale() -> void:
	var biome := load("res://data/biomes/biome_emberwild.tres") as BiomeDefinition
	_profile()
	check(not HuntBoard.is_open(biome, PlayerProfile.load_profile()), "locked before Kurogale")
	_profile([], {"kurogale": 1})
	check(HuntBoard.is_open(biome, PlayerProfile.load_profile()), "open after defeating Kurogale")
	var board := instantiate("res://scenes/ui/hunt_board.tscn") as HuntBoard
	await process_frames(2)
	check(board.get_start_button(&"ashen_oni_tortoise") != null, "hunt board offers the Tortoise hunt")
	_done()


func test_new_recipes_are_in_the_forge() -> void:
	var catalog: CraftingCatalog = load("res://data/crafting/catalog.tres")
	for id in [&"mist_charm", &"oni_fang_blades", &"ashen_plate"]:
		check(catalog.find_gear(id) != null, "%s can be forged" % id)
	check(catalog.find_gear(&"oni_fang_blades").blade_element == &"fire", "Oni Fang Blades burn (good vs Kurogale)")


# ---------------------------------------------------------------- gate

## Phase 8 gate: a complete Emberwild hunt. Crossing needs the hazard skills (vent timing, cool
## lane, stone timing, far-bank climb); the fight uses the Mist Charm against the water weakness.
func test_gate_full_emberwild_hunt() -> void:
	_profile([&"mist_charm"], {"kurogale": 1})
	var main := instantiate(SCENE)
	_nodes.append(main)
	var m := main.get_node("Expedition") as ExpeditionManager
	var player := main.get_node("Player") as PlayerController
	var boss := main.get_node("Level/Boss") as BossController
	var lava := main.get_node("Level/Hazards/LavaRiver") as LavaZone
	var burns := [0]
	lava.burned.connect(func(_pl: PlayerController) -> void: burns[0] += 1)
	await physics_frames(20)
	check(m.timer.state == ExpeditionTimer.State.RUNNING, "45:00 countdown running")
	var crossed := await BotHelpers.run_route_emberwild(self, player, main.get_node("Level"), -100.0)
	check(crossed, "crossed Emberwild (z=%.1f)" % player.global_position.z)
	check(burns[0] == 0, "never fell into the lava (burns=%d)" % burns[0])
	check(m.arena_entered and m.timer.state == ExpeditionTimer.State.STOPPED, "arena entered, timer stopped")
	await BotHelpers.fight_boss(self, player, boss)
	check(boss.state == BossController.State.DEFEATED, "Ashen Oni-Tortoise defeated (hp %.0f)" % boss.get_health().current)
	check(boss.is_part_broken(&"horns"), "horns broken")
	await physics_frames(int(boss.definition.death_time * 60.0) + 30)
	var profile := PlayerProfile.load_profile()
	check(profile.count(&"oni_horn") == 1 and profile.count(&"ashen_shell_plate") == 1, "rewards saved")
	check(int(profile.hunts_completed.get("ashen_oni_tortoise", 0)) == 1, "hunt recorded")
	_done()
