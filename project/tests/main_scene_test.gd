extends TestCase
## Integration: the real main scene boots, the ninja lands on the Verdant Canopy graybox,
## and can run the first stretch of the route and jump the pit gaps.


func test_main_scene_player_lands_at_spawn() -> void:
	var main := instantiate("res://scenes/main/main.tscn")
	var player := main.get_node("Player") as PlayerController
	await physics_frames(60)
	check(player.is_on_floor(), "player standing on the jungle floor")
	check(player.global_position.distance_to(Vector3(0, 0, 0)) < 0.5, "player at the spawn point")


func test_main_scene_route_runs_to_gate_clearing() -> void:
	# Run straight down the route, jumping at each pit gap; must reach the gate clearing.
	var main := instantiate("res://scenes/main/main.tscn")
	var player := main.get_node("Player") as PlayerController
	var respawns := [0]
	player.respawned.connect(func(_at: Vector3) -> void: respawns[0] += 1)
	await physics_frames(30)
	# Jump points along -Z just before each gap edge (see verdant_canopy_graybox.tscn).
	var jump_at: Array[float] = [-49.0, -55.0, -61.5, -68.0]
	var next_jump := 0
	press("move_forward")
	for i in 900:
		await tree.physics_frame
		var z := player.global_position.z
		# Steer toward the centre line of each platform.
		var target_x := 1.5 if z < -57.0 and z > -64.0 else 0.0
		var steer := clampf((target_x - player.global_position.x) * 0.8, -1.0, 1.0)
		Input.action_press("move_right", maxf(steer, 0.0))
		Input.action_press("move_left", maxf(-steer, 0.0))
		if next_jump < jump_at.size() and z < jump_at[next_jump] and player.is_on_floor():
			press("jump")
			await physics_frames(12)
			release("jump")
			next_jump += 1
		if z < -78.0:
			break
	check(player.global_position.z < -78.0, "reached the gate clearing (z=%.2f)" % player.global_position.z)
	check(respawns[0] == 0, "never fell into the pit (respawns=%d)" % respawns[0])
