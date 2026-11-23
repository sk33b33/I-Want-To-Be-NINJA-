extends TestCase
## Phase 13 part 1: a second beast in every jungle — data, telegraphs, weakness, part breaking,
## the hunt putting its beast into the arena, the unlock order, and a bot that beats each one.

const TEST_PROFILE := "user://test_profile_beasts.json"
## [hunt id, jungle expedition scene, first beast of that jungle, part id, weakness element]
const BEASTS := [
	["kamakiri", "res://scenes/main/main.tscn", "kurogale", &"scythes", &"fire"],
	["kasai", "res://scenes/main/expedition_emberwild.tscn", "ashen_oni_tortoise", &"tail", &"water"],
	["gamakage", "res://scenes/main/expedition_moonfen.tscn", "nami", &"sac", &"lightning"],
	["kazekiri", "res://scenes/main/expedition_stormcrag.tscn", "raijins_echo", &"fangs", &"earth"],
]


## The talisman a hunter brings for each weakness (fire is the default talisman).
const CHARM_FOR := {&"water": &"mist_charm", &"lightning": &"storm_charm", &"earth": &"stone_charm"}


func _profile(hunts: Dictionary = {}, charm: StringName = &"") -> void:
	PlayerProfile.path = TEST_PROFILE
	if FileAccess.file_exists(TEST_PROFILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PROFILE))
	var p := PlayerProfile.new()
	if charm != &"":
		var catalog: CraftingCatalog = load("res://data/crafting/catalog.tres")
		p.gear_owned.append(String(charm))
		Forge.equip(p, catalog.find_gear(charm))
	p.hunts_completed = hunts
	p.save()


func _done() -> void:
	PlayerProfile.path = PlayerProfile.DEFAULT_PATH


## The expedition for a hunt, as the hunt board would start it (hunt injected before ready).
func _expedition(row: Array) -> Node:
	var scene := (load(row[1]) as PackedScene).instantiate()
	(scene.get_node("Expedition") as ExpeditionManager).hunt = load("res://data/hunts/%s.tres" % row[0])
	return add_node(scene)


func test_every_beast_is_complete_data() -> void:
	for row in BEASTS:
		var def := load("res://data/bosses/%s.tres" % row[0]) as BossDefinition
		var hunt := load("res://data/hunts/%s.tres" % row[0]) as HuntDefinition
		check(def != null and hunt != null and hunt.boss_scene != null, "%s has boss data, a scene and a hunt" % row[0])
		check(hunt.requires_hunt == StringName(row[2]), "%s opens after %s" % [row[0], row[2]])
		check(def.attacks.size() == 4, "%s has four attacks" % row[0])
		var kinds := {}
		for a in def.attacks:
			kinds[a.kind] = true
			check(a.telegraph_time >= 1.0 and a.counterplay != "", "%s/%s telegraphs and explains counterplay" % [row[0], a.id])
		check(kinds.size() == 4, "%s uses all four attack kinds" % row[0])
		check(def.elements.multiplier(row[4]) >= 1.5, "%s is weak to %s" % [row[0], row[4]])
		check(def.parts.size() == 1 and def.parts[0].id == row[3] and def.parts[0].reward != null, "%s has its breakable %s" % [row[0], row[3]])
		check(def.victory_rewards.size() == 1, "%s gives a victory reward" % row[0])
		var biome_has := false
		for b in DirAccess.get_files_at("res://data/biomes"):
			if b.begins_with("biome_"):
				var bd := load("res://data/biomes/" + b) as BiomeDefinition
				for h in bd.hunts:
					biome_has = biome_has or h.id == StringName(row[0])
		check(biome_has, "%s is listed in its jungle" % row[0])


func test_every_beast_attack_warns_before_it_hurts() -> void:
	for row in BEASTS:
		make_floor(Vector3(80, 1, 80))
		var boss := instantiate("res://scenes/bosses/%s.tscn" % row[0]) as BossController
		boss.global_position = Vector3.ZERO
		boss.rotation.y = PI
		boss.arena_center = Vector3.ZERO
		var p := make_player(Vector3(0, 0.05, 4))
		await physics_frames(10)
		boss.awaken()
		await physics_frames(int(boss.definition.intro_time * 60.0) + 5)
		for a in boss.definition.attacks:
			if a.enraged_only:
				continue
			# The beast keeps fighting between forced attacks: wait until it is between attacks and
			# none of its own eruptions are still pending, so every hit below belongs to `a`.
			for i in 600:
				await tree.physics_frame
				if boss.state == BossController.State.STALK and tree.get_nodes_in_group("root_snares").is_empty():
					break
			p.combat.health.reset()
			boss.global_position = Vector3(0, 0.05, 0)
			p.global_position = Vector3(0, 0.05, 4.0 if a.kind == BossAttackDefinition.Kind.FRONT else 9.0)
			await physics_frames(2)
			boss.debug_force_attack(a.id)
			var t := 0.0
			var hit_at := -1.0
			for i in int((a.telegraph_time + 2.5) * 60.0):
				await tree.physics_frame
				t += 1.0 / 60.0
				if hit_at < 0.0 and p.combat.health.current < p.combat.health.max_health:
					hit_at = t
			check(hit_at > 0.0, "%s/%s connected with a player who stood still" % [row[0], a.id])
			check(hit_at >= a.telegraph_time - 0.02, "%s/%s warned first (%.2f / %.2f)" % [row[0], a.id, hit_at, a.telegraph_time])
			await physics_frames(150)
		cleanup()
		await physics_frames(3)


func test_choosing_the_hunt_puts_its_beast_in_the_arena_and_the_part_rewards_once() -> void:
	for row in BEASTS:
		_profile()
		var main := _expedition(row)
		await physics_frames(5)
		var m := main.get_node("Expedition") as ExpeditionManager
		var boss := main.get_node("Level/Boss") as BossController
		check(boss.definition.id == StringName(row[0]), "%s is in the arena (got %s)" % [row[0], boss.definition.id])
		check(m.boss == boss, "the expedition tracks it")
		# Nothing of the jungle's first boss may come along (bodies, hurtboxes, hitboxes).
		var scene_children := ((load("res://data/hunts/%s.tres" % row[0]) as HuntDefinition).boss_scene.instantiate())
		var expected: Array = scene_children.get_children().map(func(c: Node) -> StringName: return c.name)
		scene_children.free()
		var got: Array = boss.get_children().map(func(c: Node) -> StringName: return c.name)
		check(got == expected, "%s has only its own nodes (got %s)" % [row[0], got])
		check(main.find_children("*", "BossController", true, false).size() == 1, "%s: one boss in the level" % row[0])
		(main.get_node("Player") as PlayerController).global_position = Vector3(0, 0.5, -104)
		await physics_frames(10)
		check(m.arena_entered and m.timer.state == ExpeditionTimer.State.STOPPED, "%s: arena entered, timer stopped" % row[0])
		var part := boss.get_node("Visual/PartHurtbox") as Hurtbox
		for i in 12:
			var d := DamageInfo.new()
			d.amount = 30.0
			part.receive(d)
		check(boss.is_part_broken(row[3]), "%s part broken" % row[0])
		var reward := boss.definition.parts[0].reward.id
		check(int(m.run_rewards.get(reward, 0)) == 1, "%s rewards %s once" % [row[0], reward])
		check(not (boss.get_node("Visual/Part") as Node3D).visible and (boss.get_node("Visual/PartStub") as Node3D).visible, "%s shows the broken part" % row[0])
		_nodes.erase(main)
		main.free()
		await physics_frames(3)
	_done()


func test_second_beasts_unlock_after_the_first_or_with_the_testing_switch() -> void:
	_profile({"kurogale": 1})
	var verdant := load("res://data/biomes/biome_verdant_canopy.tres") as BiomeDefinition
	var stormcrag := load("res://data/biomes/biome_stormcrag.tres") as BiomeDefinition
	var profile := PlayerProfile.load_profile()
	check(HuntBoard.is_hunt_open(verdant, verdant.hunts[1], profile), "Kamakiri opens after Kurogale")
	_profile()
	profile = PlayerProfile.load_profile()
	check(not HuntBoard.is_hunt_open(verdant, verdant.hunts[1], profile), "Kamakiri locked before Kurogale")
	check(HuntBoard.is_hunt_open(verdant, verdant.hunts[0], profile), "Kurogale always open")
	var board := instantiate("res://scenes/ui/hunt_board.tscn") as HuntBoard
	await process_frames(3)
	check(board.get_start_button(&"kurogale") != null and board.get_start_button(&"kamakiri") == null, "board: second beast locked")
	GameSettings.unlock_all = true
	check(HuntBoard.is_hunt_open(stormcrag, stormcrag.hunts[1], profile), "testing switch opens Kazekiri")
	GameSettings.unlock_all = false
	_done()


## Phase 13 gate (part 1): the bot beats each new beast in its arena.
func test_gate_bot_defeats_every_new_beast() -> void:
	for row in BEASTS:
		_profile({}, CHARM_FOR.get(row[4], &""))
		var main := _expedition(row)
		await physics_frames(10)
		var player := main.get_node("Player") as PlayerController
		var boss := main.get_node("Level/Boss") as BossController
		player.global_position = Vector3(0, 0.5, -104)
		await physics_frames(20)
		await BotHelpers.fight_boss(self, player, boss)
		check(boss.state == BossController.State.DEFEATED, "%s defeated (hp %.0f)" % [row[0], boss.get_health().current])
		await physics_frames(int(boss.definition.death_time * 60.0) + 30)
		check(int(PlayerProfile.load_profile().hunts_completed.get(row[0], 0)) == 1, "%s hunt recorded" % row[0])
		_nodes.erase(main)
		main.free()
		await physics_frames(3)
	_done()
