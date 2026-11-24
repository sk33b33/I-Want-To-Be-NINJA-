extends TestCase
## Phase 10: Stormcrag — distinct mountain mechanics (cliff climb, lightning that chases you,
## shelters, alternating wind gusts on a rain-slick ridge over a chasm, rain), Raijin's Echo the
## Sky Roc (lightning, weak to earth), the Stone Charm, unlocking, and the gate: a full hunt.

const TEST_PROFILE := "user://test_profile_phase10.json"
const SCENE := "res://scenes/main/expedition_stormcrag.tscn"


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


func _box_area(area: Area3D, size: Vector3, at: Vector3) -> Area3D:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	area.add_child(col)
	add_node(area)
	area.global_position = at
	return area


func _caller() -> StormCaller:
	var c := StormCaller.new()
	c.warning_material = load("res://data/materials/lightning_warning.tres")
	c.bolt_material = load("res://data/materials/bolt_flame.tres")
	return _box_area(c, Vector3(30, 4, 30), Vector3(0, 1, 0)) as StormCaller


# ---------------------------------------------------------------- mountain mechanics

func test_gust_warns_then_pushes_and_alternates_direction() -> void:
	make_floor()
	var p := make_player(Vector3(0, 0.05, 0))
	var g := GustZone.new()
	g.calm_time = 0.5
	g.warning_time = 0.5
	g.gust_time = 0.6
	_box_area(g, Vector3(40, 4, 6), Vector3(0, 1, 0))
	await physics_frames(5)
	var seen_warning_before_push := false
	var x0 := p.global_position.x
	for i in 90:
		await tree.physics_frame
		if g.phase == GustZone.Phase.WARNING and absf(p.global_position.x - x0) < 0.01:
			seen_warning_before_push = true
		if g.phase == GustZone.Phase.GUST and g.phase_time() > 0.5:
			break
	check(seen_warning_before_push, "warned before pushing")
	var pushed := p.global_position.x - x0
	check(pushed > 1.0, "first gust pushed +x (%.2f)" % pushed)
	for i in 120:  # Let the first gust finish.
		await tree.physics_frame
		if g.phase == GustZone.Phase.CALM:
			break
	await physics_frames(10)
	var x1 := p.global_position.x
	for i in 120:
		await tree.physics_frame
		if g.phase == GustZone.Phase.GUST and g.phase_time() > 0.5:
			break
	check(p.global_position.x < x1 - 1.0, "second gust pushed back the other way (%.2f -> %.2f)" % [x1, p.global_position.x])


func test_rain_slick_stone_makes_the_ninja_slide() -> void:
	make_floor(Vector3(200, 1, 200))
	var p := make_player(Vector3(0, 0.05, 40))
	await physics_frames(5)
	press("move_forward")
	await physics_frames(60)
	release("move_forward")
	var z0 := p.global_position.z
	await physics_frames(60)
	var dry_slide := z0 - p.global_position.z
	var wet := SurfaceZone.new()
	wet.traction = 0.35
	_box_area(wet, Vector3(20, 2, 200), Vector3(30, 0, 0))
	p.global_position = Vector3(30, 0.05, 40)
	await physics_frames(10)
	press("move_forward")
	await physics_frames(60)
	release("move_forward")
	z0 = p.global_position.z
	await physics_frames(60)
	var wet_slide := z0 - p.global_position.z
	check(wet_slide > dry_slide * 2.0, "slides further on wet stone (%.2f m vs %.2f m)" % [wet_slide, dry_slide])


func test_lightning_strikes_where_you_stand_after_a_warning() -> void:
	make_floor()
	var p := make_player(Vector3(0, 0.05, 0))
	var c := _caller()
	var strikes := []
	c.struck.connect(func(at: Vector3, hit: bool) -> void: strikes.append(hit))
	await physics_frames(10)
	var hp := p.combat.health.current
	var warned := false
	for i in int((c.interval + c.telegraph + 0.5) * 60.0):
		await tree.physics_frame
		if c.pending_strikes() > 0 and p.combat.health.current == hp:
			warned = true
		if not strikes.is_empty():
			break
	check(warned, "a warning ring came first")
	check(strikes.size() == 1 and strikes[0], "the bolt hit a hunter who stood still")
	check(p.combat.health.current < hp, "took lightning damage")


func test_moving_on_dodges_the_strike() -> void:
	make_floor(Vector3(200, 1, 200))
	var p := make_player(Vector3(0, 0.05, 0))
	var c := _caller()
	var strikes := []
	c.struck.connect(func(at: Vector3, hit: bool) -> void: strikes.append(hit))
	await physics_frames(5)
	for i in int((c.interval + c.telegraph + 0.5) * 60.0):
		await tree.physics_frame
		if c.pending_strikes() > 0 and Input.is_action_pressed("move_right") == false:
			press("move_right")  # Step away as soon as the ring appears.
		if not strikes.is_empty():
			break
	release("move_right")
	check(strikes.size() == 1 and not strikes[0], "the bolt missed a hunter who moved on")


func test_shelter_stops_the_lightning() -> void:
	make_floor()
	var p := make_player(Vector3(0, 0.05, 0))
	var c := _caller()
	_box_area(StormShelter.new(), Vector3(4, 3, 4), Vector3(0, 1, 0))
	await physics_frames(int((c.interval * 2.0 + c.telegraph) * 60.0))
	check(c.pending_strikes() == 0, "no strike called on a sheltered hunter")
	check_near(p.combat.health.current, p.combat.health.max_health, 0.01, "unhurt under the overhang")


func test_rain_follows_the_camera_and_thins_out_on_phones() -> void:
	_profile()
	var main := instantiate(SCENE)
	await process_frames(5)
	var rain := main.get_node("Level/Rain") as RainFX
	check(rain.emitting, "it is raining")
	check(rain.amount == maxi(50, int(rain.amount_high * QualityProfile.current().rain_scale)), "amount follows the quality preset")
	var low := load("res://data/quality/low.tres") as QualityPreset
	check(low.rain_scale <= 0.25, "phone tier uses a quarter of the drops or fewer")
	var cam := main.get_viewport().get_camera_3d()
	check(cam != null and rain.global_position.distance_to(cam.global_position + Vector3.UP * rain.height) < 0.5, "rain hangs above the camera")
	_done()


func test_stormcrag_has_every_distinct_hazard_and_its_own_look() -> void:
	_profile()
	var main := instantiate(SCENE)
	await physics_frames(3)
	var t := main.get_tree()
	# The original route's hazards (the long route adds more of each, under RouteBuilder).
	var original := func(group: String) -> int:
		return t.get_nodes_in_group(group).filter(func(n: Node) -> bool: return not (n.get_parent() is RouteBuilder)).size()
	check(original.call("gust_zones") == 1, "gale ridge gusts on the original route")
	check(original.call("storm_callers") == 1, "storm plateau on the original route")
	check(t.get_nodes_in_group("storm_shelters").size() == 2, "two shelters")
	check(t.get_nodes_in_group("rain_fx").size() == 1, "rain")
	check((main.get_node("Level/Hazards/GaleGust") as GustZone).traction < 0.5, "the ridge is slick")
	var cliff := main.get_node("Level/RouteGeometry/CragCliff") as CSGBox3D
	check(cliff.collision_layer & 4 != 0, "the cliff is climbable")
	for g in ["fire_vents", "sinking_stones", "sinking_rafts", "fog_zones", "poison_pools"]:
		check(t.get_nodes_in_group(g).is_empty(), "no %s reused" % g)
	var boss := main.get_node("Level/Boss") as BossController
	check(boss.definition.id == &"raijins_echo", "Raijin's Echo waits in the arena")
	check((main.get_node("Expedition") as ExpeditionManager).hunt.id == &"raijins_echo", "its hunt")
	_done()


# ---------------------------------------------------------------- boss + elements

func test_sky_roc_is_weak_to_earth_and_shrugs_off_lightning() -> void:
	var def := load("res://data/bosses/raijins_echo.tres") as BossDefinition
	check_near(def.elements.multiplier(&"earth"), 1.5, 0.001, "earth x1.5")
	check_near(def.elements.multiplier(&"lightning"), 0.25, 0.001, "lightning x0.25")
	check(def.attacks.size() == 4, "four attacks")
	var kinds := {}
	for a in def.attacks:
		kinds[a.kind] = true
		check(a.telegraph_time >= 1.0 and a.counterplay != "", "%s telegraphs and documents counterplay" % a.id)
	check(kinds.size() == 4, "uses all four attack kinds")


func test_stone_charm_turns_the_talisman_to_earth() -> void:
	_profile([&"stone_charm"])
	var main := instantiate(SCENE)
	var p := main.get_node("Player") as PlayerController
	await physics_frames(10)
	check(p.combat.skill_element() == &"earth", "talisman element is earth")
	var boss := main.get_node("Level/Boss") as BossController
	var info := DamageInfo.new()
	info.amount = 20.0
	info.element = p.combat.skill_element()
	(boss.get_node("BodyHurtbox") as Hurtbox).receive(info)
	check_near(boss.get_health().max_health - boss.get_health().current, 30.0, 0.01, "earth hits for 1.5x")
	var hud: PlayerHud = main.find_children("*", "PlayerHud", true, false)[0]
	await process_frames(2)
	check(hud.skill_text().begins_with("Stone Talisman"), "HUD names the Stone Talisman (got '%s')" % hud.skill_text())
	_done()


func test_every_sky_roc_attack_warns_before_it_hurts() -> void:
	make_floor(Vector3(80, 1, 80))
	var boss := instantiate("res://scenes/bosses/raijins_echo.tscn") as BossController
	boss.global_position = Vector3(0, 0.05, 0)
	boss.rotation.y = PI
	boss.arena_center = Vector3.ZERO
	var p := make_player(Vector3(0, 0.05, 4))
	await physics_frames(10)
	boss.awaken()
	await physics_frames(int(boss.definition.intro_time * 60.0) + 5)
	for id in [&"wing_shear", &"storm_call", &"dive"]:
		p.combat.health.reset()
		boss.global_position = Vector3(0, 0.05, 0)
		p.global_position = boss.global_position + Vector3(0, 0.05, 4.0 if id == &"wing_shear" else 9.0)
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


func test_crest_breaks_once_and_rewards_once() -> void:
	_profile()
	var main := instantiate(SCENE)
	var m := main.get_node("Expedition") as ExpeditionManager
	var boss := main.get_node("Level/Boss") as BossController
	await physics_frames(5)
	(main.get_node("Player") as PlayerController).global_position = Vector3(0, 0.5, -104)
	await physics_frames(10)
	var crest := boss.get_node("Visual/CrestHurtbox") as Hurtbox
	for i in 12:
		var a := DamageInfo.new()
		a.amount = 30.0
		crest.receive(a)
	check(boss.is_part_broken(&"crest"), "crest broken")
	check(int(m.run_rewards.get(&"storm_crest", 0)) == 1, "one Storm Crest")
	check(not (boss.get_node("Visual/Crest") as Node3D).visible and (boss.get_node("Visual/CrestStub") as Node3D).visible, "stub shown")
	_done()


# ---------------------------------------------------------------- progression

func test_stormcrag_unlocks_after_nami() -> void:
	var biome := load("res://data/biomes/biome_stormcrag.tres") as BiomeDefinition
	_profile([], {"kurogale": 1, "ashen_oni_tortoise": 1})
	check(not HuntBoard.is_open(biome, PlayerProfile.load_profile()), "locked before Nami")
	_profile([], {"kurogale": 1, "ashen_oni_tortoise": 1, "nami": 1})
	check(HuntBoard.is_open(biome, PlayerProfile.load_profile()), "open after defeating Nami")
	var board := instantiate("res://scenes/ui/hunt_board.tscn") as HuntBoard
	await process_frames(2)
	check(board.get_start_button(&"raijins_echo") != null, "hunt board offers the Raijin's Echo hunt")
	_done()


func test_stormcrag_recipes_are_in_the_forge() -> void:
	var catalog: CraftingCatalog = load("res://data/crafting/catalog.tres")
	for id in [&"stone_charm", &"thunderfang_blades", &"galeweave_garb"]:
		check(catalog.find_gear(id) != null, "%s can be forged" % id)
	check(catalog.find_gear(&"stone_charm").skill_element == &"earth", "Stone Charm is the counter to the Sky Roc")
	check(catalog.find_gear(&"thunderfang_blades").blade_element == &"lightning", "Thunderfang Blades spark (good vs Nami)")
	var stone_recipe: RecipeDefinition = null
	for r in catalog.recipes:
		if r.result.id == &"stone_charm":
			stone_recipe = r
	var ids: Array = stone_recipe.inputs.map(func(i: ItemDefinition) -> StringName: return i.id)
	check(ids.has(&"ruin_shard") and ids.has(&"spirit_moss"), "Stone Charm is forged from materials found before Stormcrag")


# ---------------------------------------------------------------- gate

## Phase 10 gate: a complete Stormcrag hunt. Crossing needs every mountain skill (the cliff climb,
## not stopping under the storm, timing the gusts on the slick ridge); the fight uses the Stone
## Charm against the Sky Roc's earth weakness.
func test_gate_full_stormcrag_hunt() -> void:
	_profile([&"stone_charm"], {"kurogale": 1, "ashen_oni_tortoise": 1, "nami": 1})
	var main := instantiate(SCENE)
	_nodes.append(main)
	var m := main.get_node("Expedition") as ExpeditionManager
	var player := main.get_node("Player") as PlayerController
	var boss := main.get_node("Level/Boss") as BossController
	var falls := [0]
	player.respawned.connect(func(_at: Vector3) -> void: falls[0] += 1)
	await physics_frames(20)
	check(m.timer.state == ExpeditionTimer.State.RUNNING, "45:00 countdown running")
	var crossed := await BotHelpers.run_route_stormcrag(self, player, main.get_node("Level"), -100.0)
	check(crossed, "crossed Stormcrag (z=%.1f)" % player.global_position.z)
	check(falls[0] == 0, "never blown off the ridge (falls=%d)" % falls[0])
	check(m.arena_entered and m.timer.state == ExpeditionTimer.State.STOPPED, "arena entered, timer stopped")
	await BotHelpers.fight_boss(self, player, boss)
	check(boss.state == BossController.State.DEFEATED, "Raijin's Echo defeated (hp %.0f)" % boss.get_health().current)
	check(boss.is_part_broken(&"crest"), "crest broken")
	await physics_frames(int(boss.definition.death_time * 60.0) + 30)
	var profile := PlayerProfile.load_profile()
	check(profile.count(&"storm_crest") == 1 and profile.count(&"roc_plume") == 1, "rewards saved")
	check(int(profile.hunts_completed.get("raijins_echo", 0)) == 1, "hunt recorded")
	_done()
