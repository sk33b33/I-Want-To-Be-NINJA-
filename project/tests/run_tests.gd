extends SceneTree
## Headless test runner. Usage (from the repo root):
##   godot --headless --path project -s res://tests/run_tests.gd
## Exits with code 1 if any test fails.
## Focused run (no file edits): ... -s res://tests/run_tests.gd -- --only=qa,options
## Every tests/*_test.gd file must be listed in SUITES — a missing one fails the run.

const SUITES: Array[String] = [
	"res://tests/config_data_test.gd",
	"res://tests/player_movement_test.gd",
	"res://tests/camera_rig_test.gd",
	"res://tests/traversal_test.gd",
	"res://tests/ninja_animator_test.gd",
	"res://tests/world_generation_test.gd",
	"res://tests/expedition_timer_test.gd",
	"res://tests/expedition_flow_test.gd",
	"res://tests/combat_test.gd",
	"res://tests/boss_test.gd",
	"res://tests/biome_slice_test.gd",
	"res://tests/crafting_test.gd",
	"res://tests/emberwild_test.gd",
	"res://tests/moonfen_test.gd",
	"res://tests/stormcrag_test.gd",
	"res://tests/quality_test.gd",
	"res://tests/audio_test.gd",
	"res://tests/settings_benchmark_test.gd",
	"res://tests/qa_test.gd",
	"res://tests/options_test.gd",
	"res://tests/blades_test.gd",
	"res://tests/grip_test.gd",
	"res://tests/trail_test.gd",
	"res://tests/crash_report_test.gd",
	"res://tests/sky_test.gd",
	"res://tests/warmup_test.gd",
	"res://tests/brightness_unlock_test.gd",
	"res://tests/beasts_test.gd",
	"res://tests/art_test.gd",
	"res://tests/weapons_test.gd",
	"res://tests/secrets_test.gd",
	"res://tests/conditions_test.gd",
	"res://tests/routes_test.gd",
	"res://tests/accessibility_test.gd",
	"res://tests/main_scene_test.gd",
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var total := 0
	var failures := 0
	for f in DirAccess.get_files_at("res://tests"):
		if f.ends_with("_test.gd") and not SUITES.has("res://tests/" + f):
			print("FAIL  %s is not listed in run_tests.gd SUITES" % f)
			failures += 1
	var suites := SUITES
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			suites = []
			for name in arg.get_slice("=", 1).split(","):
				suites.append("res://tests/%s_test.gd" % name.strip_edges())
	for path in suites:
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():  # Missing or does not parse.
			print("FAIL  %s could not be loaded" % path)
			failures += 1
			continue
		for method in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			total += 1
			var suite: TestCase = script.new()
			suite.tree = self
			await suite.call(name)
			suite.cleanup()
			await process_frame
			# Let the physics engine drop the freed bodies before the next test builds its world.
			await physics_frame
			await physics_frame
			if suite.failed:
				failures += 1
				print("FAIL  %s::%s" % [path.get_file(), name])
				for msg in suite.messages:
					print("        - " + msg)
			else:
				print("PASS  %s::%s" % [path.get_file(), name])
	print("\n%d tests, %d failed" % [total, failures])
	quit(1 if failures > 0 else 0)
