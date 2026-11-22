extends SceneTree
## One-off generator for the "gloomy Verdant Canopy" visual pass: materials, data resources,
## the player scene (Mixamo ninja model), the checkpoint scene and the level scene (incl. Phase 2 route). Re-running OVERWRITES
## data/materials/*, scenes/player/player.tscn, scenes/biomes/verdant_canopy.tscn and scenes/main/main.tscn.
## Usage (repo root): godot --headless --path project -s ../tools/generate_visual_pass.gd

const MAT := "res://data/materials/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/materials")
	DirAccess.make_dir_recursive_absolute("res://data/biomes")
	_materials()
	_data()
	_enemy_scenes()
	_player_scene()
	_checkpoint_scene()
	_level_scene()
	_main_scene()
	_hunt_board_scene()
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
	_save(_shader_mat("stone", {"detail_noise": detail, "climb_marks": 1.0}), MAT + "climb_stone.tres")
	_save(_shader_mat("spirit_flame", {}), MAT + "spirit_flame.tres")
	_save(_shader_mat("ring_marker", {"color": Color(1.0, 0.15, 0.05), "strength": 0.7}), MAT + "arena_sigil.tres")
	_save(_shader_mat("health_bar", {}), MAT + "health_bar.tres")
	_save(_shader_mat("attack_warning", {}), MAT + "attack_warning.tres")
	_save(_shader_mat("lock_reticle", {}), MAT + "lock_reticle.tres")
	_save(_shader_mat("creature", {"body_color": Color(0.09, 0.08, 0.06), "glow_color": Color(1.0, 0.75, 0.2),
			"glow_energy": 2.5}), MAT + "thornling.tres")
	var blade := StandardMaterial3D.new()
	blade.vertex_color_use_as_albedo = true
	blade.metallic = 0.85
	blade.roughness = 0.25
	blade.cull_mode = BaseMaterial3D.CULL_DISABLED
	_save(blade, MAT + "blade.tres")
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
	_save(load("res://scripts/traversal/traversal_config.gd").new(), "res://data/player/traversal.tres")
	_expedition_data()
	_combat_data()


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
	p.collision_mask = 1 | 8  # world + enemies
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

	var traversal := Node.new()
	traversal.name = "Traversal"
	traversal.set_script(load("res://scripts/traversal/traversal_component.gd"))
	traversal.set("config", load("res://data/player/traversal.tres"))
	p.add_child(traversal)

	var animator := Node.new()
	animator.name = "NinjaAnimator"
	animator.set_script(load("res://scripts/player/ninja_animator.gd"))
	animator.set("config", load("res://data/player/ninja_animations.tres"))
	animator.set("animation_player_path", NodePath("../Visual/NinjaModel/AnimationPlayer"))
	p.add_child(animator)

	# ---- Phase 4 combat
	var health := Node.new()
	health.name = "Health"
	health.set_script(load("res://scripts/combat/health_component.gd"))
	p.add_child(health)
	var hurt := Area3D.new()
	hurt.name = "Hurtbox"
	hurt.set_script(load("res://scripts/combat/hurtbox.gd"))
	hurt.set("team", &"player")
	hurt.set("health_path", NodePath("../Health"))
	var hcol := CollisionShape3D.new()
	var hcap := CapsuleShape3D.new()
	hcap.radius = 0.45
	hcap.height = 1.8
	hcol.shape = hcap
	hcol.position.y = 0.9
	hurt.add_child(hcol)
	p.add_child(hurt)
	var weapon := Area3D.new()
	weapon.name = "WeaponHitbox"
	weapon.set_script(load("res://scripts/combat/hitbox.gd"))
	weapon.set("team", &"player")
	var wcol := CollisionShape3D.new()
	var wbox := BoxShape3D.new()
	wbox.size = Vector3(2.0, 1.6, 1.9)
	wcol.shape = wbox
	wcol.position = Vector3(0, 1.0, -1.05)
	weapon.add_child(wcol)
	visual.add_child(weapon)
	var combat := Node.new()
	combat.name = "Combat"
	combat.set_script(load("res://scripts/combat/player_combat.gd"))
	combat.set("config", load("res://data/combat/player_combat.tres"))
	p.add_child(combat)
	var mount := Node.new()
	mount.name = "WeaponMount"
	mount.set_script(load("res://scripts/combat/weapon_mount.gd"))
	mount.set("blade_material", load(MAT + "blade.tres"))
	p.add_child(mount)
	var reticle := MeshInstance3D.new()
	reticle.name = "LockReticle"
	reticle.set_script(load("res://scripts/combat/lock_reticle.gd"))
	var rq := QuadMesh.new()
	rq.size = Vector2(0.9, 0.9)
	rq.material = load(MAT + "lock_reticle.tres")
	reticle.mesh = rq
	reticle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(reticle)

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


func _checkpoint_scene() -> void:
	DirAccess.make_dir_recursive_absolute("res://scenes/world")
	var area := Area3D.new()
	area.name = "Checkpoint"
	area.set_script(load("res://scripts/world/checkpoint.gd"))
	var col := CollisionShape3D.new()
	col.name = "Trigger"
	var box := BoxShape3D.new()
	box.size = Vector3(13, 4, 3)
	col.shape = box
	col.position = Vector3(4.5, 2, 0)  # The shrine sits at the left edge of the route.
	area.add_child(col)
	var stone: Material = load(MAT + "stone.tres")
	var base := MeshInstance3D.new()
	base.name = "ShrineBase"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35
	cyl.bottom_radius = 0.5
	cyl.height = 1.3
	cyl.radial_segments = 8
	cyl.material = stone
	base.mesh = cyl
	base.position.y = 0.65
	area.add_child(base)
	var cap := MeshInstance3D.new()
	cap.name = "ShrineCap"
	var cap_mesh := BoxMesh.new()
	cap_mesh.size = Vector3(1.1, 0.18, 1.1)
	cap_mesh.material = stone
	cap.mesh = cap_mesh
	cap.position.y = 1.38
	area.add_child(cap)
	var flame := MeshInstance3D.new()
	flame.name = "Flame"
	var q := QuadMesh.new()
	q.size = Vector2(0.55, 0.9)
	q.material = load(MAT + "spirit_flame.tres")
	flame.mesh = q
	flame.position.y = 1.9
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	area.add_child(flame)
	var light := OmniLight3D.new()
	light.name = "FlameLight"
	light.position.y = 2.0
	light.omni_range = 7.0
	area.add_child(light)
	_pack(area, "res://scenes/world/checkpoint.tscn")


var _root: Node3D


func _climb_box(node_name: String, size: Vector3, pos: Vector3) -> CSGBox3D:
	var b := _box(node_name, size, pos, "climb_stone")
	b.collision_layer = 1 | 4  # world + climbable
	return b


func _boulder(node_name: String, pos: Vector3, radius: float) -> void:
	var s := CSGSphere3D.new()
	s.name = node_name
	s.radius = radius
	s.radial_segments = 10
	s.rings = 7
	s.position = pos
	s.scale = Vector3(1.0, 0.75, 1.1)
	s.use_collision = true
	s.collision_mask = 0
	s.material = load(MAT + "stone.tres")
	_root.get_node("RouteGeometry").add_child(s)


func _checkpoint(node_name: String, pos: Vector3) -> void:
	var cp: Node3D = (load("res://scenes/world/checkpoint.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	cp.name = node_name
	cp.position = pos
	_root.get_node("Checkpoints").add_child(cp)


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
	_climb_box("RaisedLedge", Vector3(8, 3.2, 8), Vector3(10, 1.6, -21))
	_climb_box("RuinWall", Vector3(1, 6, 20), Vector3(4, 3, -32))
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

	# Phase 2 traversal route.
	# Rampart: climbable ruined wall across the route before the gorge (top at y 4).
	_climb_box("Rampart", Vector3(40, 5, 2), Vector3(0, 1.5, -45.5))
	# Optional high route: raised ledge -> broken stone bridge (jump the gap) -> rampart top.
	_box("BridgeA", Vector3(1.6, 0.3, 8), Vector3(10, 3.05, -29), "stone")
	_box("BridgeB", Vector3(1.6, 0.3, 9), Vector3(10, 3.85, -40), "stone")
	_column("BridgeColumnA1", Vector3(10, 2.9, -27.5), 0.35, 4.0)
	_column("BridgeColumnA2", Vector3(10, 2.9, -32.0), 0.35, 4.0)
	_column("BridgeColumnB1", Vector3(10, 3.7, -37.0), 0.35, 5.0)
	_column("BridgeColumnB2", Vector3(10, 3.7, -43.0), 0.35, 5.0)
	# Far bank of the gorge: a sheer stone wall 1.9 m above the last stepping stone.
	# Too high to jump onto: catch the ledge and pull up.
	_box("FarBankWall", Vector3(30, 22.5, 3), Vector3(0, -8.75, -72.5), "stone")
	# Boulders to weave around.
	_boulder("Boulder1", Vector3(3.2, 0.4, -6), 1.1)
	_boulder("Boulder2", Vector3(-3.3, 0.3, -15), 1.0)
	_boulder("Boulder3", Vector3(-2.9, 0.2, -36.5), 0.9)
	_boulder("Boulder4", Vector3(3.0, 0.3, -86), 1.2)
	# Checkpoint shrines (spawn is also a checkpoint, set by main.gd).
	var cps := Node3D.new()
	cps.name = "Checkpoints"
	_root.add_child(cps)
	_checkpoint("CheckpointSpawn", Vector3(-4.5, 0, 1))
	_checkpoint("CheckpointGorge", Vector3(-4.5, 0, -48))
	_checkpoint("CheckpointGate", Vector3(-4.5, 0, -78))

	# Phase 4: training dummy at spawn and a Thornling hollow off the main path (west of the tunnel).
	var enemies := Node3D.new()
	enemies.name = "Enemies"
	_root.add_child(enemies)
	for spec in [["TrainingDummy", "res://scenes/enemies/training_dummy.tscn", Vector3(4.5, 0, -4)],
			["ThornlingA", "res://scenes/enemies/thornling.tscn", Vector3(-23, 0.2, -20)],
			["ThornlingB", "res://scenes/enemies/thornling.tscn", Vector3(-26, 0.2, -25)]]:
		var e: Node3D = (load(spec[1]) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		e.name = spec[0]
		e.position = spec[2]
		enemies.add_child(e)

	# Phase 3: boss arena behind the gate. Walls funnel the player through the gate.
	_box("ArenaWallL", Vector3(40, 8, 1.5), Vector3(-25.0, 2, -94), "stone")
	_box("ArenaWallR", Vector3(40, 8, 1.5), Vector3(25.0, 2, -94), "stone")
	var trigger := Area3D.new()
	trigger.name = "BossArenaTrigger"
	trigger.set_script(load("res://scripts/world/boss_arena_trigger.gd"))
	var tcol := CollisionShape3D.new()
	var tbox := BoxShape3D.new()
	# Covers the whole arena region (gate line z -96 to the map edge), so even a teleport or
	# respawn inside it counts as entry.
	tbox.size = Vector3(160, 80, 54)
	tcol.shape = tbox
	trigger.add_child(tcol)
	trigger.position = Vector3(0, 10, -123)
	_root.add_child(trigger)
	for i in 10:
		var ang := TAU * float(i) / 10.0 + PI / 10.0
		if absf(wrapf(ang - PI / 2.0, -PI, PI)) < 0.5:
			continue  # Leave the entrance (facing the gate, +Z) open.
		var p := Vector3(cos(ang) * 17.0, 0, -120.0 + sin(ang) * 17.0)
		_column("ArenaPillar%d" % i, p + Vector3.UP * (4.0 + float(i % 3) * 1.5), 0.9, 8.0)
	var sigil := MeshInstance3D.new()
	sigil.name = "ArenaSigil"
	var sq := QuadMesh.new()
	sq.size = Vector2(16, 16)
	sq.orientation = PlaneMesh.FACE_Y
	sq.material = load(MAT + "arena_sigil.tres")
	sigil.mesh = sq
	sigil.position = Vector3(0, 0.06, -120)
	sigil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(sigil)
	_omni("ArenaGlow", Vector3(0, 5, -120), Color(1.0, 0.15, 0.05), 3.0, 22.0)

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
	var expedition := Node.new()
	expedition.name = "Expedition"
	expedition.set_script(load("res://scripts/expedition/expedition_manager.gd"))
	expedition.set("hunt", load("res://data/hunts/kurogale.tres"))
	expedition.set("default_config", load("res://data/expedition/default_expedition.tres"))
	expedition.set("scene_path", "res://scenes/main/main.tscn")
	main.add_child(expedition)
	expedition.owner = main

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
	var fx := Node3D.new()
	fx.name = "CombatFx"
	fx.set_script(load("res://scripts/combat/combat_fx.gd"))
	fx.set("spark_material", load(MAT + "firefly.tres"))
	main.add_child(fx)
	fx.owner = main
	var php := Control.new()
	php.name = "PlayerHud"
	php.set_script(load("res://scripts/ui/player_hud.gd"))
	php.set("player_path", NodePath("../../Player"))
	php.set_anchors_preset(Control.PRESET_FULL_RECT)
	php.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(php)
	php.owner = main
	for spec in [["ExpeditionHud", "res://scripts/ui/expedition_hud.gd"], ["PauseMenu", "res://scripts/ui/pause_menu.gd"],
			["ExpeditionResults", "res://scripts/ui/expedition_results.gd"]]:
		var c := Control.new()
		c.name = spec[0]
		c.set_script(load(spec[1]))
		c.set("manager_path", NodePath("../../Expedition"))
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE if spec[0] == "ExpeditionHud" else Control.MOUSE_FILTER_STOP
		ui.add_child(c)
		c.owner = main
	var ps := PackedScene.new()
	ps.pack(main)
	_save(ps, "res://scenes/main/main.tscn")
	main.free()


func _hunt(id: String, beast: String, epithet: String, element: String, weakness: String, signature: String,
		description: String, config: ExpeditionConfig) -> HuntDefinition:
	var h := HuntDefinition.new()
	h.id = StringName(id)
	h.beast_name = beast
	h.epithet = epithet
	h.element = element
	h.weakness = weakness
	h.signature = signature
	h.description = description
	h.config = config
	return _save(h, "res://data/hunts/%s.tres" % id)


func _biome(id: String, name: String, mood: String, hunts: Array[HuntDefinition], unlocked: bool, note: String,
		accent: Color) -> BiomeDefinition:
	var b := BiomeDefinition.new()
	b.id = StringName(id)
	b.display_name = name
	b.mood = mood
	b.hunts = hunts
	b.unlocked = unlocked
	b.locked_note = note
	b.accent = accent
	b.expedition_scene = "res://scenes/main/main.tscn" if unlocked else ""
	return _save(b, "res://data/biomes/biome_%s.tres" % id)


func _expedition_data() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/expedition")
	DirAccess.make_dir_recursive_absolute("res://data/hunts")
	var cfg: ExpeditionConfig = _save(ExpeditionConfig.new(), "res://data/expedition/default_expedition.tres")
	var k := _hunt("kurogale", "Kurogale", "the Thornback Stag", "Nature", "Fire", "Root snare, antler sweep",
			"A stag of living thorn that rules the drowned ruins. Its antlers can be broken.", cfg)
	var a := _hunt("ashen_oni_tortoise", "Ashen Oni-Tortoise", "", "Fire", "Water", "Shell slam, lava burst", "", cfg)
	var n := _hunt("nami", "Nami", "the Lantern Serpent", "Water / Spirit", "Lightning", "Flood wave, illusion", "", cfg)
	var r := _hunt("raijins_echo", "Raijin's Echo", "Sky Roc", "Lightning", "Earth", "Dive, wind shear", "", cfg)
	_biome("verdant_canopy", "Verdant Canopy", "Drowned ruins under a storm-dark canopy.", [k] as Array[HuntDefinition],
			true, "", Color(0.35, 0.95, 0.75))
	_biome("emberwild", "Emberwild", "Volcanic jungle of black spires and lava.", [a] as Array[HuntDefinition],
			false, "arrives in Phase 8", Color(1.0, 0.45, 0.15))
	_biome("moonfen", "Moonfen", "Bioluminescent swamp in violet night.", [n] as Array[HuntDefinition],
			false, "arrives in Phase 9", Color(0.7, 0.35, 1.0))
	_biome("stormcrag", "Stormcrag", "Temple peaks under endless lightning.", [r] as Array[HuntDefinition],
			false, "arrives in Phase 10", Color(0.45, 0.7, 1.0))


func _hunt_board_scene() -> void:
	DirAccess.make_dir_recursive_absolute("res://scenes/ui")
	var board := Control.new()
	board.name = "HuntBoard"
	board.set_script(load("res://scripts/ui/hunt_board.gd"))
	var list: Array[BiomeDefinition] = []
	for id in ["verdant_canopy", "emberwild", "moonfen", "stormcrag"]:
		list.append(load("res://data/biomes/biome_%s.tres" % id))
	board.set("biomes", list)
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pack(board, "res://scenes/ui/hunt_board.tscn")


func _attack(id: String, start: float, end: float, hit: float, speed: float, damage: float, stagger: float,
		knockback: float, lunge: float) -> AttackDefinition:
	var a := AttackDefinition.new()
	a.id = StringName(id)
	a.clip = &"Dual_Weapon_Combo"
	a.clip_start = start
	a.clip_end = end
	a.clip_hit = hit
	a.speed = speed
	a.damage = damage
	a.stagger = stagger
	a.knockback = knockback
	a.lunge_speed = lunge
	return _save(a, "res://data/combat/attack_%s.tres" % id)


func _combat_data() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/combat")
	DirAccess.make_dir_recursive_absolute("res://data/enemies")
	# Slices of Dual_Weapon_Combo; hit times are the measured hand-speed peaks (0.77/1.18/1.83/2.68 s).
	var l1 := _attack("light_1", 0.35, 1.0, 0.77, 1.15, 10.0, 8.0, 1.5, 3.0)
	var l2 := _attack("light_2", 1.0, 1.45, 1.18, 1.1, 11.0, 8.0, 1.5, 3.0)
	var l3 := _attack("light_3", 1.45, 2.25, 1.83, 1.0, 17.0, 18.0, 4.0, 4.0)
	var heavy := _attack("heavy", 2.25, 3.3, 2.68, 0.85, 32.0, 30.0, 6.0, 2.0)
	var cfg := PlayerCombatConfig.new()
	cfg.light_combo = [l1, l2, l3] as Array[AttackDefinition]
	cfg.heavy = heavy
	_save(cfg, "res://data/combat/player_combat.tres")
	_save(EnemyConfig.new(), "res://data/enemies/thornling.tres")


func _enemy_scenes() -> void:
	DirAccess.make_dir_recursive_absolute("res://scenes/enemies")
	# Thornling.
	var t := CharacterBody3D.new()
	t.name = "Thornling"
	t.set_script(load("res://scripts/enemies/thornling.gd"))
	t.set("config", load("res://data/enemies/thornling.tres"))
	var col := CollisionShape3D.new()
	col.name = "Collision"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 1.0
	col.shape = cap
	col.position.y = 0.5
	t.add_child(col)
	var vis := Node3D.new()
	vis.name = "Visual"
	t.add_child(vis)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = ProceduralMeshes.thornling(load(MAT + "thornling.tres"))
	vis.add_child(body)
	var hb := Area3D.new()
	hb.name = "LungeHitbox"
	hb.set_script(load("res://scripts/combat/hitbox.gd"))
	hb.set("team", &"enemy")
	var hbc := CollisionShape3D.new()
	var hbs := BoxShape3D.new()
	hbs.size = Vector3(1.1, 1.0, 1.3)
	hbc.shape = hbs
	hbc.position = Vector3(0, 0.55, -0.7)
	hb.add_child(hbc)
	vis.add_child(hb)
	var health := Node.new()
	health.name = "Health"
	health.set_script(load("res://scripts/combat/health_component.gd"))
	t.add_child(health)
	var hurt := Area3D.new()
	hurt.name = "Hurtbox"
	hurt.set_script(load("res://scripts/combat/hurtbox.gd"))
	hurt.set("team", &"enemy")
	hurt.set("health_path", NodePath("../Health"))
	var hc := CollisionShape3D.new()
	var hs := BoxShape3D.new()
	hs.size = Vector3(1.0, 1.1, 1.7)
	hc.shape = hs
	hc.position = Vector3(0, 0.6, -0.1)
	hurt.add_child(hc)
	t.add_child(hurt)
	var warn := MeshInstance3D.new()
	warn.name = "Warning"
	var wq := QuadMesh.new()
	wq.size = Vector2(1.3, 4.0)
	wq.orientation = PlaneMesh.FACE_Y
	wq.material = load(MAT + "attack_warning.tres")
	warn.mesh = wq
	warn.top_level = true
	warn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	t.add_child(warn)
	var bar := MeshInstance3D.new()
	bar.name = "HealthBar"
	var bq := QuadMesh.new()
	bq.size = Vector2(1.0, 0.14)
	bq.material = load(MAT + "health_bar.tres")
	bar.mesh = bq
	bar.position.y = 1.55
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	t.add_child(bar)
	_pack(t, "res://scenes/enemies/thornling.tscn")

	# Training dummy.
	var d := StaticBody3D.new()
	d.name = "TrainingDummy"
	d.set_script(load("res://scripts/enemies/training_dummy.gd"))
	d.collision_layer = 8
	var dcol := CollisionShape3D.new()
	var dcyl := CylinderShape3D.new()
	dcyl.radius = 0.3
	dcyl.height = 2.0
	dcol.shape = dcyl
	dcol.position.y = 1.0
	d.add_child(dcol)
	var dvis := Node3D.new()
	dvis.name = "Visual"
	d.add_child(dvis)
	var dm := MeshInstance3D.new()
	dm.name = "Mesh"
	dm.mesh = ProceduralMeshes.training_dummy(load(MAT + "bark_vertex.tres"))
	dvis.add_child(dm)
	var dh := Node.new()
	dh.name = "Health"
	dh.set_script(load("res://scripts/combat/health_component.gd"))
	dh.set("max_health", 500.0)
	d.add_child(dh)
	var dhurt := Area3D.new()
	dhurt.name = "Hurtbox"
	dhurt.set_script(load("res://scripts/combat/hurtbox.gd"))
	dhurt.set("team", &"enemy")
	dhurt.set("health_path", NodePath("../Health"))
	var dhc := CollisionShape3D.new()
	var dhs := CylinderShape3D.new()
	dhs.radius = 0.5
	dhs.height = 1.6
	dhc.shape = dhs
	dhc.position.y = 1.2
	dhurt.add_child(dhc)
	d.add_child(dhurt)
	_pack(d, "res://scenes/enemies/training_dummy.tscn")
