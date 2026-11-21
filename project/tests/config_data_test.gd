extends TestCase
## Data files load as the right types and hold sane values.


func test_movement_config_loads_with_sane_values() -> void:
	# Arrange / Act
	var cfg := load("res://data/player/default_movement.tres") as PlayerMovementConfig
	# Assert
	check(cfg != null, "default_movement.tres is a PlayerMovementConfig")
	if cfg == null:
		return
	check(cfg.sprint_speed > cfg.run_speed, "sprint is faster than run")
	check(cfg.jump_velocity > 0.0 and cfg.gravity > 0.0, "jump and gravity are positive")
	check(cfg.kill_height < 0.0, "kill height is below the ground")


func test_camera_config_loads_with_sane_values() -> void:
	var cfg := load("res://data/camera/default_camera.tres") as CameraRigConfig
	check(cfg != null, "default_camera.tres is a CameraRigConfig")
	if cfg == null:
		return
	check(cfg.td_distance > cfg.tp_distance, "top-down sits farther out than third-person")
	check(cfg.td_pitch_deg < cfg.tp_default_pitch_deg, "top-down looks down more steeply")
	check(cfg.tp_min_pitch_deg < cfg.tp_max_pitch_deg, "pitch limits are ordered")


func test_input_actions_exist_for_all_controls() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint",
			"camera_toggle", "pause", "look_left", "look_right", "look_up", "look_down"]:
		check(InputMap.has_action(action), "input action '%s' is defined" % action)
