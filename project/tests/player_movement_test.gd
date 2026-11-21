extends TestCase
## Phase 1 locomotion: landing, camera-relative running, sprint, jump, no double jump,
## fall recovery.


func test_spawn_in_air_lands_on_floor() -> void:
	# Arrange
	make_floor()
	var player := make_player(Vector3(0, 3, 0))
	# Act
	await physics_frames(90)
	# Assert
	check(player.is_on_floor(), "player is on the floor")
	check_near(player.global_position.y, 0.0, 0.1, "player rests on the floor surface")


func test_forward_input_moves_away_from_camera() -> void:
	make_floor()
	var player := make_player(Vector3(0, 0.05, 0))
	await physics_frames(10)
	press("move_forward")
	await physics_frames(60)
	check(player.global_position.z < -3.0, "moved toward -Z with camera yaw 0 (z=%.2f)" % player.global_position.z)
	check_near(player.global_position.x, 0.0, 0.2, "no sideways drift")


func test_forward_input_follows_camera_yaw() -> void:
	make_floor()
	var player := make_player(Vector3(0, 0.05, 0))
	var rig := player.get_node("CameraRig") as CameraRig
	rig.set_yaw(PI / 2.0)  # Camera turned 90° left: "forward" is world -X.
	await physics_frames(10)
	press("move_forward")
	await physics_frames(60)
	check(player.global_position.x < -3.0, "moved toward -X (x=%.2f)" % player.global_position.x)
	check_near(player.global_position.z, 0.0, 0.2, "no drift along Z")


func test_sprint_is_faster_than_run() -> void:
	make_floor()
	var player := make_player(Vector3(0, 0.05, 0))
	await physics_frames(10)
	press("move_forward")
	await physics_frames(40)
	var run_speed := player.get_horizontal_speed()
	press("sprint")
	await physics_frames(40)
	var sprint_speed := player.get_horizontal_speed()
	check_near(run_speed, player.config.run_speed, 0.3, "reaches run speed")
	check_near(sprint_speed, player.config.sprint_speed, 0.3, "reaches sprint speed")


func test_releasing_input_stops_on_ground() -> void:
	make_floor()
	var player := make_player(Vector3(0, 0.05, 0))
	await physics_frames(10)
	press("move_forward")
	await physics_frames(40)
	release("move_forward")
	await physics_frames(30)
	check(player.get_horizontal_speed() < 0.05, "stopped (speed=%.2f)" % player.get_horizontal_speed())


func test_jump_rises_then_lands() -> void:
	make_floor()
	var player := make_player(Vector3(0, 0.05, 0))
	var jumps := [0]
	player.jumped.connect(func() -> void: jumps[0] += 1)
	await physics_frames(20)
	press("jump")
	var peak := 0.0
	for i in 90:
		await tree.physics_frame
		peak = maxf(peak, player.global_position.y)
	check(jumps[0] == 1, "exactly one jump fired (got %d)" % jumps[0])
	check(peak > 1.2, "jump peak above 1.2 m (peak=%.2f)" % peak)
	check(player.is_on_floor(), "landed again")


func test_short_tap_jumps_lower_than_held_jump() -> void:
	make_floor()
	var player := make_player(Vector3(0, 0.05, 0))
	await physics_frames(20)
	press("jump")
	await physics_frames(2)
	release("jump")
	var peak := 0.0
	for i in 60:
		await tree.physics_frame
		peak = maxf(peak, player.global_position.y)
	var held_peak := pow(player.config.jump_velocity, 2) / (2.0 * player.config.gravity)
	check(peak > 0.2, "tap still jumps (peak=%.2f)" % peak)
	check(peak < held_peak * 0.8, "tap peak %.2f is lower than held peak %.2f" % [peak, held_peak])


func test_cannot_double_jump_in_air() -> void:
	make_floor()
	var player := make_player(Vector3(0, 0.05, 0))
	var jumps := [0]
	player.jumped.connect(func() -> void: jumps[0] += 1)
	await physics_frames(20)
	press("jump")
	await physics_frames(15)
	release("jump")
	await physics_frames(1)
	press("jump")  # Mid-air press, well past coyote time.
	await physics_frames(10)
	check(jumps[0] == 1, "mid-air press does not jump again (jumps=%d)" % jumps[0])


func test_falling_below_kill_height_respawns_at_safe_ground() -> void:
	make_floor()
	var player := make_player(Vector3(5, 0.05, 5))
	await physics_frames(40)  # Long enough to record a safe position.
	var safe := player.get_safe_position()
	var respawns := [0]
	player.respawned.connect(func(_at: Vector3) -> void: respawns[0] += 1)
	player.global_position = Vector3(30, player.config.kill_height - 5.0, 30)
	await physics_frames(2)
	check(respawns[0] == 1, "respawned once (got %d)" % respawns[0])
	check(player.global_position.distance_to(safe) < 1.0, "back near the safe spot")
	check(player.velocity.length() < 1.0, "momentum cleared")
	await physics_frames(40)
	check(player.is_on_floor(), "standing again after respawn")


func test_quick_second_press_inside_coyote_window_does_not_double_jump() -> void:
	make_floor()
	var player := make_player(Vector3(0, 0.05, 0))
	var jumps := [0]
	player.jumped.connect(func() -> void: jumps[0] += 1)
	await physics_frames(20)
	press("jump")
	await physics_frames(3)
	release("jump")
	await physics_frames(1)
	press("jump")  # ~0.07 s after take-off: still inside the coyote window length.
	await physics_frames(10)
	check(jumps[0] == 1, "jumping consumes coyote time (jumps=%d)" % jumps[0])
