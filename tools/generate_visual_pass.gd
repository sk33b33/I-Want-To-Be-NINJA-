extends SceneTree
## One-off generator for the "gloomy Verdant Canopy" visual pass: materials, data resources,
## the player scene (Mixamo ninja model) and the level scene. Re-running OVERWRITES
## data/materials/*, scenes/player/player.tscn, scenes/biomes/verdant_canopy.tscn and scenes/main/main.tscn.
## Usage (repo root): godot --headless --path project -s ../tools/generate_visual_pass.gd

const MAT := "res://data/materials/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/materials")
	DirAccess.make_dir_recursive_absolute("res://data/biomes")
	_materials()
	_data()
	_player_scene()
	_level_scene()
	_main_scene()
	print("GENERATED")
	quit(0)


func _save(res: Resource, path: String) -> Resource:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("save failed %s %d" % [path, err])
	return load(path)


func _noise_tex(seed: int, freq: float, size: int = 256, normal: bool = false, octaves: int = 4,
		noise_type: FastNoiseLite.NoiseType = FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = freq
	n.fractal_octaves = octaves
	n.noise_type = noise_type
	var t := NoiseTexture2D.new()
	t.width = size
	t.height = size
	t.seamless = true
	t.noise = n
	t.as_normal_map = normal
	t.generate_mipmaps = true
	return t


func _shader_mat(shader: String, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/%s.gdshader" % shader)
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	return m


func _materials() -> void:
	var detail := _save(_noise_tex(1, 0.02), MAT + "noise_detail.tres")
	var macro := _save(_noise_tex(2, 0.008, 256, false, 3), MAT + "noise_macro.tres")
	var clouds := _save(_noise_tex(3, 0.01, 512, false, 5), MAT + "noise_clouds.tres")
	var ripples := _save(_noise_tex(4, 0.03, 256, true), MAT + "noise_ripples_normal.tres")
	var mist := _save(_noise_tex(5, 0.012, 128, false, 3), MAT + "noise_mist.tres")
	var streaks := _save(_noise_tex(6, 0.06, 128, false, 2, FastNoiseLite.TYPE_CELLULAR), MAT + "noise_streaks.tres")

	_save(_shader_mat("terrain", {"detail_noise": detail, "macro_noise": macro}), MAT + "terrain.tres")
	_save(_shader_mat("stone", {"detail_noise": detail}), MAT + "stone.tres")
	_save(_shader_mat("stone", {"detail_noise": detail, "rune_color": Color(1.0, 0.12, 0.05), "rune_strength": 3.5,
			"moss_amount": 0.35}), MAT + "gate_stone.tres")
	_save(_shader_mat("foliage", {"wind_strength": 0.12, "translucency": 0.3}), MAT + "foliage_grass.tres")
	_save(_shader_mat("foliage", {"wind_strength": 0.06, "wind_speed": 0.8, "translucency": 0.2}), MAT + "foliage_leaf.tres")
	_save(_shader_mat("foliage", {"wind_strength": 0.35, "wind_speed": 0.9, "translucency": 0.1}), MAT + "foliage_vine.tres")
	_save(_shader_mat("glow_fungus", {}), MAT + "glow_fungus.tres")
	_save(_shader_mat("water", {"ripple_noise": ripples}), MAT + "water.tres")
	_save(_shader_mat("waterfall", {"streaks": streaks}), MAT + "waterfall.tres")
	_save(_shader_mat("mist_card", {"mist_noise": mist}), MAT + "mist.tres")
	_save(_shader_mat("light_shaft", {}), MAT + "light_shaft.tres")
	_save(_shader_mat("creature", {"flap_amount": 0.9}), MAT + "bat.tres")
	_save(_shader_mat("creature", {"body_color": Color(0.04, 0.07, 0.03), "glow_color": Color(0.8, 1.0, 0.3),
			"glow_energy": 1.2}), MAT + "frog.tres")
	_save(_shader_mat("creature", {"glow_color": Color(1.0, 0.12, 0.03), "glow_energy": 2.5}), MAT + "lurker_eyes.tres")
	_save(_shader_mat("firefly", {}), MAT + "firefly.tres")
	_save(_shader_mat("ring_marker", {}), MAT + "ring_marker.tres")
	_save(_shader_mat("sky_gloom", {"cloud_noise": clouds}), MAT + "sky_gloom.tres")

	var bark := StandardMaterial3D.new()
	bark.vertex_color_use_as_albedo = true
	bark.roughness = 0.95
	bark.cull_mode = BaseMaterial3D.CULL_DISABLED
	_save(bark, MAT + "bark_vertex.tres")
	var rock := StandardMaterial3D.new()
	rock.vertex_color_use_as_albedo = true
	rock.roughness = 0.9
	rock.cull_mode = BaseMaterial3D.CULL_DISABLED
	_save(rock, MAT + "rock_vertex.tres")
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.11, 0.075, 0.05)
	wood.roughness = 0.9
	_save(wood, MAT + "dark_wood.tres")


func _data() -> void:
	_save(load("res://scripts/world/terrain_config.gd").new(), "res://data/biomes/verdant_canopy_terrain.tres")
	_save(load("res://scripts/world/flora_config.gd").new(), "res://data/biomes/verdant_canopy_flora.tres")
	_save(load("res://scripts/world/fauna/fauna_config.gd").new(), "res://data/biomes/verdant_canopy_fauna.tres")
	_save(load("res://scripts/player/ninja_animation_config.gd").new(), "res://data/player/ninja_animations.tres")


func _own(node: Node, owner: Node) -> void:
	for child in node.get_children():
		if child.owner == null:
			child.owner = owner
		if child.scene_file_path == "":
			_own(child, owner)


func _pack(root: Node, path: String) -> void:
	_own(root, root)
	var ps := PackedScene.new()
	if ps.pack(root) != OK:
		push_error("pack failed " + path)
	_save(ps, path)
	root.free()


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
	var model: Node3D = (load("res://assets/models/ninja/ninja.glb") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	model.name = "NinjaModel"
	model.rotation.y = PI  # Mixamo faces +Z; gameplay forward is -Z.
	visual.add_child(model)
	model.owner = p

	var light := OmniLight3D.new()
	light.name = "ReadabilityLight"
	light.position = Vector3(0, 2.4, 0.8)
	light.light_color = Color(1.0, 0.85, 0.7)
	light.light_energy = 0.7
	light.omni_range = 5.0
	light.shadow_enabled = false
	p.add_child(light)

	var ring := MeshInstance3D.new()
	ring.name = "GroundRing"
	var ring_quad := QuadMesh.new()
	ring_quad.size = Vector2(1.6, 1.6)
	ring_quad.orientation = PlaneMesh.FACE_Y
	ring_quad.material = load(MAT + "ring_marker.tres")
	ring.mesh = ring_quad
	ring.position.y = 0.05
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(ring)

	var animator := Node.new()
	animator.name = "NinjaAnimator"
	animator.set_script(load("res://scripts/player/ninja_animator.gd"))
	animator.set("config", load("res://data/player/ninja_animations.tres"))
	animator.set("animation_player_path", NodePath("../Visual/NinjaModel/AnimationPlayer"))
	p.add_child(animator)

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
	cam.far = 250.0
	arm.add_child(cam)
	_pack(p, "res://scenes/player/player.tscn")


var _root: Node3D


func _box(node_name: String, size: Vector3, pos: Vector3, mat: String, rot_deg: Vector3 = Vector3.ZERO) -> CSGBox3D:
	var b := CSGBox3D.new()
	b.name = node_name
	b.size = size
	b.position = pos
	b.rotation_degrees = rot_deg
	b.use_collision = true
	b.collision_layer = 1
	b.collision_mask = 0
	b.material = load(MAT + mat + ".tres")
	_root.get_node("RouteGeometry").add_child(b)
	return b


func _column(node_name: String, pos: Vector3, radius: float, height: float) -> void:
	var c := CSGCylinder3D.new()
	c.name = node_name
	c.radius = radius
	c.height = height
	c.sides = 10
	c.position = pos + Vector3.DOWN * height * 0.5
	c.use_collision = true
	c.collision_mask = 0
	c.material = load(MAT + "stone.tres")
	_root.get_node("RouteGeometry").add_child(c)


func _omni(node_name: String, pos: Vector3, color: Color, energy: float, light_range: float) -> void:
	var l := OmniLight3D.new()
	l.name = node_name
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	_root.add_child(l)


func _level_scene() -> void:
	_root = Node3D.new()
	_root.name = "VerdantCanopy"

	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = load(MAT + "sky_gloom.tres")
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.24, 0.3, 0.32)
	env.ambient_light_energy = 3.5
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.35
	env.fog_enabled = true
	env.fog_light_color = Color(0.15, 0.19, 0.21)
	env.fog_density = 0.016
	env.fog_sky_affect = 0.3
	env.fog_height = 0.5
	env.fog_height_density = 0.04
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.85
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 0.85
	env_node.environment = env
	_root.add_child(env_node)

	var moon := DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.rotation_degrees = Vector3(-38, 35, 0)
	moon.light_color = Color(0.55, 0.64, 0.82)
	moon.light_energy = 1.2
	moon.shadow_enabled = true
	moon.shadow_opacity = 0.7
	moon.directional_shadow_max_distance = 55.0
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_root.add_child(moon)

	var terrain := Node3D.new()
	terrain.name = "Terrain"
	terrain.set_script(load("res://scripts/world/biome_terrain.gd"))
	terrain.set("material", load(MAT + "terrain.tres"))
	terrain.set("config", load("res://data/biomes/verdant_canopy_terrain.tres"))
	_root.add_child(terrain)

	var flora := Node3D.new()
	flora.name = "Flora"
	flora.set_script(load("res://scripts/world/flora_scatter.gd"))
	flora.set("terrain_path", NodePath("../Terrain"))
	flora.set("grass_material", load(MAT + "foliage_grass.tres"))
	flora.set("leaf_material", load(MAT + "foliage_leaf.tres"))
	flora.set("vine_material", load(MAT + "foliage_vine.tres"))
	flora.set("bark_material", load(MAT + "bark_vertex.tres"))
	flora.set("fungus_material", load(MAT + "glow_fungus.tres"))
	flora.set("rock_material", load(MAT + "rock_vertex.tres"))
	flora.set("stone_material", load(MAT + "stone.tres"))
	flora.set("config", load("res://data/biomes/verdant_canopy_flora.tres"))
	_root.add_child(flora)

	var fauna := Node3D.new()
	fauna.name = "Fauna"
	fauna.set_script(load("res://scripts/world/fauna/fauna_spawner.gd"))
	fauna.set("terrain_path", NodePath("../Terrain"))
	fauna.set("config", load("res://data/biomes/verdant_canopy_fauna.tres"))
	fauna.set("bat_material", load(MAT + "bat.tres"))
	fauna.set("frog_material", load(MAT + "frog.tres"))
	fauna.set("eye_material", load(MAT + "lurker_eyes.tres"))
	fauna.set("firefly_material", load(MAT + "firefly.tres"))
	_root.add_child(fauna)

	var atmos := Node3D.new()
	atmos.name = "Atmosphere"
	atmos.set_script(load("res://scripts/world/biome_atmosphere.gd"))
	atmos.set("terrain_path", NodePath("../Terrain"))
	atmos.set("sun_path", NodePath("../Moonlight"))
	atmos.set("environment_path", NodePath("../WorldEnvironment"))
	atmos.set("mist_material", load(MAT + "mist.tres"))
	atmos.set("shaft_material", load(MAT + "light_shaft.tres"))
	atmos.set("waterfall_material", load(MAT + "waterfall.tres"))
	atmos.set("water_material", load(MAT + "water.tres"))
	_root.add_child(atmos)

	var geo := Node3D.new()
	geo.name = "RouteGeometry"
	_root.add_child(geo)

	var spawn := Marker3D.new()
	spawn.name = "SpawnPoint"
	spawn.position = Vector3(0, 0.1, 0)
	_root.add_child(spawn)

	# Route pieces (same layout and collision as the Phase 1 graybox; restyled as ruins).
	_box("StepLow", Vector3(3, 0.5, 3), Vector3(-6, 0.25, -8), "stone")
	_box("StepMid", Vector3(3, 1.0, 3), Vector3(-9, 0.5, -8), "stone")
	_box("StepHigh", Vector3(3, 1.6, 3), Vector3(-12, 0.8, -8), "stone")
	_box("Ramp", Vector3(4, 0.5, 10), Vector3(10, 1.6, -12), "dark_wood", Vector3(18, 0, 0))
	_box("RaisedLedge", Vector3(8, 3.2, 8), Vector3(10, 1.6, -21), "stone")
	_box("RuinWall", Vector3(1, 6, 20), Vector3(4, 3, -32), "stone")
	_box("TunnelRoof", Vector3(6, 1, 6), Vector3(-4, 3.2, -30), "stone")
	_box("TunnelLeft", Vector3(1, 2.7, 6), Vector3(-6.5, 1.35, -30), "stone")
	_box("TunnelRight", Vector3(1, 2.7, 6), Vector3(-1.5, 1.35, -30), "stone")
	# Gorge stepping stones on ancient columns.
	_box("GapPlatform1", Vector3(4, 1, 4), Vector3(0, -0.5, -54), "stone")
	_box("GapPlatform2", Vector3(4, 1, 4), Vector3(1.5, -0.2, -60.5), "stone")
	_box("GapPlatform3", Vector3(4, 1, 4), Vector3(0, 0.1, -67), "stone")
	_column("GapColumn1", Vector3(0, -1.0, -54), 1.3, 22.0)
	_column("GapColumn2", Vector3(1.5, -0.7, -60.5), 1.3, 22.0)
	_column("GapColumn3", Vector3(0, -0.4, -67), 1.3, 22.0)
	# Boss gate (no logic until Phase 3): carved stone with glowing runes.
	_box("GatePillarL", Vector3(1.6, 8, 1.6), Vector3(-4.2, 4, -94), "gate_stone")
	_box("GatePillarR", Vector3(1.6, 8, 1.6), Vector3(4.2, 4, -94), "gate_stone")
	_box("GateLintel", Vector3(11, 1.4, 2.0), Vector3(0, 8.5, -94), "gate_stone")
	_box("GateCrown", Vector3(5, 1.2, 1.6), Vector3(0, 9.8, -94), "gate_stone")

	_omni("GateGlow", Vector3(0, 4, -91), Color(1.0, 0.2, 0.08), 2.5, 16.0)
	_omni("ShrineGlow", Vector3(-9, 2.5, -8), Color(0.2, 0.9, 0.8), 1.2, 9.0)
	_omni("GorgeGlow", Vector3(0, -12, -60), Color(0.15, 0.6, 0.7), 2.0, 22.0)

	_pack(_root, "res://scenes/biomes/verdant_canopy.tscn")


func _main_scene() -> void:
	var main := Node3D.new()
	main.name = "Main"
	main.set_script(load("res://scripts/main/main.gd"))
	var level: Node = (load("res://scenes/biomes/verdant_canopy.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
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
	hud.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8, 0.85))
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
	_save(ps, "res://scenes/main/main.tscn")
	main.free()
