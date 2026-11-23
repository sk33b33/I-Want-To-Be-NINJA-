extends TestCase
## Owner requests: "still a bit too dark" (brightness setting, brighter default) and "make the
## other jungles available so I can test them" (Unlock all jungles switch in the dojo).

const SETTINGS := "user://test_settings_brightness.cfg"


func _fresh() -> void:
	GameSettings.path = SETTINGS
	if FileAccess.file_exists(SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	GameSettings.load_settings()
	PlayerProfile.path = "user://test_profile_brightness.json"
	if FileAccess.file_exists(PlayerProfile.path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PlayerProfile.path))


func _done() -> void:
	GameSettings.unlock_all = false
	GameSettings.brightness = 1.5
	GameSettings.path = GameSettings.DEFAULT_PATH
	GameSettings.load_settings()
	PlayerProfile.path = PlayerProfile.DEFAULT_PATH


func test_default_is_brighter_and_the_slider_never_compounds() -> void:
	_fresh()
	check(GameSettings.brightness > 1.1, "default brighter than before (%.2f)" % GameSettings.brightness)
	var level := (load("res://scenes/biomes/verdant_canopy.tscn") as PackedScene).instantiate()
	var base_exposure := (level.get_node("WorldEnvironment") as WorldEnvironment).environment.tonemap_exposure
	level.free()  # Only read; never added to the tree.
	var main := instantiate("res://scenes/main/main.tscn")
	await process_frames(3)
	var env := (main.get_node("Level/WorldEnvironment") as WorldEnvironment).environment
	check_near(env.tonemap_exposure, base_exposure * GameSettings.brightness, 0.01, "exposure scaled by the setting")
	GameSettings.set_brightness(1.8)
	QualityProfile.apply_brightness(main)
	QualityProfile.apply_brightness(main)  # Twice: must not compound.
	check_near(env.tonemap_exposure, base_exposure * 1.8, 0.01, "slider applies live, never compounds")
	_done()


func test_unlock_all_opens_every_jungle_on_the_board() -> void:
	_fresh()
	var board := instantiate("res://scenes/ui/hunt_board.tscn") as HuntBoard
	await process_frames(3)
	var profile := PlayerProfile.load_profile()
	var locked := board.biomes.filter(func(b: BiomeDefinition) -> bool: return not HuntBoard.is_open(b, profile))
	check(locked.size() == 3, "fresh profile: three jungles locked (%d)" % locked.size())
	check(board.settings.unlock_button != null, "switch in the dojo settings")
	GameSettings.set_unlock_all(true)
	for b in board.biomes:
		check(HuntBoard.is_open(b, profile), "%s open for testing" % b.display_name)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	check(cfg.get_value("game", "unlock_all") == true, "saved")
	var board2 := instantiate("res://scenes/ui/hunt_board.tscn") as HuntBoard
	await process_frames(3)
	for h in [&"kurogale", &"ashen_oni_tortoise", &"nami", &"raijins_echo"]:
		check(board2.get_start_button(h) != null, "%s can be started" % h)
	_done()
