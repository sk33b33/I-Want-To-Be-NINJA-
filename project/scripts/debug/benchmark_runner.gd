class_name BenchmarkRunner
extends Node
## Phase 11 performance benchmark. Visits fixed viewpoints (spawn, mid-route, arena) in every
## biome with the current graphics preset and records frame time, draw calls and triangles.
## Started from the dojo's Settings tab (so it runs on the real phone) or by tools/benchmark.gd.
## Results are kept in `last_results`, written to user://benchmark.txt, then the dojo reopens.

signal finished(results: Array)

const SPOTS: Array[Vector3] = [Vector3(0, 0.3, 0), Vector3(0, 0.3, -46), Vector3(0, 0.3, -106)]
const REPORT_PATH := "user://benchmark.txt"
## Targets (docs/PERFORMANCE.md).
const TARGET_FPS := {&"low": 30.0, &"medium": 45.0, &"high": 60.0}

static var last_results: Array[Dictionary] = []
## The dojo opens on its Settings tab once after a run, to show the results.
static var show_results_once: bool = false

## Expedition scenes to visit, in order (display name -> scene path).
var scenes: Array = []
var settle_frames: int = 45
var sample_frames: int = 120
var return_to_board: bool = true


## Default list: every biome on the hunt board.
static func default_scenes() -> Array:
	return [["Verdant Canopy", "res://scenes/main/main.tscn"],
			["Emberwild", "res://scenes/main/expedition_emberwild.tscn"],
			["Moonfen", "res://scenes/main/expedition_moonfen.tscn"],
			["Stormcrag", "res://scenes/main/expedition_stormcrag.tscn"]]


## Start a benchmark run detached from the current scene (it frees the dojo while it runs).
static func start(tree: SceneTree, return_to_dojo: bool = true) -> BenchmarkRunner:
	var r := BenchmarkRunner.new()
	r.scenes = default_scenes()
	r.return_to_board = return_to_dojo
	r.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(r)
	r.run.call_deferred()
	return r


func run() -> void:
	var tree := get_tree()
	var results: Array[Dictionary] = []
	var tier := QualityProfile.tier()
	for entry in scenes:
		if is_instance_valid(tree.current_scene):
			tree.current_scene.free()
		var scene := (load(entry[1]) as PackedScene).instantiate()
		tree.root.add_child(scene)
		tree.current_scene = scene
		var player := scene.get_node_or_null("Player") as PlayerController
		var rig := player.get_node_or_null("CameraRig") as CameraRig if player else null
		if player:
			player.input_enabled = false
			if player.combat and player.combat.health:
				player.combat.health.invulnerable = true  # Bosses may attack at the arena viewpoint.
		for spot in SPOTS:
			if player:
				player.global_position = spot
				player.set_safe_position(spot)
			if rig:
				rig.set_yaw(0.0)
				rig.snap_to_target()
			for i in settle_frames:
				await tree.process_frame
			results.append(await _sample(entry[0], spot.z, tier))
	last_results = results
	show_results_once = true
	_write_report(results, tier)
	finished.emit(results)
	if return_to_board:
		SceneFlow.go_to_hunt_board(tree)
	queue_free()


func _sample(biome: String, z: float, tier: StringName) -> Dictionary:
	var tree := get_tree()
	var total_us := 0
	var worst_us := 0
	var draws := 0.0
	var tris := 0.0
	var last := Time.get_ticks_usec()
	for i in sample_frames:
		await tree.process_frame
		var now := Time.get_ticks_usec()
		var dt := now - last
		last = now
		total_us += dt
		worst_us = maxi(worst_us, dt)
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		tris += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var avg_ms := total_us / 1000.0 / sample_frames
	return {"biome": biome, "z": z, "tier": String(tier), "avg_ms": avg_ms,
			"fps": 1000.0 / maxf(avg_ms, 0.001), "worst_ms": worst_us / 1000.0,
			"draw_calls": int(draws / sample_frames), "triangles": int(tris / sample_frames)}


## One line per viewpoint, plus a verdict against the target for this preset.
static func format_results(results: Array, tier: StringName) -> String:
	var target: float = TARGET_FPS.get(tier, 30.0)
	var lines: PackedStringArray = ["Benchmark — preset %s, target %d fps, %s" % [String(tier).to_upper(), int(target), OS.get_model_name()]]
	var worst_fps := INF
	for r: Dictionary in results:
		worst_fps = minf(worst_fps, r["fps"])
		lines.append("%-15s %5s  %5.1f fps  (%.1f ms avg, %.1f ms worst)  %4d draws  %4dk tris" % [
				r["biome"], "z%d" % int(r["z"]), r["fps"], r["avg_ms"], r["worst_ms"], r["draw_calls"], int(r["triangles"]) / 1000])
	if not results.is_empty():
		lines.append("Slowest viewpoint: %.1f fps — %s" % [worst_fps, "TARGET MET" if worst_fps >= target else "below target"])
	return "\n".join(lines)


static func _write_report(results: Array, tier: StringName) -> void:
	var f := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if f:
		f.store_string(format_results(results, tier) + "\n")
		f.close()
