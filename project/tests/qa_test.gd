extends TestCase
## Phase 12 QA pass: edge cases in saving, the expedition timer and hunt flow, camera/lock-on,
## bosses, crafting and respawns. Each test names the situation and the expected behaviour.

const TEST_PROFILE := "user://test_profile_phase12.json"


func _fresh(materials: Dictionary = {}) -> void:
	PlayerProfile.path = TEST_PROFILE
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		if FileAccess.file_exists(TEST_PROFILE + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PROFILE + suffix))
	if not materials.is_empty():
		var p := PlayerProfile.new()
		for id in materials:
			p.add_material(StringName(id), int(materials[id]))
		p.save()


func _done() -> void:
	PlayerProfile.path = PlayerProfile.DEFAULT_PATH


func _write(text: String) -> void:
	var f := FileAccess.open(TEST_PROFILE, FileAccess.WRITE)
	f.store_string(text)
	f.close()


# ---------------------------------------------------------------- save / load

func test_corrupt_save_falls_back_to_the_backup_instead_of_wiping_progress() -> void:
	_fresh({"glowcap": 3})
	var p := PlayerProfile.load_profile()
	p.add_material(&"ruin_shard", 1)
	p.save()  # Second save: the first good file becomes the backup.
	_write('{"version": 2, "materials": {"glowcap": 5')  # Torn write.
	var loaded := PlayerProfile.load_profile()
	check(loaded.count(&"glowcap") == 3, "recovered from the backup (glowcap %d)" % loaded.count(&"glowcap"))
	check(FileAccess.file_exists(TEST_PROFILE + ".corrupt"), "the damaged file is kept aside, not silently overwritten")
	_done()


func test_save_with_wrong_types_loads_what_it_can() -> void:
	_fresh()
	_write('{"version": 2, "materials": ["glowcap"], "hunts_completed": {"kurogale": 1}, "gear_owned": "oops", "equipped": 7}')
	var p := PlayerProfile.load_profile()
	check(p.materials.is_empty() and p.gear_owned.is_empty() and p.equipped.is_empty(), "bad fields become empty")
	check(int(p.hunts_completed.get("kurogale", 0)) == 1, "good fields survive")
	_done()


func test_save_is_written_atomically() -> void:
	_fresh({"glowcap": 1})
	var p := PlayerProfile.load_profile()
	p.add_material(&"glowcap", 1)
	check(p.save(), "saved")
	check(not FileAccess.file_exists(TEST_PROFILE + ".tmp"), "no temp file left behind")
	check(FileAccess.file_exists(TEST_PROFILE + ".bak"), "previous save kept as a backup")
	check(PlayerProfile.load_profile().count(&"glowcap") == 2, "new data on disk")
	_done()


# ---------------------------------------------------------------- hunt flow

func test_leaving_mid_hunt_keeps_gathered_materials_like_an_escape() -> void:
	_fresh()
	var main := instantiate("res://scenes/main/main.tscn")
	var m := main.get_node("Expedition") as ExpeditionManager
	await physics_frames(5)
	m.collect(load("res://data/items/glowcap.tres"), 2)
	m.return_to_hunt_board()
	await process_frames(3)
	check(PlayerProfile.load_profile().count(&"glowcap") == 2, "gathered glowcaps saved when quitting to the dojo")
	check(PlayerProfile.load_profile().hunts_completed.is_empty(), "no hunt credit")
	if is_instance_valid(tree.current_scene):
		_nodes.append(tree.current_scene)
	_done()


func test_restart_saves_once_and_starts_a_fresh_45_minutes() -> void:
	_fresh()
	var main := instantiate("res://scenes/main/main.tscn")
	var m := main.get_node("Expedition") as ExpeditionManager
	await physics_frames(5)
	m.collect(load("res://data/items/glowcap.tres"), 1)
	m.debug_set_remaining(100.0)
	m.restart()
	await process_frames(3)
	var next := tree.current_scene
	_nodes.append(next)
	var m2 := next.get_node("Expedition") as ExpeditionManager
	check(m2 != m and m2.timer.remaining >= 2700.0 - 1.0, "fresh countdown (%.0f s)" % m2.timer.remaining)
	check(PlayerProfile.load_profile().count(&"glowcap") == 1, "gathered saved exactly once")
	_done()


func test_arena_entry_after_the_timer_expired_is_ignored() -> void:
	_fresh()
	var main := instantiate("res://scenes/main/main.tscn")
	var m := main.get_node("Expedition") as ExpeditionManager
	await physics_frames(5)
	m.debug_set_remaining(0.05)
	await physics_frames(10)
	check(m.ended, "escaped")
	m.enter_boss_arena()
	check(not m.arena_entered and not (main.get_node("Level/Boss") as BossController).state != BossController.State.DORMANT, "no arena after the beast escaped")
	_done()


func test_dying_in_the_arena_keeps_the_boss_wounded_and_the_timer_gone() -> void:
	_fresh()
	var main := instantiate("res://scenes/main/main.tscn")
	var m := main.get_node("Expedition") as ExpeditionManager
	var p := main.get_node("Player") as PlayerController
	var boss := main.get_node("Level/Boss") as BossController
	var hud := main.get_node("UI/ExpeditionHud") as ExpeditionHud
	await physics_frames(5)
	(main.get_node("Level/Checkpoints/CheckpointGate") as Checkpoint).activate(p)
	p.global_position = Vector3(0, 0.5, -104)
	await physics_frames(10)
	var wound := DamageInfo.new()
	wound.amount = 200.0
	(boss.get_node("BodyHurtbox") as Hurtbox).receive(wound)
	var hp := boss.get_health().current
	var kill := DamageInfo.new()
	kill.amount = 9999.0
	p.combat.health.apply_damage(kill)
	await physics_frames(int(p.combat.config.respawn_delay * 60.0) + 60)
	check(p.combat.state != PlayerCombat.State.DEAD and p.combat.health.current > 0.0, "respawned")
	check(p.global_position.z > -95.0, "back at the gate shrine")
	check(boss.get_health().current <= hp + 0.01, "boss did not heal (%.0f / %.0f)" % [boss.get_health().current, hp])
	check(m.timer.state == ExpeditionTimer.State.STOPPED and not hud.is_timer_visible(), "timer stays stopped and hidden")
	p.global_position = Vector3(0, 0.5, -104)
	await physics_frames(10)
	check(m.arena_entered and m.timer.state == ExpeditionTimer.State.STOPPED, "walking back in changes nothing")
	_done()


func test_switching_away_from_the_game_pauses_the_countdown() -> void:
	_fresh()
	var main := instantiate("res://scenes/main/main.tscn")
	var m := main.get_node("Expedition") as ExpeditionManager
	await physics_frames(5)
	var menu: PauseMenu = main.find_children("*", "PauseMenu", true, false)[0]
	menu.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(menu.visible and m.is_paused() and m.timer.state == ExpeditionTimer.State.PAUSED, "pause menu opened, timer frozen")
	menu.close()
	check(not m.is_paused(), "resumes on demand")
	_done()


# ---------------------------------------------------------------- combat / camera / bosses

func test_lock_on_releases_when_the_target_dies() -> void:
	_fresh()
	make_floor()
	var p := make_player(Vector3(0, 0.05, 0))
	var t := instantiate("res://scenes/enemies/thornling.tscn") as Thornling
	t.global_position = Vector3(0, 0.1, -4)
	await physics_frames(10)
	p.combat.set_lock_target(t)
	check(p.combat.lock_target == t, "locked")
	var kill := DamageInfo.new()
	kill.amount = 9999.0
	(t.get_node("Hurtbox") as Hurtbox).receive(kill)
	await physics_frames(120)
	check(p.combat.lock_target == null, "lock released after the kill")
	_done()


func test_boss_defeated_mid_telegraph_hides_its_warning() -> void:
	_fresh()
	make_floor(Vector3(80, 1, 80))
	var boss := instantiate("res://scenes/bosses/kurogale.tscn") as BossController
	boss.global_position = Vector3.ZERO
	boss.arena_center = Vector3.ZERO
	var p := make_player(Vector3(0, 0.05, 6))
	await physics_frames(5)
	boss.awaken()
	await physics_frames(int(boss.definition.intro_time * 60.0) + 5)
	var a := boss.definition.attacks[0]
	boss.debug_force_attack(a.id)
	await physics_frames(10)
	var kill := DamageInfo.new()
	kill.amount = 99999.0
	(boss.get_node("BodyHurtbox") as Hurtbox).receive(kill)
	await physics_frames(5)
	check(boss.state == BossController.State.DEFEATED, "defeated")
	var warn := boss.get_node_or_null(a.warning_node) as Node3D
	check(warn == null or not warn.visible, "warning hidden")
	var hp := p.combat.health.current
	await physics_frames(int((a.telegraph_time + a.active_time) * 60.0) + 10)
	check_near(p.combat.health.current, hp, 0.01, "a dead boss's attack never lands")
	_done()


func test_top_down_camera_survives_a_respawn() -> void:
	_fresh()
	var main := instantiate("res://scenes/main/main.tscn")
	var p := main.get_node("Player") as PlayerController
	var rig := p.get_node("CameraRig") as CameraRig
	await physics_frames(5)
	BotHelpers.tap(self, "camera_toggle")
	await physics_frames(30)
	check(rig.mode == CameraRig.Mode.TOP_DOWN, "top-down")
	p.global_position = Vector3(0, -40, -60)  # Fall into the gorge.
	await physics_frames(30)
	check(rig.mode == CameraRig.Mode.TOP_DOWN, "still top-down after falling and respawning")
	_done()


# ---------------------------------------------------------------- crafting / respawns

func test_old_save_with_unknown_gear_and_items_does_not_break_the_forge() -> void:
	_fresh()
	_write('{"version": 2, "materials": {"glowcap": 2, "mystery_dust": 4}, "hunts_completed": {}, "gear_owned": ["removed_blade"], "equipped": {"Weapon": "removed_blade"}}')
	var board := instantiate("res://scenes/ui/hunt_board.tscn") as HuntBoard
	await process_frames(3)
	board.show_tab("forge")
	await process_frames(2)
	check(board.forge.visible, "forge opens")
	var main := instantiate("res://scenes/main/main.tscn")
	await physics_frames(10)
	check_near((main.get_node("Player") as PlayerController).combat.blade_damage_multiplier, 1.0, 0.001, "unknown gear ignored in the expedition")
	_done()


func test_respawning_out_of_mud_restores_normal_movement() -> void:
	_fresh()
	var main := instantiate("res://scenes/main/expedition_moonfen.tscn")
	var p := main.get_node("Player") as PlayerController
	await physics_frames(10)
	p.global_position = Vector3(-1.0, 0.3, -15)  # In the mud.
	await physics_frames(10)
	check(p.surface_blocks_jump(), "stuck in mud")
	p.respawn(Vector3(0, 0.3, 0))
	await physics_frames(10)
	check(not p.surface_blocks_jump() and is_equal_approx(p.surface_speed_multiplier(), 1.0), "free again after the respawn")
	_done()


func test_falling_while_climbing_resets_traversal() -> void:
	_fresh()
	var main := instantiate("res://scenes/main/main.tscn")
	var p := main.get_node("Player") as PlayerController
	await physics_frames(5)
	p.traversal.set("state", TraversalComponent.State.CLIMB)
	p.respawn(Vector3(0, 0.3, 0))
	await physics_frames(5)
	check(p.traversal.state == TraversalComponent.State.NONE, "not climbing thin air after a respawn")
	_done()
