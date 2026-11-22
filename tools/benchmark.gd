extends SceneTree
## Runs the Phase 11 benchmark (BenchmarkRunner: every biome x spawn / mid-route / arena) with
## the chosen preset and prints the report. Same code as the dojo's "Run benchmark" button.
## Render counts (draw calls, triangles) need a renderer:
##   xvfb-run godot --path project -s ../tools/benchmark.gd -- --quality=low
## Headless (no rendering) gives CPU-only frame times. Godot paces headless frames at ~6.9 ms,
## so a 6.9 ms average there means "CPU cost at or below 6.9 ms" (an upper bound):
##   godot --headless --path project -s ../tools/benchmark.gd -- --quality=low
## Optional: --settle=N --samples=N frames per viewpoint (fewer for slow software rendering).


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	PlayerProfile.path = "user://benchmark_profile.json"
	var r := BenchmarkRunner.new()
	r.scenes = BenchmarkRunner.default_scenes()
	r.return_to_board = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--settle="):
			r.settle_frames = int(arg.get_slice("=", 1))
		elif arg.begins_with("--samples="):
			r.sample_frames = int(arg.get_slice("=", 1))
	root.add_child(r)
	r.run.call_deferred()
	await r.finished
	print(BenchmarkRunner.format_results(BenchmarkRunner.last_results, QualityProfile.tier()))
	quit(0)
