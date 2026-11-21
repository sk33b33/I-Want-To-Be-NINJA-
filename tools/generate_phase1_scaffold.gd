extends SceneTree
## One-off generator used to create the Phase 0/1 project settings, data and scenes.
## Kept for reference only: re-running it OVERWRITES project.godot input map and scenes.
## Edit scenes in the Godot editor from now on.

func _initialize() -> void:
	_settings()
	_data()
	_boot_scene()
	_player_scene()
	_level_scene()
	_main_scene()
	print("GENERATED")
	quit(0)


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.device = -1
	e.physical_keycode = code
	return e


func _joy_btn(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = -1
	e.button_index = b
	return e


func _joy_axis(a: JoyAxis, v: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.device = -1
	e.axis = a
	e.axis_value = v
	return e


func _action(name: String, events: Array, deadzone: float = 0.2) -> void:
	ProjectSettings.set_setting("input/" + name, {"deadzone": deadzone, "events": events})


func _settings() -> void:
	var ps := ProjectSettings
	ps.set_setting("application/config/name", "I want to be NINJA")
	ps.set_setting("application/config/description", "3D jungle ninja hunting adventure (Phase 1 graybox).")
	ps.set_setting("application/run/main_scene", "res://scenes/main/main.tscn")
	ps.set_setting("display/window/size/viewport_width", 1280)
	ps.set_setting("display/window/size/viewport_height", 720)
	ps.set_setting("display/window/stretch/mode", "canvas_items")
	ps.set_setting("display/window/stretch/aspect", "expand")
	ps.set_setting("display/window/handheld/orientation", 6)  # sensor landscape
	ps.set_setting("rendering/renderer/rendering_method", "gl_compatibility")
	ps.set_setting("rendering/renderer/rendering_method.mobile", "gl_compatibility")
	ps.set_setting("rendering/textures/vram_compression/import_etc2_astc", true)
	ps.set_setting("physics/3d/physics_engine", "Jolt Physics")
	ps.set_setting("layer_names/3d_physics/layer_1", "world")
	ps.set_setting("layer_names/3d_physics/layer_2", "player")

	_action("move_forward", [_key(KEY_W), _key(KEY_UP), _joy_axis(JOY_AXIS_LEFT_Y, -1.0)])
	_action("move_back", [_key(KEY_S), _key(KEY_DOWN), _joy_axis(JOY_AXIS_LEFT_Y, 1.0)])
	_action("move_left", [_key(KEY_A), _key(KEY_LEFT), _joy_axis(JOY_AXIS_LEFT_X, -1.0)])
	_action("move_right", [_key(KEY_D), _key(KEY_RIGHT), _joy_axis(JOY_AXIS_LEFT_X, 1.0)])
	_action("look_left", [_joy_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_action("look_right", [_joy_axis(JOY_AXIS_RIGHT_X, 1.0)])
	_action("look_up", [_joy_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_action("look_down", [_joy_axis(JOY_AXIS_RIGHT_Y, 1.0)])
	_action("jump", [_key(KEY_SPACE), _joy_btn(JOY_BUTTON_A)], 0.5)
	_action("sprint", [_key(KEY_SHIFT), _joy_btn(JOY_BUTTON_LEFT_STICK)], 0.5)
	_action("camera_toggle", [_key(KEY_V), _joy_btn(JOY_BUTTON_DPAD_DOWN)], 0.5)
	_action("pause", [_key(KEY_ESCAPE), _joy_btn(JOY_BUTTON_START)], 0.5)
	var err := ps.save()
	assert(err == OK)


func _save_res(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("save failed %s %d" % [path, err])


func _data() -> void:
	var m: Resource = load("res://scripts/player/player_movement_config.gd").new()
	_save_res(m, "res://data/player/default_movement.tres")
	var c: Resource = load("res://scripts/camera/camera_rig_config.gd").new()
	_save_res(c, "res://data/camera/default_camera.tres")


func _own(node: Node, owner: Node) -> void:
	for child in node.get_children():
		if child.owner == null:
			child.owner = owner
		if child.scene_file_path == "":
			_own(child, owner)


func _pack(root: Node, path: String) -> void:
	_own(root, root)
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err != OK:
		push_error("pack failed " + path)
	_save_res(ps, path)
	root.free()


func _boot_scene() -> void:
	var root := Node.new()
	root.name = "BootTest"
	root.set_script(load("res://scripts/tests/boot_test.gd"))
	_pack(root, "res://scenes/tests/boot_test.tscn")


func _mat(color: Color, rough: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


func _player_scene() -> void:
	var p := CharacterBody3D.new()
	p.name = "Player"
	p.set_script(load("res://scripts/player/player_controller.gd"))
	p.set("config", load("res://data/player/default_movement.tres"))
	p.collision_layer = 2
	p.collision_mask = 1
	p.floor_snap_length = 0.3
	p.floor_max_angle = deg_to_rad(46.0)

	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	col.shape = cap
	col.position.y = 0.9
	p.add_child(col)

	var visual := Node3D.new()
	visual.name = "Visual"
	p.add_child(visual)
	var body := MeshInstance3D.new()
	body.name = "Body"
	var cm := CapsuleMesh.new()
	cm.radius = 0.4
	cm.height = 1.8
	cm.material = _mat(Color(0.08, 0.09, 0.16), 0.7)
	body.mesh = cm
	body.position.y = 0.9
	visual.add_child(body)
	var band := MeshInstance3D.new()
	band.name = "Headband"
	var bm := CylinderMesh.new()
	bm.top_radius = 0.42
	bm.bottom_radius = 0.42
	bm.height = 0.12
	bm.material = _mat(Color(0.8, 0.1, 0.1), 0.6)
	band.mesh = bm
	band.position.y = 1.5
	visual.add_child(band)
	var visor := MeshInstance3D.new()
	visor.name = "FacingVisor"
	var vm := BoxMesh.new()
	vm.size = Vector3(0.36, 0.1, 0.12)
	vm.material = _mat(Color(0.95, 0.85, 0.6), 0.5)
	visor.mesh = vm
	visor.position = Vector3(0, 1.62, -0.36)
	visual.add_child(visor)
	var tail := MeshInstance3D.new()
	tail.name = "HeadbandTail"
	var tm := BoxMesh.new()
	tm.size = Vector3(0.08, 0.06, 0.5)
	tm.material = bm.material
	tail.mesh = tm
	tail.position = Vector3(0.1, 1.45, 0.6)
	tail.rotation.x = deg_to_rad(-25)
	visual.add_child(tail)

	var rig := Node3D.new()
	rig.name = "CameraRig"
	rig.set_script(load("res://scripts/camera/camera_rig.gd"))
	rig.set("config", load("res://data/camera/default_camera.tres"))
	p.add_child(rig)
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	rig.add_child(pivot)
	var arm := SpringArm3D.new()
	arm.name = "SpringArm3D"
	arm.collision_mask = 1
	var sphere := SphereShape3D.new()
	sphere.radius = 0.25
	arm.shape = sphere
	arm.spring_length = 5.0
	pivot.add_child(arm)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.current = true
	cam.far = 400.0
	arm.add_child(cam)
	_pack(p, "res://scenes/player/player.tscn")


var _level_root: Node3D
var _mats: Dictionary = {}


func _box(name: String, size: Vector3, pos: Vector3, mat: String, rot_deg: Vector3 = Vector3.ZERO) -> CSGBox3D:
	var b := CSGBox3D.new()
	b.name = name
	b.size = size
	b.position = pos
	b.rotation_degrees = rot_deg
	b.use_collision = true
	b.collision_layer = 1
	b.collision_mask = 0
	b.material = _mats[mat]
	_level_root.get_node("Geometry").add_child(b)
	return b


func _tree(name: String, pos: Vector3, height: float, radius: float) -> void:
	var t := CSGCylinder3D.new()
	t.name = name
	t.radius = radius
	t.height = height
	t.sides = 10
	t.position = pos + Vector3.UP * height * 0.5
	t.use_collision = true
	t.collision_mask = 0
	t.material = _mats["bark"]
	_level_root.get_node("Geometry").add_child(t)
	var crown := CSGSphere3D.new()
	crown.name = name + "Crown"
	crown.radius = radius * 3.2
	crown.radial_segments = 10
	crown.rings = 6
	crown.position = pos + Vector3.UP * (height + radius * 1.5)
	crown.material = _mats["canopy"]
	_level_root.get_node("Geometry").add_child(crown)


func _level_scene() -> void:
	_mats = {
		"ground": _mat(Color(0.24, 0.42, 0.2)),
		"rock": _mat(Color(0.33, 0.35, 0.33)),
		"stone": _mat(Color(0.42, 0.4, 0.33)),
		"wood": _mat(Color(0.45, 0.3, 0.17)),
		"bark": _mat(Color(0.3, 0.22, 0.14)),
		"canopy": _mat(Color(0.12, 0.35, 0.15)),
		"water": _mat(Color(0.1, 0.55, 0.55), 0.1),
		"gate": _mat(Color(0.2, 0.6, 0.55), 0.4),
	}
	_level_root = Node3D.new()
	_level_root.name = "GrayboxRoute"

	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.42, 0.62)
	sky_mat.sky_horizon_color = Color(0.62, 0.72, 0.66)
	sky_mat.ground_horizon_color = Color(0.5, 0.6, 0.5)
	sky_mat.ground_bottom_color = Color(0.15, 0.22, 0.15)
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ambient_light_sky_contribution = 0.55
	env.ambient_light_energy = 0.7
	env.fog_enabled = true
	env.fog_light_color = Color(0.62, 0.74, 0.66)
	env.fog_density = 0.012
	env.fog_sky_affect = 0.4
	env_node.environment = env
	_level_root.add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	_level_root.add_child(sun)

	var geo := Node3D.new()
	geo.name = "Geometry"
	_level_root.add_child(geo)

	var spawn := Marker3D.new()
	spawn.name = "SpawnPoint"
	spawn.position = Vector3(0, 0.1, 0)
	_level_root.add_child(spawn)

	# Section A: start clearing + jungle floor (z 10 .. -50).
	_box("JungleFloor", Vector3(60, 1, 60), Vector3(0, -0.5, -20), "ground")
	# Steps of increasing height (step-up / jump practice).
	_box("StepLow", Vector3(3, 0.5, 3), Vector3(-6, 0.25, -8), "stone")
	_box("StepMid", Vector3(3, 1.0, 3), Vector3(-9, 0.5, -8), "stone")
	_box("StepHigh", Vector3(3, 1.6, 3), Vector3(-12, 0.8, -8), "stone")
	# Ramp up to a raised ledge (slope walking, fall-off test).
	_box("Ramp", Vector3(4, 0.5, 10), Vector3(10, 1.6, -12), "wood", Vector3(18, 0, 0))
	_box("RaisedLedge", Vector3(8, 3.2, 8), Vector3(10, 1.6, -21), "rock")
	# Tall wall next to the path: camera collision test.
	_box("CameraWall", Vector3(1, 6, 20), Vector3(4, 3, -32), "rock")
	# Low overhang / tunnel: camera collision from above.
	_box("TunnelRoof", Vector3(6, 1, 6), Vector3(-4, 3.2, -30), "rock")
	_box("TunnelLeft", Vector3(1, 2.7, 6), Vector3(-6.5, 1.35, -30), "rock")
	_box("TunnelRight", Vector3(1, 2.7, 6), Vector3(-1.5, 1.35, -30), "rock")
	# Stream (visual only, walkable) as a landmark.
	_box("Stream", Vector3(60, 0.05, 3), Vector3(0, 0.02, -40), "water")
	# Section B: gap jumps over a pit (z -50 .. -75). Falling triggers recovery.
	_box("GapPlatform1", Vector3(4, 1, 4), Vector3(0, -0.5, -54), "wood")
	_box("GapPlatform2", Vector3(4, 1, 4), Vector3(1.5, -0.2, -60.5), "wood")
	_box("GapPlatform3", Vector3(4, 1, 4), Vector3(0, 0.1, -67), "wood")
	# Section C: gate clearing (future boss gate; no logic in Phase 1).
	_box("GateClearing", Vector3(24, 1, 20), Vector3(0, -0.5, -81), "ground")
	_box("GatePillarL", Vector3(1.5, 7, 1.5), Vector3(-4, 3.5, -88), "gate")
	_box("GatePillarR", Vector3(1.5, 7, 1.5), Vector3(4, 3.5, -88), "gate")
	_box("GateLintel", Vector3(10, 1.2, 1.8), Vector3(0, 7.6, -88), "gate")

	var tree_spots := [
		Vector3(-15, 0, -2), Vector3(14, 0, 2), Vector3(-20, 0, -18), Vector3(20, 0, -30),
		Vector3(-14, 0, -42), Vector3(16, 0, -45), Vector3(-25, 0, -30), Vector3(24, 0, -10),
		Vector3(-9, 0, -80), Vector3(9, 0, -78),
	]
	for i in tree_spots.size():
		_tree("Tree%d" % i, tree_spots[i], 7.0 + float(i % 3) * 2.5, 0.6 + float(i % 2) * 0.25)

	_pack(_level_root, "res://scenes/biomes/verdant_canopy_graybox.tscn")


func _main_scene() -> void:
	var main := Node3D.new()
	main.name = "Main"
	main.set_script(load("res://scripts/main/main.gd"))
	var level: Node = (load("res://scenes/biomes/verdant_canopy_graybox.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	level.name = "Level"
	main.add_child(level)
	level.owner = main
	var player: Node = (load("res://scenes/player/player.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	player.name = "Player"
	main.add_child(player)
	player.owner = main

	var ui := CanvasLayer.new()
	ui.name = "UI"
	main.add_child(ui)
	ui.owner = main
	var hud := Label.new()
	hud.name = "DebugHud"
	hud.set_script(load("res://scripts/ui/debug_hud.gd"))
	hud.set("camera_rig_path", NodePath("../../Player/CameraRig"))
	hud.position = Vector2(16, 12)
	hud.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	hud.add_theme_constant_override("shadow_offset_x", 2)
	hud.add_theme_constant_override("shadow_offset_y", 2)
	ui.add_child(hud)
	hud.owner = main
	var touch := Control.new()
	touch.name = "TouchControls"
	touch.set_script(load("res://scripts/ui/touch_controls.gd"))
	touch.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(touch)
	touch.owner = main
	var ps := PackedScene.new()
	ps.pack(main)
	_save_res(ps, "res://scenes/main/main.tscn")
	main.free()
