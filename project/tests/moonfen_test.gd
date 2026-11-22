extends TestCase
## Phase 9: Moonfen — distinct swamp mechanics (mud, stream current, poison, fog bank, sinking
## reed rafts, deep bog), Nami the Lantern Serpent (water, weak to lightning), the Storm Charm,
## unlocking, and the gate: a full Moonfen hunt.

const TEST_PROFILE := "user://test_profile_phase9.json"
const SCENE := "res://scenes/main/expedition_moonfen.tscn"


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


func _zone(size: Vector3, at: Vector3, props: Dictionary) -> SurfaceZone:
	var z := SurfaceZone.new()
	for k: String in props:
		z.set(k, props[k])
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	z.add_child(col)
	add_node(z)
	z.global_position = at
	return z


## Run forward for `frames` and return the distance covered.
func _run_distance(p: PlayerController, frames: int) -> float:
	var start := p.global_position
	press("move_forward")
	await physics_frames(frames)
	release("move_forward")
	return Vector2(p.global_position.x - start.x, p.global_position.z - start.z).length()


# ---------------------------------------------------------------- swamp mechanics

func test_mud_slows_the_hunter_and_blocks_jumping() -> void:
	make_floor()
	var p := make_player(Vector3(0, 0.05, 0))
	await physics_frames(10)
	var free_run: float = await _run_distance(p, 60)
	p.global_position = Vector3(0, 0.05, 30)
	_zone(Vector3(10, 1, 30), Vector3(0, 0, 20), {"speed_multiplier": 0.45, "blocks_jump": true})
	await physics_frames(10)
	var mud_run: float = await _run_distance(p, 60)
	check(mud_run < free_run * 0.6, "slower in mud (%.1f m vs %.1f m)" % [mud_run, free_run])
	await physics_frames(20)
	press("jump")
	await physics_frames(10)
	release("jump")
	check(p.global_position.y < 0.3, "cannot jump out of mud (y=%.2f)" % p.global_position.y)
	p.global_position = Vector3(20, 0.05, 0)  # Out of the mud: jumping works again.
	await physics_frames(10)
	press("jump")
	await physics_frames(10)
	release("jump")
	check(p.global_position.y > 0.8, "jumps on firm ground (y=%.2f)" % p.global_position.y)


func test_stream_current_carries_a_player_who_stands_still() -> void:
	make_floor()
	var p := make_player(Vector3(0, 0.05, 0))
	_zone(Vector3(30, 1.5, 4), Vector3(0, 0, 0), {"current": Vector3(2.2, 0, 0)})
	await physics_frames(60)
	check(p.global_position.x > 1.2, "drifted downstream (x=%.2f)" % p.global_position.x)
	var x := p.global_position.x
	p.global_position = Vector3(x, 0.05, 6)  # Step out of the stream.
	await physics_frames(40)
	var x2 := p.global_position.x
	await physics_frames(30)
	check(absf(p.global_position.x - x2) < 0.05, "no drift on the bank")


func test_poison_pool_hurts_over_time_only_inside() -> void:
	make_floor()
	var p := make_player(Vector3(0, 0.05, 0))
	_zone(Vector3(4, 1.2, 4), Vector3(0, 0, 0), {"damage_per_tick": 4.0, "element": &"poison"})
	await physics_frames(70)
	check(p.combat.health.current < 100.0, "poisoned while standing in it (%.0f)" % p.combat.health.current)
	var hp := p.combat.health.current
	p.global_position = Vector3(10, 0.05, 0)
	await physics_frames(70)
	check_near(p.combat.health.current, hp, 0.01, "no poison outside")


func test_fog_bank_closes_in_and_clears_again() -> void:
	_profile()
	var main := instantiate(SCENE)
	var p := main.get_node("Player") as PlayerController
	var fog := main.get_node("Level/Hazards/FogBank") as FogZone
	var env := (main.get_node("Level/WorldEnvironment") as WorldEnvironment).environment
	await physics_frames(10)
	var clear := env.fog_density
	p.global_position = Vector3(1.6, 0.3, -43.5)
	await physics_frames(int(fog.blend_time * 60.0) + 20)
	check(env.fog_density > clear * 3.0, "fog thickens inside (%.3f -> %.3f)" % [clear, env.fog_density])
	check(main.get_tree().get_nodes_in_group("spirit_lanterns").size() == 4, "spirit lanterns mark the way")
	p.global_position = Vector3(0, 0.3, -26)
	await physics_frames(int(fog.blend_time * 60.0) + 20)
	check_near(env.fog_density, clear, 0.002, "fog clears after leaving")
	_done()


func test_reed_raft_sinks_under_your_weight_and_floats_back() -> void:
	make_floor(Vector3(40, 1, 40), Vector3(0, -10, 0))  # Below the raft, above the kill height.
	var raft := instantiate("res://scenes/world/sinking_raft.tscn") as SinkingRaft
	raft.global_position = Vector3.ZERO
	await physics_frames(2)
	var p := make_player(Vector3(0, 0.1, 0))
	await physics_frames(15)
	check(raft.is_ridden() and p.is_on_floor(), "standing on the raft")
	var y_early := raft.global_position.y
	await physics_frames(int(raft.hold_time * 60.0) + 10)
	check(raft.sink_amount() > 0.99, "fully under after %.1f s" % raft.hold_time)
	check(y_early > -0.5, "sinks slowly at first (y=%.2f)" % y_early)
	check(p.global_position.y < -1.5, "the player went down with it (y=%.2f)" % p.global_position.y)
	p.global_position = Vector3(10, -9, 0)  # Step off onto the floor below.
	await physics_frames(int(60.0 / raft.rise_rate) + 20)
	check(raft.sink_amount() < 0.01 and absf(raft.global_position.y) < 0.01, "floated back up")


func test_deep_bog_drowns_and_returns_the_player_to_the_checkpoint() -> void:
	_profile()
	var main := instantiate(SCENE)
	var p := main.get_node("Player") as PlayerController
	await physics_frames(10)
	var cp := main.get_node("Level/Checkpoints/CheckpointBog") as Checkpoint
	cp.activate(p)
	var bog := main.get_node("Level/Hazards/DeepBog") as LavaZone
	var falls := [0]
	bog.burned.connect(func(_pl: PlayerController) -> void: falls[0] += 1)
	p.global_position = Vector3(0, -1.6, -60)
	await physics_frames(10)
	check(falls[0] == 1, "fell into the bog once")
	check(p.combat.health.current < p.combat.health.max_health, "took damage")
	check(bog.element == &"water", "drowning is water, not fire")
	check(p.global_position.distance_to(cp.global_position) < 1.5, "back at the bog shrine")
	_done()


func test_moonfen_has_every_distinct_hazard_and_its_own_look() -> void:
	_profile()
	var main := instantiate(SCENE)
	await physics_frames(3)
	var t := main.get_tree()
	var zones := t.get_nodes_in_group("surface_zones")
	var mud := 0
	var current := 0
	for z: SurfaceZone in zones:
		mud += 1 if z.blocks_jump else 0
		current += 1 if z.current != Vector3.ZERO else 0
	check(mud == 1 and current == 1, "mud flats and a stream current")
	check(t.get_nodes_in_group("poison_pools").size() == 3, "three poison pools")
	check(t.get_nodes_in_group("fog_zones").size() == 1, "a fog bank")
	check(t.get_nodes_in_group("sinking_rafts").size() == 4, "four reed rafts")
	check(t.get_nodes_in_group("fire_vents").is_empty() and t.get_nodes_in_group("sinking_stones").is_empty(), "no Emberwild hazards reused")
	var boss := main.get_node("Level/Boss") as BossController
	check(boss.definition.id == &"nami", "Nami waits in the arena")
	check((main.get_node("Expedition") as ExpeditionManager).hunt.id == &"nami", "its hunt")
	var sky := ((main.get_node("Level/WorldEnvironment") as WorldEnvironment).environment.sky.sky_material) as ShaderMaterial
	var horizon: Color = sky.get_shader_parameter("horizon")
	check(horizon.b > horizon.r and horizon.b > horizon.g, "violet night sky")
	_done()


# ---------------------------------------------------------------- boss + elements

func test_nami_is_weak_to_lightning_and_shrugs_off_water() -> void:
	var def := load("res://data/bosses/nami.tres") as BossDefinition
	check_near(def.elements.multiplier(&"lightning"), 1.5, 0.001, "lightning x1.5")
	check_near(def.elements.multiplier(&"water"), 0.5, 0.001, "water x0.5")
	check_near(def.elements.multiplier(&"fire"), 0.5, 0.001, "fire x0.5")
	check(def.attacks.size() == 4, "four attacks")
	var kinds := {}
	for a in def.attacks:
		kinds[a.kind] = true
		check(a.telegraph_time >= 1.0 and a.counterplay != "", "%s telegraphs and documents counterplay" % a.id)
	check(kinds.size() == 4, "uses all four attack kinds")


func test_storm_charm_turns_the_talisman_to_lightning() -> void:
	_profile([&"storm_charm"])
	var main := instantiate(SCENE)
	var p := main.get_node("Player") as PlayerController
	await physics_frames(10)
	check(p.combat.skill_element() == &"lightning", "talisman element is lightning")
	var boss := main.get_node("Level/Boss") as BossController
	var info := DamageInfo.new()
	info.amount = 20.0
	info.element = p.combat.skill_element()
	(boss.get_node("BodyHurtbox") as Hurtbox).receive(info)
	check_near(boss.get_health().max_health - boss.get_health().current, 30.0, 0.01, "lightning hits for 1.5x")
	var hud: PlayerHud = main.find_children("*", "PlayerHud", true, false)[0]
	await process_frames(2)
	check(hud.skill_text().begins_with("Storm Talisman"), "HUD names the Storm Talisman (got '%s')" % hud.skill_text())
	_done()


func test_every_nami_attack_warns_before_it_hurts() -> void:
	make_floor(Vector3(80, 1, 80))
	var boss := instantiate("res://scenes/bosses/nami.tscn") as BossController
	boss.global_position = Vector3(0, 0.05, 0)
	boss.rotation.y = PI
	boss.arena_center = Vector3.ZERO
	var p := make_player(Vector3(0, 0.05, 4))
	await physics_frames(10)
	boss.awaken()
	await physics_frames(int(boss.definition.intro_time * 60.0) + 5)
	for id in [&"flood_wave", &"lantern_lure", &"dive_strike"]:
		p.combat.health.reset()
		boss.global_position = Vector3(0, 0.05, 0)
		p.global_position = boss.global_position + Vector3(0, 0.05, 5.0 if id == &"flood_wave" else 9.0)
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


func test_lantern_breaks_once_and_rewards_once() -> void:
	_profile()
	var main := instantiate(SCENE)
	var m := main.get_node("Expedition") as ExpeditionManager
	var boss := main.get_node("Level/Boss") as BossController
	await physics_frames(5)
	(main.get_node("Player") as PlayerController).global_position = Vector3(0, 0.5, -104)
	await physics_frames(10)
	var lantern := boss.get_node("Visual/LanternHurtbox") as Hurtbox
	for i in 12:
		var a := DamageInfo.new()
		a.amount = 30.0
		lantern.receive(a)
	check(boss.is_part_broken(&"lantern"), "lantern broken")
	check(int(m.run_rewards.get(&"lantern_pearl", 0)) == 1, "one Lantern Pearl")
	check(not (boss.get_node("Visual/Lantern") as Node3D).visible and (boss.get_node("Visual/LanternStub") as Node3D).visible, "stub shown")
	_done()


# ---------------------------------------------------------------- progression

func test_moonfen_unlocks_after_the_oni_tortoise() -> void:
	var biome := load("res://data/biomes/biome_moonfen.tres") as BiomeDefinition
	_profile([], {"kurogale": 1})
	check(not HuntBoard.is_open(biome, PlayerProfile.load_profile()), "locked before the Tortoise")
	_profile([], {"kurogale": 1, "ashen_oni_tortoise": 1})
	check(HuntBoard.is_open(biome, PlayerProfile.load_profile()), "open after defeating the Tortoise")
	var board := instantiate("res://scenes/ui/hunt_board.tscn") as HuntBoard
	await process_frames(2)
	check(board.get_start_button(&"nami") != null, "hunt board offers the Nami hunt")
	_done()


func test_moonfen_recipes_are_in_the_forge() -> void:
	var catalog: CraftingCatalog = load("res://data/crafting/catalog.tres")
	for id in [&"storm_charm", &"moonfang_blades", &"fenscale_mail"]:
		check(catalog.find_gear(id) != null, "%s can be forged" % id)
	check(catalog.find_gear(&"storm_charm").skill_element == &"lightning", "Storm Charm is the counter to Nami")
	var storm_recipe: RecipeDefinition = null
	for r in catalog.recipes:
		if r.result.id == &"storm_charm":
			storm_recipe = r
	var ids: Array = storm_recipe.inputs.map(func(i: ItemDefinition) -> StringName: return i.id)
	check(ids.has(&"ember_crystal") and ids.has(&"ruin_shard"), "Storm Charm is forged from materials found before Moonfen")


# ---------------------------------------------------------------- gate

## Phase 9 gate: a complete Moonfen hunt. Crossing needs every swamp skill (wading the mud,
## fighting the current, reading the lanterns in the fog, never stopping on a raft, the root
## climb); the fight uses the Storm Charm against Nami's lightning weakness.
func test_gate_full_moonfen_hunt() -> void:
	_profile([&"storm_charm"], {"kurogale": 1, "ashen_oni_tortoise": 1})
	var main := instantiate(SCENE)
	_nodes.append(main)
	var m := main.get_node("Expedition") as ExpeditionManager
	var player := main.get_node("Player") as PlayerController
	var boss := main.get_node("Level/Boss") as BossController
	var bog := main.get_node("Level/Hazards/DeepBog") as LavaZone
	var falls := [0]
	bog.burned.connect(func(_pl: PlayerController) -> void: falls[0] += 1)
	await physics_frames(20)
	check(m.timer.state == ExpeditionTimer.State.RUNNING, "45:00 countdown running")
	var crossed := await BotHelpers.run_route_moonfen(self, player, -100.0)
	check(crossed, "crossed Moonfen (z=%.1f)" % player.global_position.z)
	check(falls[0] == 0, "never sank into the bog (falls=%d)" % falls[0])
	check(m.arena_entered and m.timer.state == ExpeditionTimer.State.STOPPED, "arena entered, timer stopped")
	await BotHelpers.fight_boss(self, player, boss)
	check(boss.state == BossController.State.DEFEATED, "Nami defeated (hp %.0f)" % boss.get_health().current)
	check(boss.is_part_broken(&"lantern"), "lantern broken")
	await physics_frames(int(boss.definition.death_time * 60.0) + 30)
	var profile := PlayerProfile.load_profile()
	check(profile.count(&"lantern_pearl") == 1 and profile.count(&"nami_scale") == 1, "rewards saved")
	check(int(profile.hunts_completed.get("nami", 0)) == 1, "hunt recorded")
	_done()
