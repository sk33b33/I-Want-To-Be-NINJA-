extends TestCase
## Phase 11: the dojo Settings tab (graphics preset, volumes, comfort options) and the benchmark
## that the owner runs on the real phone.

const SETTINGS := "user://test_settings_phase11_ui.cfg"


func _fresh() -> void:
	GameSettings.path = SETTINGS
	if FileAccess.file_exists(SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	GameSettings.load_settings()
	PlayerProfile.path = "user://test_profile_phase11_ui.json"


func _done() -> void:
	GameSettings.path = GameSettings.DEFAULT_PATH
	GameSettings.load_settings()
	PlayerProfile.path = PlayerProfile.DEFAULT_PATH
	BenchmarkRunner.last_results.clear()
	BenchmarkRunner.show_results_once = false


func test_dojo_settings_tab_changes_and_saves_options() -> void:
	_fresh()
	var board := instantiate("res://scenes/ui/hunt_board.tscn") as HuntBoard
	await process_frames(3)
	board.show_tab("settings")
	await process_frames(2)
	check(board.settings.is_visible_in_tree(), "settings tab shows")
	check(board.settings.quality_button.text.begins_with("Graphics: Auto"), "auto by default (%s)" % board.settings.quality_button.text)
	board.settings.quality_button.pressed.emit()
	check(GameSettings.get_quality() == "low" and board.settings.quality_button.text == "Graphics: Low", "cycles to Low")
	(board.settings.sliders["SFX"] as HSlider).value = 0.4
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	check(cfg.get_value("graphics", "quality") == "low", "graphics saved")
	check_near(float(cfg.get_value("audio", "sfx")), 0.4, 0.001, "sfx volume saved")
	check(board.settings.benchmark_button != null, "benchmark button in the dojo")
	_done()


func test_benchmark_visits_every_biome_and_writes_a_report() -> void:
	_fresh()
	var r := BenchmarkRunner.new()
	r.scenes = BenchmarkRunner.default_scenes()
	r.settle_frames = 3
	r.sample_frames = 5
	r.return_to_board = false
	tree.root.add_child(r)
	var done := [false]
	r.finished.connect(func(_res: Array) -> void: done[0] = true)
	r.run()
	for i in 3000:
		await tree.process_frame
		if done[0]:
			break
	check(done[0], "benchmark finished")
	var res := BenchmarkRunner.last_results
	check(res.size() == 4 * BenchmarkRunner.SPOTS.size(), "every biome x viewpoint measured (%d)" % res.size())
	for row: Dictionary in res:
		check(row["fps"] > 0.0 and row.has("draw_calls") and row.has("triangles"), "%s z%d has numbers" % [row["biome"], int(row["z"])])
	var report := FileAccess.get_file_as_string(BenchmarkRunner.REPORT_PATH)
	check(report.contains("Stormcrag") and report.contains("Slowest viewpoint"), "report written")
	if is_instance_valid(tree.current_scene):
		_nodes.append(tree.current_scene)  # The last biome visited; cleaned up with the test.
	_done()
