extends TestCase
## Phase 9 readability / accessibility pass: comfort options persist, screen shake can be turned
## off, bold warnings brighten every telegraph material, and the pause menu exposes both.

const TEST_PATH := "user://test_settings_phase9.cfg"


func _fresh() -> void:
	GameSettings.path = TEST_PATH
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	GameSettings.load_settings()


func _done() -> void:
	GameSettings.screen_shake = true
	GameSettings.bold_warnings = false
	GameSettings.apply()
	GameSettings.path = GameSettings.DEFAULT_PATH


## Godot drops a shader parameter set back to its default, so "unset" means the default 1.0.
func _boost(m: ShaderMaterial) -> float:
	var v: Variant = m.get_shader_parameter("boost")
	return 1.0 if v == null else float(v)


func test_defaults_then_settings_survive_a_reload() -> void:
	_fresh()
	check(GameSettings.screen_shake and not GameSettings.bold_warnings, "defaults: shake on, normal warnings")
	GameSettings.set_screen_shake(false)
	GameSettings.set_bold_warnings(true)
	GameSettings.screen_shake = true  # Forget in memory...
	GameSettings.bold_warnings = false
	GameSettings.load_settings()  # ...and read back from disk.
	check(not GameSettings.screen_shake and GameSettings.bold_warnings, "both options persisted")
	_done()


func test_screen_shake_off_keeps_the_camera_still() -> void:
	_fresh()
	make_floor()
	var p := make_player(Vector3(0, 0.05, 0))
	await physics_frames(2)
	var rig := p.get_node("CameraRig") as CameraRig
	GameSettings.set_screen_shake(false)
	rig.add_shake(1.0)
	check_near(rig.get("_shake"), 0.0, 0.0001, "no shake when turned off")
	GameSettings.set_screen_shake(true)
	rig.add_shake(0.5)
	check(float(rig.get("_shake")) > 0.4, "shakes when on")
	_done()


func test_bold_warnings_brighten_every_warning_material() -> void:
	_fresh()
	for path in GameSettings.WARNING_MATERIALS:
		check(ResourceLoader.exists(path), "%s exists" % path.get_file())
	var held: Array[ShaderMaterial] = []  # Keep them loaded, as a running scene does.
	for path in GameSettings.WARNING_MATERIALS:
		held.append(load(path) as ShaderMaterial)
	GameSettings.set_bold_warnings(true)
	for m in held:
		var path := m.resource_path
		check_near(_boost(m), GameSettings.BOLD_BOOST, 0.001, "%s boosted" % path.get_file())
	GameSettings.set_bold_warnings(false)
	check_near(_boost(held[0]), 1.0, 0.001, "back to normal")
	_done()


## Regression: the option was lost when a warning material dropped out of Godot's resource cache
## between scenes; starting an expedition must re-apply it to the materials that scene uses.
func test_bold_warnings_reach_a_freshly_loaded_expedition() -> void:
	_fresh()
	GameSettings.set_bold_warnings(true)
	PlayerProfile.path = "user://test_profile_phase9_access.json"
	var main := instantiate("res://scenes/main/expedition_moonfen.tscn")
	await physics_frames(3)
	var warn := (main.get_node("Level/Boss/Front/FloodWarning") as MeshInstance3D).mesh.surface_get_material(0) as ShaderMaterial
	if warn == null:
		warn = ((main.get_node("Level/Boss/Front/FloodWarning") as MeshInstance3D).mesh as QuadMesh).material as ShaderMaterial
	check_near(_boost(warn), GameSettings.BOLD_BOOST, 0.001, "the boss's flood warning is bold")
	PlayerProfile.path = PlayerProfile.DEFAULT_PATH
	_done()


func test_pause_menu_toggles_and_saves_the_options() -> void:
	_fresh()
	PlayerProfile.path = "user://test_profile_phase9_access.json"
	var main := instantiate("res://scenes/main/main.tscn")
	await physics_frames(5)
	var menu: PauseMenu = null
	for n in main.find_children("*", "PauseMenu", true, false):
		menu = n as PauseMenu
	check(menu != null, "pause menu present")
	check(menu.shake_button.text.ends_with("On"), "shows shake on")
	menu.shake_button.pressed.emit()
	menu.warnings_button.pressed.emit()
	check(menu.shake_button.text.ends_with("Off") and menu.warnings_button.text.ends_with("On"), "labels follow the options")
	var cfg := ConfigFile.new()
	check(cfg.load(TEST_PATH) == OK, "saved")
	check(cfg.get_value("comfort", "screen_shake") == false and cfg.get_value("readability", "bold_warnings") == true, "saved values")
	PlayerProfile.path = PlayerProfile.DEFAULT_PATH
	_done()
