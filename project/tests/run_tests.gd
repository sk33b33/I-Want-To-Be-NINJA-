extends SceneTree
## Headless test runner. Usage (from the repo root):
##   godot --headless --path project -s res://tests/run_tests.gd
## Exits with code 1 if any test fails.

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
	"res://tests/main_scene_test.gd",
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var total := 0
	var failures := 0
	for path in SUITES:
		var script := load(path) as GDScript
		if script == null:
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
			if suite.failed:
				failures += 1
				print("FAIL  %s::%s" % [path.get_file(), name])
				for msg in suite.messages:
					print("        - " + msg)
			else:
				print("PASS  %s::%s" % [path.get_file(), name])
	print("\n%d tests, %d failed" % [total, failures])
	quit(1 if failures > 0 else 0)
