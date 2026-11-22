extends TestCase
## Phase 6: Verdant Canopy vertical slice — gatherables on optional paths, lore stones, shrine
## healing, the objective HUD, and the gate: one full expedition from the hunt board to rewards.

const TEST_PROFILE := "user://test_profile_phase6.json"


func _fresh_profile() -> void:
	PlayerProfile.path = TEST_PROFILE
	if FileAccess.file_exists(TEST_PROFILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PROFILE))


func _restore_profile() -> void:
	PlayerProfile.path = PlayerProfile.DEFAULT_PATH


func test_optional_paths_have_gatherables_and_the_route_has_lore() -> void:
	var main := instantiate("res://scenes/main/main.tscn")
	await physics_frames(5)
	var pickups := main.get_tree().get_nodes_in_group("pickups")
	var lore := main.get_tree().get_nodes_in_group("lore_stones")
	check(pickups.size() >= 8, "gatherables placed (%d)" % pickups.size())
	check(lore.size() == 2, "two lore stones")
	var off_route := 0
	for p in pickups:
		if absf((p as Node3D).global_position.x) > 5.0:
			off_route += 1
	check(off_route >= 5, "most gatherables reward detours off the main line (%d)" % off_route)


func test_pickup_collects_once_and_is_kept_even_if_the_beast_escapes() -> void:
	_fresh_profile()
	var main := instantiate("res://scenes/main/main.tscn")
	var m := main.get_node("Expedition") as ExpeditionManager
	var player := main.get_node("Player") as PlayerController
	var hud := main.get_node("UI/ExpeditionHud") as ExpeditionHud
	await physics_frames(10)
	var pk := main.get_node("Level/Gatherables/glowcap_0") as Pickup
	var at := pk.global_position
	player.global_position = at + Vector3.UP * 0.2
	await physics_frames(10)
	player.global_position = at + Vector3(0, 0.2, 4)
	await physics_frames(5)
	player.global_position = at + Vector3.UP * 0.2  # Walk back over the spot.
	await physics_frames(10)
	check(pk.taken, "picked up")
	check(int(m.gathered.get(&"glowcap", 0)) == 1, "counted once (got %d)" % int(m.gathered.get(&"glowcap", 0)))
	m.debug_set_remaining(0.2)
	await process_frames(30)
	check(m.ended, "the beast escaped (timeout)")
	check(PlayerProfile.load_profile().count(&"glowcap") == 1, "gathered glowcap saved anyway")
	check(PlayerProfile.load_profile().hunts_completed.is_empty(), "no hunt credit for an escape")
	check(hud.is_timer_visible() == false, "timer hidden after timeout")
	_restore_profile()


func test_lore_stone_shows_its_text_once() -> void:
	var main := instantiate("res://scenes/main/main.tscn")
	var player := main.get_node("Player") as PlayerController
	await physics_frames(10)
	var stone := main.get_node("Level/Gatherables/LoreStone0") as LoreStone
	var reads := [0]
	stone.read.connect(func(_t: String) -> void: reads[0] += 1)
	player.global_position = stone.global_position + Vector3(1, 0.3, 1)
	await physics_frames(10)
	player.global_position = stone.global_position + Vector3(10, 0.3, 0)
	await physics_frames(5)
	player.global_position = stone.global_position + Vector3(1, 0.3, 1)
	await physics_frames(10)
	check(reads[0] == 1, "read once (got %d)" % reads[0])
	check(stone.was_read, "marked as read")


func test_lighting_a_shrine_heals_the_hunter() -> void:
	var main := instantiate("res://scenes/main/main.tscn")
	var player := main.get_node("Player") as PlayerController
	await physics_frames(10)
	var info := DamageInfo.new()
	info.amount = 60.0
	player.combat.health.apply_damage(info)
	await physics_frames(30)
	var cp := main.get_node("Level/Checkpoints/CheckpointGorge") as Checkpoint
	cp.activate(player)
	check_near(player.combat.health.current, player.combat.health.max_health, 0.01, "healed to full")


func test_objective_hud_counts_down_distance_to_the_arena() -> void:
	var main := instantiate("res://scenes/main/main.tscn")
	var player := main.get_node("Player") as PlayerController
	var hud := main.get_node("UI/ExpeditionHud") as ExpeditionHud
	await process_frames(5)
	check(hud.objective_text() == "Arena  94 m", "94 m from spawn (got '%s')" % hud.objective_text())
	player.global_position = Vector3(0, 0.3, -50)
	await process_frames(5)
	check(hud.objective_text() == "Arena  44 m", "closer after moving (got '%s')" % hud.objective_text())


func test_lighting_preset_stays_gloomy_but_readable() -> void:
	# Owner direction: dark, ominous tones, "a tiny bit" lighter than the first pass.
	var level := load("res://scenes/biomes/verdant_canopy.tscn").instantiate() as Node3D
	var env := (level.get_node("WorldEnvironment") as WorldEnvironment).environment
	var moon := level.get_node("Moonlight") as DirectionalLight3D
	check(env.ambient_light_energy > 3.5 and env.ambient_light_energy < 6.0, "ambient lifted a little (%.2f)" % env.ambient_light_energy)
	check(env.tonemap_exposure > 1.35 and env.tonemap_exposure < 1.8, "exposure lifted a little (%.2f)" % env.tonemap_exposure)
	check(moon.light_energy < 2.0, "still moonlight, not daylight (%.2f)" % moon.light_energy)
	level.free()


## Phase 6 gate: one complete expedition — choose the hunt on the board, cross the route with
## the timer running, gather on the way, enter the arena (timer stops and hides), defeat
## Kurogale, break its antlers, and see the rewards saved and shown.
func test_gate_full_expedition_from_hunt_board_to_rewards() -> void:
	_fresh_profile()
	var board := instantiate("res://scenes/ui/hunt_board.tscn") as HuntBoard
	await process_frames(3)
	var biome := board.biomes[0]
	var main := board.begin(biome, biome.hunts[0])
	_nodes.append(main)
	await physics_frames(20)
	var m := main.get_node("Expedition") as ExpeditionManager
	var player := main.get_node("Player") as PlayerController
	var boss := main.get_node("Level/Boss") as Kurogale
	var hud := main.get_node("UI/ExpeditionHud") as ExpeditionHud
	var results := main.get_node("UI/ExpeditionResults") as ExpeditionResults
	check(m.hunt.id == &"kurogale", "Kurogale hunt selected")
	check(m.timer.state == ExpeditionTimer.State.RUNNING and hud.is_timer_visible(), "45:00 countdown running")

	var reached := await BotHelpers.run_route(self, player, -100.0)
	check(reached, "crossed the Verdant Canopy to the arena (z=%.1f)" % player.global_position.z)
	check(m.arena_entered, "arena entered")
	check(m.timer.state == ExpeditionTimer.State.STOPPED and not hud.is_timer_visible(), "timer stopped and hidden in the arena")
	check(m.remaining_at_arena > 0.0 and m.remaining_at_arena < 2700.0, "time to spare recorded (%.1f)" % m.remaining_at_arena)
	check(int(m.gathered.get(&"glowcap", 0)) >= 1, "gathered a glowcap on the gorge stones")

	await BotHelpers.fight_boss(self, player, boss)
	check(boss.state == Kurogale.State.DEFEATED, "Kurogale defeated (hp %.0f)" % boss.get_health().current)
	check(boss.is_part_broken(&"antler"), "antlers broken")
	await physics_frames(int(boss.definition.death_time * 60.0) + 30)
	check(results.visible, "results screen shown")
	var profile := PlayerProfile.load_profile()
	check(profile.count(&"kurogale_hide") == 1, "hide saved")
	check(profile.count(&"thornback_antler") == 1, "antler saved")
	check(profile.count(&"glowcap") >= 1, "gathered materials saved")
	check(int(profile.hunts_completed.get("kurogale", 0)) == 1, "hunt recorded")
	_restore_profile()
