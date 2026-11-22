extends TestCase
## Phase 3 gate: timer behaviour at start, pause, resume, arena entry and timeout, in the real
## expedition scene; plus the hunt board starting an expedition with the chosen hunt.


func _expedition() -> Node:
	return instantiate("res://scenes/main/main.tscn")


func _manager(main: Node) -> ExpeditionManager:
	return main.get_node("Expedition") as ExpeditionManager


func _hud(main: Node) -> ExpeditionHud:
	return main.get_node("UI/ExpeditionHud") as ExpeditionHud


func test_start_runs_45_minute_countdown_with_hud() -> void:
	var main := _expedition()
	var m := _manager(main)
	await process_frames(5)
	check(m.timer.state == ExpeditionTimer.State.RUNNING, "countdown running at expedition start")
	check_near(m.timer.duration, 2700.0, 0.001, "45 minutes")
	check(m.hunt != null and m.hunt.id == &"kurogale", "default hunt is Kurogale")
	check(_hud(main).is_timer_visible(), "HUD timer visible")
	check(_hud(main).shown_time() == "45:00", "HUD shows 45:00 (got %s)" % _hud(main).shown_time())
	await process_frames(60)
	check(m.timer.remaining < 2700.0, "time is passing (%.2f)" % m.timer.remaining)


func test_pause_freezes_timer_and_resume_continues() -> void:
	var main := _expedition()
	var m := _manager(main)
	var menu := main.get_node("UI/PauseMenu") as PauseMenu
	await process_frames(10)
	press("pause")
	await process_frames(3)
	check(tree.paused, "game tree paused")
	check(menu.visible, "pause menu shown")
	check(m.timer.state == ExpeditionTimer.State.PAUSED, "timer paused")
	var frozen := m.timer.remaining
	await process_frames(90)
	check_near(m.timer.remaining, frozen, 0.0001, "no time lost while paused")
	release("pause")
	press("pause")
	await process_frames(3)
	check(not tree.paused, "game resumed")
	check(not menu.visible, "pause menu hidden")
	check(m.timer.state == ExpeditionTimer.State.RUNNING, "timer running again")
	await process_frames(30)
	check(m.timer.remaining < frozen, "countdown continues after resume")


func test_entering_arena_stops_and_hides_timer_for_good() -> void:
	var main := _expedition()
	var m := _manager(main)
	var player := main.get_node("Player") as PlayerController
	var arena_events := [0]
	m.boss_arena_entered.connect(func(_r: float) -> void: arena_events[0] += 1)
	await physics_frames(10)
	player.global_position = Vector3(0, 0.5, -105)  # Inside the arena, past the trigger.
	player.set_safe_position(player.global_position)
	await physics_frames(10)
	check(m.arena_entered, "arena entry detected")
	check(arena_events[0] == 1, "BossArenaEntered fired once (got %d)" % arena_events[0])
	check(m.timer.state == ExpeditionTimer.State.STOPPED, "timer stopped")
	check(not _hud(main).is_timer_visible(), "timer hidden")
	var at_entry := m.timer.remaining
	# Leaving and re-entering, pausing, and waiting must not restart or advance it.
	player.global_position = Vector3(0, 0.5, -90)
	await physics_frames(10)
	player.global_position = Vector3(0, 0.5, -105)
	await physics_frames(60)
	m.set_paused(true)
	m.set_paused(false)
	check(arena_events[0] == 1, "no second arena event")
	check_near(m.timer.remaining, at_entry, 0.0001, "timer frozen for the rest of the run")
	check(not _hud(main).is_timer_visible(), "timer stays hidden")


func test_timeout_ends_expedition_with_results() -> void:
	var main := _expedition()
	var m := _manager(main)
	var player := main.get_node("Player") as PlayerController
	var results := main.get_node("UI/ExpeditionResults") as ExpeditionResults
	var ended := [{}]
	m.expedition_ended.connect(func(r: Dictionary) -> void: ended[0] = r)
	await process_frames(5)
	m.debug_set_remaining(0.3)
	await process_frames(60)
	check(m.timer.state == ExpeditionTimer.State.EXPIRED, "timer expired")
	check(m.ended, "expedition ended")
	check(ended[0].get("outcome") == "escaped", "outcome: beast escaped")
	check(results.visible, "results screen shown")
	check(not player.input_enabled, "player input disabled")
	check(not _hud(main).is_timer_visible(), "timer hidden after timeout")
	press("pause")
	await process_frames(3)
	check(not tree.paused, "cannot pause after the expedition ended")


func test_timer_cannot_expire_after_arena_entry() -> void:
	var main := _expedition()
	var m := _manager(main)
	await process_frames(5)
	m.debug_set_remaining(0.3)
	m.enter_boss_arena()
	await process_frames(60)
	check(m.timer.state == ExpeditionTimer.State.STOPPED, "still stopped, not expired")
	check(not m.ended, "expedition continues into the boss fight")


func test_timeout_can_return_to_checkpoint_instead() -> void:
	var main := _expedition()
	var m := _manager(main)
	var player := main.get_node("Player") as PlayerController
	await physics_frames(5)
	var cfg := m.config.duplicate() as ExpeditionConfig
	cfg.timeout_behavior = ExpeditionConfig.TimeoutBehavior.RETURN_TO_CHECKPOINT
	m.config = cfg
	var respawns := [0]
	player.respawned.connect(func(_a: Vector3) -> void: respawns[0] += 1)
	m.debug_set_remaining(0.2)
	await physics_frames(30)
	check(respawns[0] == 1, "sent back to the checkpoint")
	check(m.timer.state == ExpeditionTimer.State.RUNNING, "timer restarted")
	check(m.timer.remaining > m.timer.duration - 2.0, "full time again")


func test_hunt_board_lists_biomes_and_starts_expedition() -> void:
	var board := instantiate("res://scenes/ui/hunt_board.tscn") as HuntBoard
	await process_frames(3)
	check(board.biomes.size() == 4, "four jungles listed")
	# With no hunts completed only the Verdant Canopy is open (Emberwild needs Kurogale first).
	var fresh := PlayerProfile.new()
	var unlocked := board.biomes.filter(func(b: BiomeDefinition) -> bool: return HuntBoard.is_open(b, fresh))
	check(unlocked.size() == 1 and unlocked[0].id == &"verdant_canopy", "only Verdant Canopy open for a new hunter")
	var start := board.get_start_button(&"kurogale")
	check(start != null and not start.disabled, "Kurogale hunt can be started")
	var scene := board.begin(unlocked[0], unlocked[0].hunts[0])
	await process_frames(5)
	_track(scene)
	check(scene.is_inside_tree(), "expedition scene loaded")
	var m := scene.get_node("Expedition") as ExpeditionManager
	check(m.hunt == unlocked[0].hunts[0], "chosen hunt injected")
	check(m.timer.state == ExpeditionTimer.State.RUNNING, "expedition countdown started")


func _track(node: Node) -> void:
	_nodes.append(node)
