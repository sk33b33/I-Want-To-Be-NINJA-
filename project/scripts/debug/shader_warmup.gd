class_name ShaderWarmup
extends Node
## Shows every distinct visual (mesh type + material/shader) in the expedition to a camera once,
## one per frame, while the game is paused behind a "Preparing the jungle…" screen. Shaders are
## compiled the first time they are drawn: on the owner's Galaxy S20 (Mali-G77) the Godot app died
## ~8 s into every expedition with nothing happening — likely a driver crash compiling a shader
## the first time something (bats, fireflies, eyes…) came into view. Warming up front removes
## mid-game compiles, and every step is written to the crash breadcrumbs BEFORE it is drawn, so a
## crash report names the exact material. Skipped headless (no real renderer there).

signal finished

## Unique visuals found (key -> node), and how many were drawn.
var targets: Array[GeometryInstance3D] = []
var warmed: int = 0
var _camera: Camera3D
var _old_camera: Camera3D
var _overlay: CanvasLayer
var _was_paused: bool = false


static func is_needed() -> bool:
	return DisplayServer.get_name() != "headless"


## Collect one GeometryInstance3D per distinct (class, mesh class, materials) under `root`.
static func collect(root: Node) -> Array[GeometryInstance3D]:
	var seen := {}
	var out: Array[GeometryInstance3D] = []
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		var key := describe(g)
		if not seen.has(key):
			seen[key] = true
			out.append(g)
	return out


## "<node class> <mesh class> <shader/material list>" — also the breadcrumb text.
static func describe(g: GeometryInstance3D) -> String:
	var mats: Array[Material] = []
	if g.material_override:
		mats.append(g.material_override)
	var mesh: Mesh = null
	if g is MeshInstance3D:
		mesh = (g as MeshInstance3D).mesh
	elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh:
		mesh = (g as MultiMeshInstance3D).multimesh.mesh
	elif g is CPUParticles3D:
		mesh = (g as CPUParticles3D).mesh
	elif g is CSGShape3D and g.get("material"):
		mats.append(g.get("material"))
	if mesh:
		for s in mesh.get_surface_count():
			if mesh.surface_get_material(s):
				mats.append(mesh.surface_get_material(s))
	var names := mats.map(func(m: Material) -> String:
		if m is ShaderMaterial and (m as ShaderMaterial).shader:
			return (m as ShaderMaterial).shader.resource_path.get_file()
		return m.get_class())
	return "%s %s [%s]" % [g.get_class(), mesh.get_class() if mesh else "-", ",".join(names)]


## Warm up everything under `scene_root` (the expedition). Awaitable; emits `finished`.
func run(scene_root: Node) -> void:
	var tree := get_tree()
	process_mode = Node.PROCESS_MODE_ALWAYS
	targets = ShaderWarmup.collect(scene_root)
	_was_paused = tree.paused
	tree.paused = true  # Nothing moves and the 45:00 countdown does not run meanwhile.
	_show_overlay()
	_old_camera = get_viewport().get_camera_3d()
	_camera = Camera3D.new()
	_camera.far = 400.0
	add_child(_camera)
	_camera.current = true
	CrashReport.note("warm-up start: %d visuals" % targets.size())
	for i in targets.size():
		var g := targets[i]
		if not is_instance_valid(g) or not g.is_inside_tree():
			continue
		CrashReport.note("warm %d/%d %s (%s)" % [i + 1, targets.size(), ShaderWarmup.describe(g), g.name])
		var hidden := _reveal(g)
		_frame(g)
		if ShaderWarmup.is_needed():
			await RenderingServer.frame_post_draw  # Really drawn (shader compiled).
		else:
			await tree.process_frame  # Headless: no renderer, nothing to compile.
		for h: Node3D in hidden:
			if is_instance_valid(h):
				h.visible = false
		warmed += 1
	CrashReport.note("warm-up done")
	if is_instance_valid(_old_camera):
		_old_camera.current = true
	_camera.queue_free()
	if _overlay:
		_overlay.queue_free()
	tree.paused = _was_paused
	finished.emit()


## Make the node and any hidden ancestors visible; returns what to hide again afterwards.
func _reveal(g: GeometryInstance3D) -> Array[Node3D]:
	var hidden: Array[Node3D] = []
	var n: Node = g
	while n and n is Node3D:
		if not (n as Node3D).visible:
			(n as Node3D).visible = true
			hidden.append(n)
		n = n.get_parent()
	return hidden


## Point the warm-up camera at the node from a little in front and above.
func _frame(g: GeometryInstance3D) -> void:
	var box := g.global_transform * g.get_aabb()
	var centre := box.get_center()
	var dist := clampf(box.size.length() * 0.8 + 1.5, 2.0, 40.0)
	_camera.global_position = centre + Vector3(0.0, dist * 0.35, dist)
	_camera.look_at(centre, Vector3.UP)


func _show_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 90
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.035, 0.94)  # Not fully opaque: the 3D pass must still draw.
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(bg)
	var l := UiStyle.label("Preparing the jungle…", 30, UiStyle.MUTED)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overlay.add_child(l)
	add_child(_overlay)
