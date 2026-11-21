extends TestCase
## Phase 1 camera: smooth third-person <-> top-down switching and wall collision.


func test_toggle_blends_to_top_down_and_back() -> void:
	# Arrange
	make_floor()
	var player := make_player(Vector3(0, 0.05, 0))
	var rig := player.get_node("CameraRig") as CameraRig
	var modes: Array[int] = []
	rig.mode_changed.connect(func(m: CameraRig.Mode) -> void: modes.append(m))
	await process_frames(5)
	# Act
	press("camera_toggle")
	await process_frames(3)
	# Assert: switching is smooth, not a cut.
	check(rig.mode == CameraRig.Mode.TOP_DOWN, "mode is top-down after toggle")
	check(rig.is_blending(), "camera is easing, not snapping")
	check(rig.get_distance() < rig.config.td_distance - 1.0, "distance has not jumped instantly")
	await process_frames(180)
	check_near(rad_to_deg(rig.get_pitch()), rig.config.td_pitch_deg, 1.0, "reached top-down pitch")
	check_near(rig.get_distance(), rig.config.td_distance, 0.2, "reached top-down distance")
	# Act: back to third-person.
	rig.toggle_mode()
	await process_frames(180)
	check(rig.mode == CameraRig.Mode.THIRD_PERSON, "back in third-person")
	check_near(rig.get_distance(), rig.config.tp_distance, 0.2, "reached third-person distance")
	check(modes == [CameraRig.Mode.TOP_DOWN, CameraRig.Mode.THIRD_PERSON], "mode_changed fired twice in order")


func test_movement_still_camera_relative_in_top_down() -> void:
	make_floor()
	var player := make_player(Vector3(0, 0.05, 0))
	var rig := player.get_node("CameraRig") as CameraRig
	rig.set_mode(CameraRig.Mode.TOP_DOWN)
	rig.set_yaw(PI)  # Camera faces +Z.
	await physics_frames(10)
	press("move_forward")
	await physics_frames(60)
	check(player.global_position.z > 3.0, "forward follows the top-down camera's facing (z=%.2f)" % player.global_position.z)


func test_wall_behind_player_pulls_camera_in() -> void:
	make_floor()
	# A wall 2 m behind the player (camera sits on +Z at yaw 0).
	make_floor(Vector3(10, 10, 1), Vector3(0, 5, 2.0))
	var player := make_player(Vector3(0, 0.05, 0))
	var rig := player.get_node("CameraRig") as CameraRig
	var arm := rig.get_node("Pivot/SpringArm3D") as SpringArm3D
	await physics_frames(10)
	await process_frames(10)
	var cam_z := rig.camera.global_position.z
	check(arm.get_hit_length() < rig.config.tp_distance - 1.0,
			"spring arm shortened (hit length %.2f)" % arm.get_hit_length())
	check(cam_z < 2.0, "camera stays in front of the wall (z=%.2f)" % cam_z)


func test_third_person_pitch_is_clamped() -> void:
	make_floor()
	var player := make_player(Vector3(0, 0.05, 0))
	var rig := player.get_node("CameraRig") as CameraRig
	rig.add_look_input(Vector2(0, 50.0))
	await process_frames(240)
	check(rad_to_deg(rig.get_pitch()) >= rig.config.tp_min_pitch_deg - 0.5, "pitch clamped at the minimum")
	rig.add_look_input(Vector2(0, -100.0))
	await process_frames(240)
	check(rad_to_deg(rig.get_pitch()) <= rig.config.tp_max_pitch_deg + 0.5, "pitch clamped at the maximum")
