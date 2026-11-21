extends TestCase
## Integration: the real main scene boots, the ninja lands on the Verdant Canopy graybox,
## and can run the first stretch of the route and jump the pit gaps.


func test_main_scene_player_lands_at_spawn() -> void:
	var main := instantiate("res://scenes/main/main.tscn")
	var player := main.get_node("Player") as PlayerController
	await physics_frames(60)
	check(player.is_on_floor(), "player standing on the jungle floor")
	check(player.global_position.distance_to(Vector3(0, 0, 0)) < 0.5, "player at the spawn point")


func test_route_spawn_to_gate_third_person() -> void:
	await _run_route(CameraRig.Mode.THIRD_PERSON)


func test_route_spawn_to_gate_top_down() -> void:
	await _run_route(CameraRig.Mode.TOP_DOWN)


func test_checkpoints_activate_along_route_and_respawn_uses_latest() -> void:
	var main := instantiate("res://scenes/main/main.tscn")
	var player := main.get_node("Player") as PlayerController
	await physics_frames(20)
	var gorge_cp := main.get_node("Level/Checkpoints/CheckpointGorge") as Checkpoint
	check(not gorge_cp.is_active, "gorge checkpoint starts dormant")
	gorge_cp.activate(player)
	check(gorge_cp.is_active, "checkpoint lights up")
	# Fall into the gorge.
	player.global_position = Vector3(0, -10, -60)
	await physics_frames(100)
	check(player.global_position.distance_to(gorge_cp.global_position) < 1.5,
			"respawned at the gorge checkpoint (at %s)" % player.global_position)


## Phase 2 gate: a bot completes the route from spawn to the boss gate. It holds forward,
## steers to the route centre line, and presses jump at fixed points; climbing the rampart and
## grabbing the far-bank ledge happen automatically through TraversalComponent.
func _run_route(mode: CameraRig.Mode) -> void:
	var main := instantiate("res://scenes/main/main.tscn")
	var player := main.get_node("Player") as PlayerController
	var rig := player.get_node("CameraRig") as CameraRig
	rig.set_mode(mode)
	var respawns := [0]
	var climbs := [0]
	var hangs := [0]
	player.respawned.connect(func(_at: Vector3) -> void: respawns[0] += 1)
	player.traversal.state_changed.connect(func(s: TraversalComponent.State) -> void:
		if s == TraversalComponent.State.CLIMB: climbs[0] += 1
		if s == TraversalComponent.State.HANG: hangs[0] += 1)
	await physics_frames(30)
	# Jump points along -Z: rampart face, then each gorge gap, then into the far-bank wall.
	var jump_at: Array[float] = [-43.0, -49.0, -55.0, -61.5, -68.0]
	var next_jump := 0
	press("move_forward")
	var reached := false
	for i in 2400:
		await tree.physics_frame
		var z := player.global_position.z
		var target_x := 1.5 if z < -57.0 and z > -64.0 else 0.0
		var steer := clampf((target_x - player.global_position.x) * 0.8, -1.0, 1.0)
		Input.action_press("move_right", maxf(steer, 0.0))
		Input.action_press("move_left", maxf(-steer, 0.0))
		if next_jump < jump_at.size() and z < jump_at[next_jump] and player.is_on_floor():
			press("jump")
			await physics_frames(12)
			release("jump")
			next_jump += 1
		if z < -90.0:
			reached = true
			break
	check(reached, "reached the boss gate (z=%.2f, mode %d)" % [player.global_position.z, mode])
	check(climbs[0] >= 1, "climbed the rampart (climbs=%d)" % climbs[0])
	check(hangs[0] >= 1, "grabbed the far-bank ledge (hangs=%d)" % hangs[0])
	check(respawns[0] == 0, "never fell (respawns=%d)" % respawns[0])
	var gate_cp := main.get_node("Level/Checkpoints/CheckpointGate") as Checkpoint
	check(gate_cp.is_active, "passed the gate checkpoint")
