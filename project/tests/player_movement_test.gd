extends TestCase
## Phase 1 locomotion: landing, camera-relative running, sprint, jump, the air jump (double jump),
## stamina,
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


## Owner request: a double jump whose second jump is a front flip.
func test_second_press_in_the_air_is_a_front_flip_air_jump_once_per_jump() -> void:
	make_floor()
	var player := make_player(Vector3(0, 0.05, 0))
	var air_jumps := [0]
	var jumps := [0]
	player.double_jumped.connect(func() -> void: air_jumps[0] += 1)
	player.jumped.connect(func() -> void: jumps[0] += 1)
	await physics_frames(20)
	press("jump")
	await physics_frames(14)
	release("jump")
	var before := player.velocity.y
	await physics_frames(1)
	press("jump")
	await physics_frames(2)
	check(air_jumps[0] == 1 and jumps[0] == 1, "one ground jump and one air jump (%d, %d)" % [jumps[0], air_jumps[0]])
	check(player.velocity.y > before + 2.0, "the air jump pushes up (%.1f -> %.1f)" % [before, player.velocity.y])
	var animator := player.find_children("*", "NinjaAnimator", true, false)
	if not animator.is_empty():
		check((animator[0] as NinjaAnimator).current_clip() == &"Front_Flip", "the air jump plays the front flip (%s)" % (animator[0] as NinjaAnimator).current_clip())
	release("jump")
	await physics_frames(3)
	press("jump")  # A third press: no more air jumps until landing.
	await physics_frames(3)
	check(air_jumps[0] == 1, "only one air jump per jump (%d)" % air_jumps[0])
	release("jump")
	await physics_frames(120)
	check(player.is_on_floor(), "landed")
	press("jump")
	await physics_frames(14)
	release("jump")
	await physics_frames(1)
	press("jump")
	await physics_frames(2)
	check(air_jumps[0] == 2, "landing gives the air jump back (%d)" % air_jumps[0])
	release("jump")
	await physics_frames(2)


func test_falling_off_a_ledge_still_allows_the_air_jump() -> void:
	make_floor()
	var player := make_player(Vector3(0, 6.0, 0))  # Dropped in the air: never jumped.
	var air_jumps := [0]
	player.double_jumped.connect(func() -> void: air_jumps[0] += 1)
	await physics_frames(5)
	press("jump")
	await physics_frames(3)
	check(air_jumps[0] == 1, "a fall can be rescued with the air jump (%d)" % air_jumps[0])


## Owner request: sprint drains a stamina bar; empty = no sprint until some comes back.
func test_sprint_drains_stamina_then_falls_back_to_running_and_recovers() -> void:
	make_floor()
	var player := make_player(Vector3(0, 0.05, 0))
	await physics_frames(10)
	check(is_equal_approx(player.stamina, player.config.stamina_max), "starts with full stamina")
	press("move_forward")
	await physics_frames(30)
	check(is_equal_approx(player.stamina, player.config.stamina_max), "running costs nothing")
	press("sprint")
	await physics_frames(60)
	check(player.stamina < player.config.stamina_max - 5.0 and player.is_sprinting(), "sprinting drains stamina (%.0f)" % player.stamina)
	player.stamina = 0.5
	await physics_frames(20)
	check(player.is_exhausted() and not player.is_sprinting(), "an empty bar stops the sprint")
	check_near(player.get_horizontal_speed(), player.config.run_speed, 0.4, "exhausted: back to running speed")
	release("sprint")
	release("move_forward")
	await physics_frames(int((player.config.stamina_regen_delay + player.config.stamina_recover_threshold / player.config.stamina_regen + 0.5) * 60.0))
	check(player.stamina >= player.config.stamina_recover_threshold and not player.is_exhausted(), "rest refills it (%.0f)" % player.stamina)


## Owner request: green life bar, red only while health has just been lost; a stamina bar; the
## touch button says SPRINT.
func test_hud_green_life_red_only_after_damage_stamina_bar_and_sprint_label() -> void:
	PlayerProfile.path = "user://test_profile_movement.json"
	var main := instantiate("res://scenes/main/main.tscn")
	await physics_frames(5)
	var hud: PlayerHud = main.find_children("*", "PlayerHud", true, false)[0]
	var player := main.get_node("Player") as PlayerController
	await process_frames(2)
	var c := hud.health_colour()
	check(c.g > c.r * 2.0 and c.g > c.b * 2.0, "the life bar is green (%s)" % c)
	check(not hud.red_showing(), "no red on a full life bar")
	var info := DamageInfo.new()
	info.amount = 20.0
	player.combat.health.apply_damage(info)
	await process_frames(2)
	check(hud.red_showing(), "red shows the health just lost")
	await tree.create_timer(2.0).timeout
	check(not hud.red_showing(), "the red drains away after a moment")
	player.stamina = 30.0
	player.stamina_changed.emit(30.0, player.config.stamina_max)
	check(is_equal_approx(hud.shown_stamina(), 30.0), "the stamina bar follows stamina")
	var tc := TouchControls.new()
	var labels: Array = []
	for b: Dictionary in tc.get("_buttons"):
		labels.append(b["label"])
	tc.free()
	check(labels.has("SPRINT") and not labels.has("DASH"), "the touch button says SPRINT (%s)" % [labels])
	main.free()
	_nodes.erase(main)
	PlayerProfile.path = PlayerProfile.DEFAULT_PATH
