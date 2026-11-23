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
	_boss_scenes_prerequisites()
	_data()
	_enemy_scenes()
	_boss_scenes()
	_player_scene()
	_checkpoint_scene()
	_phase6_scenes()
	_crafting_data()
	_level_scene()
	_main_scene()
	_emberwild()  # Phase 8
	_moonfen()  # Phase 9
	_stormcrag()  # Phase 10
	_hunt_board_scene()
	print("GENERATED")
	quit(0)


func _save(res: Resource, path: String) -> Resource:
	if res is ShaderMaterial:
		Cc0Surfaces.apply(res, path.get_file().get_basename())  # CC0 detail textures (art pass).
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
	_save(_shader_mat("ring_marker", {"color": Color(0.5, 0.25, 0.7), "strength": 0.35}), MAT + "arena_sigil.tres")  # Not red: red means danger.
	_save(_shader_mat("health_bar", {}), MAT + "health_bar.tres")
	_save(_shader_mat("attack_warning", {}), MAT + "attack_warning.tres")
	_save(_shader_mat("lock_reticle", {}), MAT + "lock_reticle.tres")
	_save(_shader_mat("area_warning", {}), MAT + "area_warning.tres")
	_save(_shader_mat("area_warning", {"color": Color(0.3, 1.0, 0.35)}), MAT + "snare_warning.tres")
	_save(_shader_mat("creature", {"body_color": Color(0.13, 0.11, 0.085), "glow_color": Color(0.5, 1.0, 0.3),
			"glow_energy": 4.0, "spine_idle": Color(0.12, 0.2, 0.08)}), MAT + "kurogale_body.tres")
	_save(_shader_mat("creature", {"body_color": Color(0.3, 0.26, 0.2), "spine_idle": Color(0.34, 0.3, 0.22),
			"spine_color": Color(1.0, 0.25, 0.05), "spine_strength": 0.6}), MAT + "kurogale_antlers.tres")
	_save(_shader_mat("creature", {"body_color": Color(0.09, 0.08, 0.06), "glow_color": Color(1.0, 0.75, 0.2),
			"glow_energy": 2.5}), MAT + "thornling.tres")
	var blade := StandardMaterial3D.new()
	blade.vertex_color_use_as_albedo = true
	blade.metallic = 0.85
	blade.roughness = 0.25
	blade.cull_mode = BaseMaterial3D.CULL_DISABLED
	_save(blade, MAT + "blade.tres")
	_save(_shader_mat("sky_gloom", {"cloud_noise": clouds}), MAT + "sky_gloom.tres")

	# Art pass: textured `painted` shader (was StandardMaterial3D with vertex colour).
	for f: String in Cc0Surfaces.PAINTED:
		_save(Cc0Surfaces.make_painted(f), MAT + f + ".tres")


func _data() -> void:
	_save(load("res://scripts/world/terrain_config.gd").new(), "res://data/biomes/verdant_canopy_terrain.tres")
	_save(load("res://scripts/world/flora_config.gd").new(), "res://data/biomes/verdant_canopy_flora.tres")
	_save(load("res://scripts/world/fauna/fauna_config.gd").new(), "res://data/biomes/verdant_canopy_fauna.tres")
	_save(load("res://scripts/player/ninja_animation_config.gd").new(), "res://data/player/ninja_animations.tres")
	_save(load("res://scripts/traversal/traversal_config.gd").new(), "res://data/player/traversal.tres")
	_expedition_data()
	_combat_data()
	_boss_data()


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
	env.ambient_light_energy = 4.3
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.17, 0.21, 0.23)
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
	moon.light_energy = 1.35
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
	atmos.set("mood", load("res://data/mood/verdant_canopy.tres"))  # Art pass stage 3 (tools/generate_moods.gd).
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
	_omni("ArenaGlow", Vector3(0, 5, -120), Color(0.55, 0.3, 0.8), 2.0, 22.0)
	# Phase 5: Kurogale sleeps in the arena, facing the gate (+Z).
	var boss: Node3D = (load("res://scenes/bosses/kurogale.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	boss.name = "Boss"
	boss.position = Vector3(0, 0.2, -121)
	boss.rotation.y = PI
	_root.add_child(boss)

	# Phase 6: objective marker, gatherables on the optional paths, lore stones.
	var marker := Marker3D.new()
	marker.name = "ArenaGateMarker"
	marker.position = Vector3(0, 0, -94)
	_root.add_child(marker)
	var gather := Node3D.new()
	gather.name = "Gatherables"
	_root.add_child(gather)
	var spots := [
		# [scene, position, snap to ground]
		["glowcap", Vector3(-24, 0, -22), true], ["glowcap", Vector3(-27.5, 0, -18.5), true],
		["glowcap", Vector3(-21, 0, -26.5), true],                          # Thornling hollow
		["glowcap", Vector3(11.5, 3.25, -23), false], ["glowcap", Vector3(10, 4.05, -42), false],  # High route
		["glowcap", Vector3(2.2, 0.35, -60.5), false],                      # Gorge stepping stone
		["glowcap", Vector3(8, 2.55, -72.5), false],                        # Far-bank wall top
		["ruin_shard", Vector3(6.5, 0, -37), true], ["ruin_shard", Vector3(-19, 0, -46.5), true],
	]
	for i in spots.size():
		var spot: Array = spots[i]
		var pk: Node3D = (load("res://scenes/world/pickup_%s.tscn" % spot[0]) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		pk.name = "%s_%d" % [spot[0], i]
		pk.position = spot[1]
		pk.set("snap_to_ground", spot[2])
		gather.add_child(pk)
	var lore := [
		["The Drowned Way", "Before the canopy closed, pilgrims walked this road to the stag-shrine. The waters rose, the shrine sank, and only the thorns remember the way.", Vector3(-7.5, 0, 3.5)],
		["Of Kurogale", "It sheds no antler and forgets no trespass. Strike while its head is bowed: the crown of thorn breaks only then. It fears the ember.", Vector3(6.5, 0, -82)],
	]
	for i in lore.size():
		var ls: Node3D = (load("res://scenes/world/lore_stone.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		ls.name = "LoreStone%d" % i
		ls.set("title", lore[i][0])
		ls.set("text", lore[i][1])
		ls.position = lore[i][2]
		gather.add_child(ls)

	_omni("GateGlow", Vector3(0, 4, -91), Color(1.0, 0.2, 0.08), 2.5, 16.0)
	_omni("ShrineGlow", Vector3(-9, 2.5, -8), Color(0.2, 0.9, 0.8), 1.2, 9.0)
	_omni("GorgeGlow", Vector3(0, -12, -60), Color(0.15, 0.6, 0.7), 2.0, 22.0)

	_pack(_root, "res://scenes/biomes/verdant_canopy.tscn")


func _main_scene(level_path: String = "res://scenes/biomes/verdant_canopy.tscn",
		hunt_path: String = "res://data/hunts/kurogale.tres", out_path: String = "res://scenes/main/main.tscn") -> void:
	var main := Node3D.new()
	main.name = "Main"
	main.set_script(load("res://scripts/main/main.gd"))
	var level: Node = (load(level_path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
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
	expedition.set("hunt", load(hunt_path))
	expedition.set("default_config", load("res://data/expedition/default_expedition.tres"))
	expedition.set("scene_path", out_path)
	expedition.set("crafting", load("res://data/crafting/catalog.tres"))
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
	for spec in [["ExpeditionHud", "res://scripts/ui/expedition_hud.gd"], ["BossHud", "res://scripts/ui/boss_hud.gd"],
			["PauseMenu", "res://scripts/ui/pause_menu.gd"],
			["ExpeditionResults", "res://scripts/ui/expedition_results.gd"]]:
		var c := Control.new()
		c.name = spec[0]
		c.set_script(load(spec[1]))
		c.set("manager_path", NodePath("../../Expedition"))
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE if spec[0].ends_with("Hud") else Control.MOUSE_FILTER_STOP
		ui.add_child(c)
		c.owner = main
	var ps := PackedScene.new()
	ps.pack(main)
	_save(ps, out_path)
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
	var items: Array[ItemDefinition] = [load("res://data/items/thornback_antler.tres"), load("res://data/items/kurogale_hide.tres"),
			load("res://data/items/glowcap.tres"), load("res://data/items/ruin_shard.tres")]
	board.set("known_items", items)
	board.set("crafting", load("res://data/crafting/catalog.tres"))
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
	heavy.trail_width = 1.3  # Slash trail: wider and brighter than the light combo.
	heavy.trail_intensity = 1.35
	_save(heavy, "res://data/combat/attack_heavy.tres")
	var cfg := PlayerCombatConfig.new()
	cfg.light_combo = [l1, l2, l3] as Array[AttackDefinition]
	cfg.heavy = heavy
	# Ember Talisman: quick throw (first combo slice, sped up) that launches a fire projectile.
	var skill := _attack("ember_talisman", 0.35, 0.95, 0.7, 1.6, 18.0, 15.0, 2.0, 0.0)
	skill.element = &"fire"
	skill.projectile_scene = load("res://scenes/combat/fire_talisman.tscn")
	_save(skill, "res://data/combat/attack_ember_talisman.tres")
	cfg.skill = load("res://data/combat/attack_ember_talisman.tres")
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


func _item(id: String, name: String, desc: String, color: Color, rarity: int) -> ItemDefinition:
	var it := ItemDefinition.new()
	it.id = StringName(id)
	it.display_name = name
	it.description = desc
	it.color = color
	it.rarity = rarity
	return _save(it, "res://data/items/%s.tres" % id)


func _boss_attack(id: String, name: String, telegraph: float, active: float, recovery: float, damage: float,
		knockback: float, min_r: float, max_r: float, weight: float, cooldown: float, counter: String) -> BossAttackDefinition:
	var a := BossAttackDefinition.new()
	a.id = StringName(id)
	a.display_name = name
	a.telegraph_time = telegraph
	a.active_time = active
	a.recovery_time = recovery
	a.damage = damage
	a.knockback = knockback
	a.min_range = min_r
	a.max_range = max_r
	a.weight = weight
	a.cooldown = cooldown
	a.counterplay = counter
	return a


func _boss_data() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/items")
	DirAccess.make_dir_recursive_absolute("res://data/bosses")
	var antler := _item("thornback_antler", "Thornback Antler", "A broken antler of living thorn. Still warm.",
			Color(0.75, 0.65, 0.45), 1)
	var hide := _item("kurogale_hide", "Kurogale's Hide", "Bark-like hide carved from the Thornback Stag.",
			Color(0.35, 0.3, 0.2), 0)
	var el := ElementProfile.new()
	el.affinity = &"nature"
	el.multipliers = {&"fire": 1.5, &"earth": 0.5}
	var sweep := _boss_attack("antler_sweep", "Antler Sweep", 0.9, 0.35, 1.1, 24.0, 8.0, 0.0, 5.5, 3.0, 2.5,
			"Roll away or get behind it; its head stays low afterwards: strike the antlers.")
	var snare := _boss_attack("root_snare", "Root Snare", 1.2, 0.45, 0.9, 18.0, 4.0, 3.0, 22.0, 2.0, 6.0,
			"Step out of the glowing green rings before the roots erupt.")
	var charge := _boss_attack("charge", "Charge", 1.0, 0.9, 1.2, 28.0, 10.0, 7.0, 26.0, 2.0, 5.0,
			"Roll sideways off the red strip; if it slams into a pillar it is stunned.")
	charge.move_speed = 15.0
	# Behaviour (BossController reads these; see BossAttackDefinition.Kind).
	sweep.kind = BossAttackDefinition.Kind.FRONT
	sweep.hitbox_node = NodePath("Front/SweepHitbox")
	sweep.warning_node = NodePath("Front/SweepWarning")
	sweep.telegraph_pitch = -0.3
	sweep.glow = BossAttackDefinition.Glow.PARTS
	sweep.weakened_by_part = &"antler"
	sweep.element = &"nature"
	snare.kind = BossAttackDefinition.Kind.ERUPTIONS
	snare.eruption_scene = load("res://scenes/bosses/root_snare.tscn")
	snare.eruption_offsets = PackedVector3Array([Vector3.ZERO, Vector3(2.6, 0, 1.2), Vector3(-2.4, 0, -1.6)])
	snare.telegraph_pitch = 0.2
	snare.glow = BossAttackDefinition.Glow.BODY
	snare.element = &"nature"
	charge.kind = BossAttackDefinition.Kind.DASH
	charge.hitbox_node = NodePath("Front/ChargeHitbox")
	charge.warning_node = NodePath("Front/ChargeWarning")
	charge.telegraph_pitch = -0.12
	charge.telegraph_wobble = 0.1
	charge.stuns_on_wall = true
	charge.element = &"nature"
	var burst := _boss_attack("thorn_burst", "Thorn Burst", 1.0, 0.3, 0.9, 20.0, 9.0, 0.0, 5.0, 2.0, 6.0,
			"Leave the red ring around it.")
	burst.enraged_only = true
	burst.kind = BossAttackDefinition.Kind.RADIAL
	burst.hitbox_node = NodePath("BurstHitbox")
	burst.warning_node = NodePath("BurstWarning")
	burst.telegraph_pitch = 0.2
	burst.glow = BossAttackDefinition.Glow.BODY
	burst.tracks_player = false
	burst.element = &"nature"
	var part := BossPartDefinition.new()
	part.id = &"antler"
	part.display_name = "Antlers"
	part.break_health = 220.0
	part.reward = antler
	part.reward_count = 1
	part.break_stagger_time = 2.0
	part.intact_node = NodePath("Visual/Antlers")
	part.broken_node = NodePath("Visual/AntlerStubs")
	var def := BossDefinition.new()
	def.id = &"kurogale"
	def.display_name = "Kurogale, the Thornback Stag"
	def.max_health = 900.0
	def.elements = el
	def.attacks = [sweep, snare, charge, burst] as Array[BossAttackDefinition]
	def.parts = [part] as Array[BossPartDefinition]
	def.victory_rewards = [hide] as Array[ItemDefinition]
	def.lock_offset = Vector3(0, 2.6, -1.8)
	_save(def, "res://data/bosses/kurogale.tres")


func _warning_quad(node_name: String, size: Vector2, pos: Vector3, mat: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var q := QuadMesh.new()
	q.size = size
	q.orientation = PlaneMesh.FACE_Y
	q.material = load(MAT + mat + ".tres")
	mi.mesh = q
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _area(node_name: String, script: String, team: StringName, shape: Shape3D, pos: Vector3) -> Area3D:
	var a := Area3D.new()
	a.name = node_name
	a.set_script(load(script))
	a.set("team", team)
	var c := CollisionShape3D.new()
	c.shape = shape
	c.position = pos
	a.add_child(c)
	return a


func _box_shape(size: Vector3) -> BoxShape3D:
	var b := BoxShape3D.new()
	b.size = size
	return b


func _boss_scenes() -> void:
	DirAccess.make_dir_recursive_absolute("res://scenes/bosses")
	DirAccess.make_dir_recursive_absolute("res://scenes/combat")
	# Ember Talisman projectile.
	var tal := Node3D.new()
	tal.name = "FireTalisman"
	tal.set_script(load("res://scripts/combat/fire_talisman.gd"))
	var sphere := SphereShape3D.new()
	sphere.radius = 0.45
	tal.add_child(_area("Hitbox", "res://scripts/combat/hitbox.gd", &"player", sphere, Vector3.ZERO))
	var flame := MeshInstance3D.new()
	flame.name = "Flame"
	var fq := QuadMesh.new()
	fq.size = Vector2(0.5, 0.7)
	fq.material = load(MAT + "spirit_flame.tres")
	flame.mesh = fq
	flame.set_instance_shader_parameter("flame_color", Color(1.0, 0.45, 0.1))
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tal.add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.15)
	light.light_energy = 1.5
	light.omni_range = 4.0
	tal.add_child(light)
	_pack(tal, "res://scenes/combat/fire_talisman.tscn")

	_root_snare_scene()

	# Kurogale.
	var k := CharacterBody3D.new()
	k.name = "Kurogale"
	k.set_script(load("res://scripts/bosses/kurogale.gd"))
	k.set("definition", load("res://data/bosses/kurogale.tres"))
	var col := CollisionShape3D.new()
	col.name = "Collision"
	col.shape = _box_shape(Vector3(1.8, 3.0, 4.4))
	col.position = Vector3(0, 1.5, 0)  # Bottom at the origin, so the boss stands on the ground.
	k.add_child(col)
	var vis := Node3D.new()
	vis.name = "Visual"
	k.add_child(vis)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = ProceduralMeshes.kurogale_body(load(MAT + "kurogale_body.tres"))
	vis.add_child(body)
	var ant := MeshInstance3D.new()
	ant.name = "Antlers"
	ant.mesh = ProceduralMeshes.kurogale_antlers(load(MAT + "kurogale_antlers.tres"), false)
	vis.add_child(ant)
	var stubs := MeshInstance3D.new()
	stubs.name = "AntlerStubs"
	stubs.mesh = ProceduralMeshes.kurogale_antlers(load(MAT + "kurogale_antlers.tres"), true)
	vis.add_child(stubs)
	var ah := _area("AntlerHurtbox", "res://scripts/combat/hurtbox.gd", &"enemy", _box_shape(Vector3(3.2, 2.4, 2.6)), Vector3(0, 4.0, -2.4))
	ah.set("part_id", &"antler")
	ah.set("health_path", NodePath("../../Health"))
	vis.add_child(ah)
	var front := Node3D.new()
	front.name = "Front"
	k.add_child(front)
	front.add_child(_area("SweepHitbox", "res://scripts/combat/hitbox.gd", &"enemy", _box_shape(Vector3(6.0, 2.6, 4.2)), Vector3(0, 1.3, -3.6)))
	front.add_child(_area("ChargeHitbox", "res://scripts/combat/hitbox.gd", &"enemy", _box_shape(Vector3(2.6, 2.6, 1.8)), Vector3(0, 1.3, -2.7)))
	front.add_child(_warning_quad("SweepWarning", Vector2(6.0, 4.5), Vector3(0, 0.12, -3.8), "attack_warning"))
	front.add_child(_warning_quad("ChargeWarning", Vector2(2.4, 14.0), Vector3(0, 0.12, -8.5), "attack_warning"))
	var health := Node.new()
	health.name = "Health"
	health.set_script(load("res://scripts/combat/health_component.gd"))
	k.add_child(health)
	var bh := _area("BodyHurtbox", "res://scripts/combat/hurtbox.gd", &"enemy", _box_shape(Vector3(2.2, 2.8, 4.6)), Vector3(0, 1.9, 0.2))
	bh.set("health_path", NodePath("../Health"))
	k.add_child(bh)
	var burst := SphereShape3D.new()
	burst.radius = 5.0
	k.add_child(_area("BurstHitbox", "res://scripts/combat/hitbox.gd", &"enemy", burst, Vector3(0, 1.0, 0)))
	k.add_child(_warning_quad("BurstWarning", Vector2(10.0, 10.0), Vector3(0, 0.12, 0), "area_warning"))
	_pack(k, "res://scenes/bosses/kurogale.tscn")


## The talisman projectile scene must exist before the combat data that references it.
func _boss_scenes_prerequisites() -> void:
	if not ResourceLoader.exists("res://scenes/combat/fire_talisman.tscn"):
		_boss_scenes_talisman_only()
	if not ResourceLoader.exists("res://scenes/bosses/root_snare.tscn"):
		_root_snare_scene()


func _boss_scenes_talisman_only() -> void:
	DirAccess.make_dir_recursive_absolute("res://scenes/combat")
	var tal := Node3D.new()
	tal.name = "FireTalisman"
	tal.set_script(load("res://scripts/combat/fire_talisman.gd"))
	var sphere := SphereShape3D.new()
	sphere.radius = 0.45
	tal.add_child(_area("Hitbox", "res://scripts/combat/hitbox.gd", &"player", sphere, Vector3.ZERO))
	_pack(tal, "res://scenes/combat/fire_talisman.tscn")


func _phase6_scenes() -> void:
	DirAccess.make_dir_recursive_absolute("res://scenes/world")
	var glow := _item("glowcap", "Glowcap", "A mushroom that drinks moonlight. Alchemists prize its spores.",
			Color(0.2, 0.95, 0.8), 0)
	var shard := _item("ruin_shard", "Ruin Shard", "A rune-cut stone from the drowned shrine. It hums faintly.",
			Color(0.7, 0.6, 0.9), 1)
	for spec in [["glowcap", glow], ["ruin_shard", shard]]:
		var a := Area3D.new()
		a.name = "Pickup"
		a.set_script(load("res://scripts/world/pickup.gd"))
		a.set("item", spec[1])
		var sphere := SphereShape3D.new()
		sphere.radius = 1.0
		var col := CollisionShape3D.new()
		col.shape = sphere
		col.position.y = 0.6
		a.add_child(col)
		var vis := Node3D.new()
		vis.name = "Visual"
		a.add_child(vis)
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		var rng := RandomNumberGenerator.new()
		rng.seed = 600
		if spec[0] == "glowcap":
			mi.mesh = ProceduralMeshes.mushroom_cluster(rng, Color(0.25, 1.0, 0.85), load(MAT + "glow_fungus.tres"))
			mi.scale = Vector3.ONE * 1.4
		else:
			var bm := BoxMesh.new()
			bm.size = Vector3(0.35, 0.5, 0.25)
			bm.material = load(MAT + "gate_stone.tres")
			mi.mesh = bm
			mi.rotation_degrees = Vector3(15, 0, 20)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		vis.add_child(mi)
		# Soft sparkle so pickups read in the dark from a distance.
		var mote := MeshInstance3D.new()
		mote.name = "Mote"
		var q := QuadMesh.new()
		q.size = Vector2(0.9, 0.9)
		q.material = load(MAT + "spirit_flame.tres")
		mote.mesh = q
		mote.position.y = 0.6
		mote.set_instance_shader_parameter("flame_color", (spec[1] as ItemDefinition).color * 0.6)
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		vis.add_child(mote)
		_pack(a, "res://scenes/world/pickup_%s.tscn" % spec[0])

	var ls := Area3D.new()
	ls.name = "LoreStone"
	ls.set_script(load("res://scripts/world/lore_stone.gd"))
	var lcol := CollisionShape3D.new()
	var ls_shape := SphereShape3D.new()
	ls_shape.radius = 3.5
	lcol.shape = ls_shape
	lcol.position.y = 1.0
	ls.add_child(lcol)
	var tablet := MeshInstance3D.new()
	tablet.name = "Tablet"
	var tb := BoxMesh.new()
	tb.size = Vector3(1.1, 1.7, 0.28)
	tb.material = load(MAT + "climb_stone.tres")
	tablet.mesh = tb
	tablet.position.y = 0.75
	tablet.rotation_degrees = Vector3(-6, 20, 3)
	ls.add_child(tablet)
	_pack(ls, "res://scenes/world/lore_stone.tscn")


func _gear(id: String, name: String, desc: String, slot: GearDefinition.Slot, color: Color, stats: Dictionary) -> GearDefinition:
	var g := GearDefinition.new()
	g.id = StringName(id)
	g.display_name = name
	g.description = desc
	g.slot = slot
	g.color = color
	for k: String in stats:
		g.set(k, stats[k])
	return _save(g, "res://data/gear/%s.tres" % id)


func _recipe(id: String, result: GearDefinition, inputs: Array[ItemDefinition], counts: Array) -> RecipeDefinition:
	var r := RecipeDefinition.new()
	r.id = StringName(id)
	r.result = result
	r.inputs = inputs
	r.counts = PackedInt32Array(counts)
	return _save(r, "res://data/crafting/recipe_%s.tres" % id)


func _crafting_data() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/gear")
	DirAccess.make_dir_recursive_absolute("res://data/crafting")
	var antler: ItemDefinition = load("res://data/items/thornback_antler.tres")
	var hide: ItemDefinition = load("res://data/items/kurogale_hide.tres")
	var glow: ItemDefinition = load("res://data/items/glowcap.tres")
	var shard: ItemDefinition = load("res://data/items/ruin_shard.tres")
	var blades := _gear("thornfang_blades", "Thornfang Blades",
			"Twin blades edged with Kurogale's antler. They bite deeper.", GearDefinition.Slot.WEAPON,
			Color(0.55, 0.95, 0.45), {"blade_damage_multiplier": 1.25})
	var garb := _gear("barkhide_garb", "Barkhide Garb",
			"Ninja garb lined with the Thornback's bark-hide, stitched with glowcap thread.", GearDefinition.Slot.ARMOR,
			Color(0.65, 0.5, 0.32), {"max_health_bonus": 25.0, "damage_reduction": 0.15})
	var charm := _gear("ember_charm", "Ember Charm",
			"A rune shard that keeps a glowcap's light burning. Talismans ignite faster and hotter.",
			GearDefinition.Slot.CHARM, Color(1.0, 0.55, 0.2),
			{"skill_cooldown_reduction": 1.5, "skill_damage_multiplier": 1.3})
	var catalog := CraftingCatalog.new()
	catalog.recipes = [
		_recipe("thornfang_blades", blades, [antler, shard] as Array[ItemDefinition], [1, 1]),
		_recipe("barkhide_garb", garb, [hide, glow] as Array[ItemDefinition], [1, 2]),
		_recipe("ember_charm", charm, [glow, shard] as Array[ItemDefinition], [3, 1]),
	] as Array[RecipeDefinition]
	catalog.items = [antler, hide, glow, shard] as Array[ItemDefinition]
	_save(catalog, "res://data/crafting/catalog.tres")


func _root_snare_scene() -> void:
	DirAccess.make_dir_recursive_absolute("res://scenes/bosses")
	# Root snare hazard.
	var sn := Node3D.new()
	sn.name = "RootSnare"
	sn.set_script(load("res://scripts/bosses/root_snare.gd"))
	sn.add_child(_warning_quad("Ring", Vector2(3.4, 3.4), Vector3(0, 0.07, 0), "snare_warning"))
	var roots := Node3D.new()
	roots.name = "Roots"
	var rm := MeshInstance3D.new()
	rm.mesh = ProceduralMeshes.snare_roots(load(MAT + "bark_vertex.tres"))
	roots.add_child(rm)
	sn.add_child(roots)
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.6
	cyl.height = 2.0
	sn.add_child(_area("Hitbox", "res://scripts/combat/hitbox.gd", &"enemy", cyl, Vector3(0, 1, 0)))
	_pack(sn, "res://scenes/bosses/root_snare.tscn")


# ================================================================ Phase 8: Emberwild

func _emberwild() -> void:
	_emberwild_materials()
	_emberwild_data()
	_emberwild_scenes()
	_emberwild_level()
	_main_scene("res://scenes/biomes/emberwild.tscn", "res://data/hunts/ashen_oni_tortoise.tres",
			"res://scenes/main/expedition_emberwild.tscn")
	_emberwild_unlock()


func _emberwild_materials() -> void:
	var detail: Resource = load(MAT + "noise_detail.tres")
	_save(_shader_mat("lava", {"flow_noise": detail}), MAT + "lava.tres")
	_save(_shader_mat("lava", {"flow_noise": detail, "falling": true, "glow": 2.6}), MAT + "lava_fall.tres")
	_save(_shader_mat("basalt", {"detail_noise": detail}), MAT + "basalt.tres")
	_save(_shader_mat("basalt", {"detail_noise": detail, "climb_marks": 1.0}), MAT + "basalt_climb.tres")
	_save(_shader_mat("terrain", {"detail_noise": detail, "macro_noise": load(MAT + "noise_macro.tres"),
			"moss_dark": Color(0.07, 0.06, 0.055), "moss_light": Color(0.16, 0.13, 0.11), "mud": Color(0.12, 0.08, 0.06),
			"rock": Color(0.14, 0.12, 0.12), "rock_dark": Color(0.04, 0.035, 0.035)}), MAT + "terrain_ash.tres")
	_save(_shader_mat("foliage", {"wind_strength": 0.08, "translucency": 0.15, "tint": Color(1.1, 0.6, 0.35),
			"brightness": 1.6}), MAT + "foliage_scorched.tres")
	_save(_shader_mat("foliage", {"wind_strength": 0.04, "translucency": 0.1, "tint": Color(0.9, 0.45, 0.3),
			"brightness": 1.5}), MAT + "leaf_scorched.tres")
	_save(_shader_mat("sky_gloom", {"cloud_noise": load(MAT + "noise_clouds.tres"), "zenith": Color(0.06, 0.03, 0.03),
			"horizon": Color(0.32, 0.12, 0.06), "glow_tint": Color(0.9, 0.3, 0.08), "flash_color": Color(1.0, 0.4, 0.15),
			"moon_dir": Vector3(-0.3, 0.15, -0.9)}), MAT + "sky_ember.tres")
	_save(_shader_mat("mist_card", {"mist_noise": load(MAT + "noise_mist.tres"), "color": Color(0.25, 0.2, 0.18),
			"opacity": 0.28}), MAT + "mist_ash.tres")
	_save(_shader_mat("light_shaft", {"color": Color(0.7, 0.3, 0.12), "strength": 0.03}), MAT + "shaft_ember.tres")
	_save(_shader_mat("area_warning", {"color": Color(1.0, 0.35, 0.05)}), MAT + "vent_glow.tres")
	_save(_shader_mat("area_warning", {"color": Color(1.0, 0.5, 0.1)}), MAT + "heat_shimmer.tres")
	_save(_shader_mat("area_warning", {"color": Color(1.0, 0.55, 0.08)}), MAT + "lava_warning.tres")
	_save(_shader_mat("creature", {"body_color": Color(0.22, 0.19, 0.17), "glow_color": Color(1.0, 0.6, 0.1),
			"glow_energy": 4.0, "spine_idle": Color(0.55, 0.16, 0.05), "spine_color": Color(1.0, 0.35, 0.05),
			"spine_strength": 2.5}), MAT + "oni_body.tres")
	_save(_shader_mat("creature", {"body_color": Color(0.3, 0.27, 0.24), "spine_idle": Color(0.35, 0.3, 0.26),
			"spine_color": Color(1.0, 0.5, 0.1), "spine_strength": 0.8}), MAT + "oni_horns.tres")


func _emberwild_data() -> void:
	# World configs.
	var terrain := TerrainConfig.new()
	terrain.seed = 4040
	terrain.hill_height = 7.0
	terrain.valley_wall_height = 20.0
	terrain.stream_z = -1000.0  # No stream in Emberwild.
	terrain.stream_depth = 0.0
	terrain.gorge_depth = -4.0  # Lava river (surface at -1.6); LavaZone handles falls.
	_save(terrain, "res://data/biomes/emberwild_terrain.tres")
	var flora := FloraConfig.new()
	flora.seed = 5150
	flora.grass_count = 2500
	flora.fern_count = 500
	flora.broadleaf_count = 120
	flora.mushroom_count = 380
	flora.rock_count = 900
	flora.jungle_tree_count = 25
	flora.dead_tree_count = 85
	flora.log_count = 18
	flora.pillar_count = 10
	flora.mushroom_glows = [Color(1.0, 0.45, 0.1), Color(1.0, 0.2, 0.05), Color(1.0, 0.75, 0.2)] as Array[Color]
	_save(flora, "res://data/biomes/emberwild_flora.tres")
	var fauna := FaunaConfig.new()
	fauna.seed = 808
	fauna.bat_flocks = [Vector3(0, 12, -60), Vector3(-28, 16, -15), Vector3(26, 15, -35), Vector3(15, 18, -100)] as Array[Vector3]
	fauna.frog_count = 0
	fauna.lurker_count = 12
	fauna.lurker_glow = Color(1.0, 0.45, 0.05)
	fauna.firefly_swarms = 20
	fauna.firefly_color = Color(1.0, 0.45, 0.1)  # Rising embers.
	_save(fauna, "res://data/biomes/emberwild_fauna.tres")
	# Items.
	var crystal := _item("ember_crystal", "Ember Crystal", "A shard of cooled magma that never quite stops glowing.",
			Color(1.0, 0.45, 0.15), 0)
	var horn := _item("oni_horn", "Oni Horn", "A horn of the Ashen Oni-Tortoise, heavy as an anvil and still hot.",
			Color(0.85, 0.55, 0.35), 1)
	var plate := _item("ashen_shell_plate", "Ashen Shell Plate", "A slab of the Oni-Tortoise's volcanic shell.",
			Color(0.35, 0.3, 0.28), 0)
	# Boss.
	var el := ElementProfile.new()
	el.affinity = &"fire"
	el.multipliers = {&"water": 1.5, &"fire": 0.25, &"nature": 0.75}
	var slam := _boss_attack("shell_slam", "Shell Slam", 1.1, 0.35, 1.2, 30.0, 10.0, 0.0, 6.0, 3.0, 3.0,
			"It rears onto its hind legs: back out of the red zone in front, then strike its lowered horns.")
	slam.kind = BossAttackDefinition.Kind.FRONT
	slam.hitbox_node = NodePath("Front/SlamHitbox")
	slam.warning_node = NodePath("Front/SlamWarning")
	slam.telegraph_pitch = 0.35
	slam.glow = BossAttackDefinition.Glow.BODY
	slam.weakened_by_part = &"horns"
	slam.element = &"fire"
	var burst := _boss_attack("lava_burst", "Lava Burst", 1.3, 0.5, 1.0, 22.0, 6.0, 3.0, 26.0, 2.0, 6.0,
			"Glowing orange circles open under you: step out before the magma erupts.")
	burst.kind = BossAttackDefinition.Kind.ERUPTIONS
	burst.eruption_scene = load("res://scenes/bosses/lava_burst.tscn") if ResourceLoader.exists("res://scenes/bosses/lava_burst.tscn") else null
	burst.eruption_offsets = PackedVector3Array([Vector3.ZERO, Vector3(3.0, 0, 0.8), Vector3(-2.8, 0, 1.2), Vector3(0.6, 0, -3.0)])
	burst.telegraph_pitch = 0.15
	burst.glow = BossAttackDefinition.Glow.BODY
	burst.element = &"fire"
	var spin := _boss_attack("shell_spin", "Shell Spin", 1.0, 1.3, 1.5, 26.0, 12.0, 6.0, 26.0, 2.0, 6.0,
			"It withdraws and spins at you, curving slightly: roll sideways late; it stuns itself on pillars.")
	spin.kind = BossAttackDefinition.Kind.DASH
	spin.hitbox_node = NodePath("Front/SpinHitbox")
	spin.warning_node = NodePath("Front/SpinWarning")
	spin.move_speed = 11.0
	spin.dash_homing = 1.2
	spin.stuns_on_wall = true
	spin.stun_time = 3.0
	spin.telegraph_pitch = -0.1
	spin.telegraph_wobble = 0.08
	spin.element = &"fire"
	var field := _boss_attack("ember_field", "Ember Field", 1.2, 0.4, 1.0, 24.0, 9.0, 0.0, 6.5, 2.0, 7.0,
			"Enraged: the ground around it glows; get out of the ring.")
	field.kind = BossAttackDefinition.Kind.RADIAL
	field.enraged_only = true
	field.hitbox_node = NodePath("BurstHitbox")
	field.warning_node = NodePath("BurstWarning")
	field.telegraph_pitch = 0.2
	field.glow = BossAttackDefinition.Glow.BODY
	field.tracks_player = false
	field.element = &"fire"
	var part := BossPartDefinition.new()
	part.id = &"horns"
	part.display_name = "Horns"
	part.break_health = 260.0
	part.reward = horn
	part.reward_count = 1
	part.break_stagger_time = 2.2
	part.intact_node = NodePath("Visual/Horns")
	part.broken_node = NodePath("Visual/HornStubs")
	var def := BossDefinition.new()
	def.id = &"ashen_oni_tortoise"
	def.display_name = "Ashen Oni-Tortoise"
	def.max_health = 1100.0
	def.poise = 150.0
	def.stagger_time = 1.6
	def.elements = el
	def.attacks = [slam, burst, spin, field] as Array[BossAttackDefinition]
	def.parts = [part] as Array[BossPartDefinition]
	def.victory_rewards = [plate] as Array[ItemDefinition]
	def.walk_speed = 2.4
	def.turn_sharpness = 3.0
	def.stalk_distance = 5.5
	def.attack_interval = 1.4
	def.head_down_pitch = -0.35
	def.lock_offset = Vector3(0, 1.8, -2.6)
	_save(def, "res://data/bosses/ashen_oni_tortoise.tres")
	# Hunt (replaces the Phase 3 stub).
	var h := HuntDefinition.new()
	h.id = &"ashen_oni_tortoise"
	h.beast_name = "Ashen Oni-Tortoise"
	h.element = "Fire"
	h.weakness = "Water"
	h.signature = "Shell slam, lava burst"
	h.description = "A horned tortoise of living basalt that sleeps in the caldera. Fire only feeds it."
	h.config = load("res://data/expedition/default_expedition.tres")
	_save(h, "res://data/hunts/ashen_oni_tortoise.tres")
	# Crafting: Mist Charm (water talisman) + two Emberwild recipes.
	var glow: ItemDefinition = load("res://data/items/glowcap.tres")
	var shard: ItemDefinition = load("res://data/items/ruin_shard.tres")
	var mist := _gear("mist_charm", "Mist Charm",
			"A rune shard wrapped in damp glowcap moss. Talismans burst into cold mist instead of flame.",
			GearDefinition.Slot.CHARM, Color(0.4, 0.75, 1.0), {"skill_element": &"water", "skill_cooldown_reduction": 0.5})
	var oni_blades := _gear("oni_fang_blades", "Oni Fang Blades",
			"Blades ground from an oni horn. They stay hot enough to sear.", GearDefinition.Slot.WEAPON,
			Color(1.0, 0.45, 0.15), {"blade_damage_multiplier": 1.4, "blade_element": &"fire"})
	var ashen := _gear("ashen_plate", "Ashen Plate",
			"Armor plates cut from the Oni-Tortoise's shell. Heavy, and nearly fireproof.", GearDefinition.Slot.ARMOR,
			Color(0.45, 0.4, 0.38), {"max_health_bonus": 40.0, "damage_reduction": 0.25})
	var catalog: CraftingCatalog = load("res://data/crafting/catalog.tres")
	catalog.recipes.append(_recipe("mist_charm", mist, [shard, glow] as Array[ItemDefinition], [2, 2]))
	catalog.recipes.append(_recipe("oni_fang_blades", oni_blades, [horn, crystal] as Array[ItemDefinition], [1, 2]))
	catalog.recipes.append(_recipe("ashen_plate", ashen, [plate, crystal] as Array[ItemDefinition], [1, 2]))
	catalog.items.append_array([crystal, horn, plate])
	_save(catalog, "res://data/crafting/catalog.tres")


func _emberwild_scenes() -> void:
	# Lava burst eruption (RootSnare behaviour, molten visuals).
	var lb := Node3D.new()
	lb.name = "LavaBurst"
	lb.set_script(load("res://scripts/bosses/root_snare.gd"))
	lb.add_child(_warning_quad("Ring", Vector2(3.4, 3.4), Vector3(0, 0.07, 0), "lava_warning"))
	var roots := Node3D.new()
	roots.name = "Roots"
	var rm := MeshInstance3D.new()
	rm.mesh = ProceduralMeshes.magma_spikes(load(MAT + "glow_fungus.tres"))
	roots.add_child(rm)
	lb.add_child(roots)
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.6
	cyl.height = 2.2
	lb.add_child(_area("Hitbox", "res://scripts/combat/hitbox.gd", &"enemy", cyl, Vector3(0, 1, 0)))
	_pack(lb, "res://scenes/bosses/lava_burst.tscn")
	# Re-save the boss data now that the eruption scene exists.
	var def: BossDefinition = load("res://data/bosses/ashen_oni_tortoise.tres")
	def.get_attack(&"lava_burst").eruption_scene = load("res://scenes/bosses/lava_burst.tscn")
	_save(def, "res://data/bosses/ashen_oni_tortoise.tres")

	# Fire vent.
	var v := Node3D.new()
	v.name = "FireVent"
	v.set_script(load("res://scripts/world/hazards/fire_vent.gd"))
	var cone := MeshInstance3D.new()
	cone.name = "Cone"
	cone.mesh = ProceduralMeshes.vent_cone(load(MAT + "basalt.tres"))
	v.add_child(cone)
	v.add_child(_warning_quad("Glow", Vector2(3.4, 3.4), Vector3(0, 0.6, 0), "vent_glow"))
	var column := Node3D.new()
	column.name = "Column"
	var fq := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.2, 6.0)
	q.center_offset = Vector3(0, 3.0, 0)
	q.material = load(MAT + "spirit_flame.tres")
	fq.mesh = q
	fq.set_instance_shader_parameter("flame_color", Color(1.0, 0.45, 0.08))
	fq.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	column.add_child(fq)
	var fl := OmniLight3D.new()
	fl.light_color = Color(1.0, 0.45, 0.1)
	fl.light_energy = 3.0
	fl.omni_range = 7.0
	fl.position.y = 2.0
	column.add_child(fl)
	v.add_child(column)
	var vcyl := CylinderShape3D.new()
	vcyl.radius = 1.6
	vcyl.height = 5.0
	v.add_child(_area("Hitbox", "res://scripts/combat/hitbox.gd", &"enemy", vcyl, Vector3(0, 2.5, 0)))
	_pack(v, "res://scenes/world/fire_vent.tscn")

	# Sinking stepping stone.
	var s := AnimatableBody3D.new()
	s.name = "SinkingStone"
	s.set_script(load("res://scripts/world/hazards/sinking_stone.gd"))
	s.collision_layer = 1
	var sc := CollisionShape3D.new()
	sc.shape = _box_shape(Vector3(3.2, 1.0, 3.2))
	sc.position.y = -0.5
	s.add_child(sc)
	var smesh := MeshInstance3D.new()
	smesh.name = "Mesh"
	var sb := BoxMesh.new()
	sb.size = Vector3(3.2, 1.0, 3.2)
	sb.material = load(MAT + "basalt.tres")
	smesh.mesh = sb
	smesh.position.y = -0.5
	s.add_child(smesh)
	_pack(s, "res://scenes/world/sinking_stone.tscn")

	# Crumbling basalt platform.
	var c := AnimatableBody3D.new()
	c.name = "CrumblePlatform"
	c.set_script(load("res://scripts/world/hazards/crumble_platform.gd"))
	c.collision_layer = 1
	var cc := CollisionShape3D.new()
	cc.name = "Collision"
	cc.shape = _box_shape(Vector3(2.6, 0.8, 2.6))
	cc.position.y = -0.4
	c.add_child(cc)
	var cm := MeshInstance3D.new()
	cm.name = "Mesh"
	var cb := BoxMesh.new()
	cb.size = Vector3(2.6, 0.8, 2.6)
	cb.material = load(MAT + "basalt.tres")
	cm.mesh = cb
	cm.position.y = -0.4
	cm.set_instance_shader_parameter("rune_glow", 0.35)  # Brittle: veins glow faintly.
	c.add_child(cm)
	var trig := Area3D.new()
	trig.name = "Trigger"
	var tc := CollisionShape3D.new()
	tc.shape = _box_shape(Vector3(2.4, 0.6, 2.4))
	tc.position.y = 0.3
	trig.add_child(tc)
	c.add_child(trig)
	_pack(c, "res://scenes/world/crumble_platform.tscn")

	# Ember Crystal pickup.
	var a := Area3D.new()
	a.name = "Pickup"
	a.set_script(load("res://scripts/world/pickup.gd"))
	a.set("item", load("res://data/items/ember_crystal.tres"))
	var ps := SphereShape3D.new()
	ps.radius = 1.0
	var pcol := CollisionShape3D.new()
	pcol.shape = ps
	pcol.position.y = 0.6
	a.add_child(pcol)
	var vis := Node3D.new()
	vis.name = "Visual"
	a.add_child(vis)
	var gem := MeshInstance3D.new()
	var gm := PrismMesh.new()
	gm.size = Vector3(0.35, 0.6, 0.35)
	gm.material = load(MAT + "lava.tres")
	gem.mesh = gm
	vis.add_child(gem)
	var mote := MeshInstance3D.new()
	var mq := QuadMesh.new()
	mq.size = Vector2(0.9, 0.9)
	mq.material = load(MAT + "spirit_flame.tres")
	mote.mesh = mq
	mote.position.y = 0.6
	mote.set_instance_shader_parameter("flame_color", Color(1.0, 0.45, 0.1) * 0.6)
	vis.add_child(mote)
	_pack(a, "res://scenes/world/pickup_ember_crystal.tscn")

	# Ashen Oni-Tortoise.
	var k := CharacterBody3D.new()
	k.name = "AshenOniTortoise"
	k.set_script(load("res://scripts/bosses/boss_controller.gd"))
	k.set("definition", load("res://data/bosses/ashen_oni_tortoise.tres"))
	var col := CollisionShape3D.new()
	col.name = "Collision"
	col.shape = _box_shape(Vector3(3.4, 2.4, 4.4))
	col.position = Vector3(0, 1.2, 0.2)
	k.add_child(col)
	var vis2 := Node3D.new()
	vis2.name = "Visual"
	k.add_child(vis2)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = ProceduralMeshes.oni_tortoise_body(load(MAT + "oni_body.tres"))
	vis2.add_child(body)
	var horns := MeshInstance3D.new()
	horns.name = "Horns"
	horns.mesh = ProceduralMeshes.oni_horns(load(MAT + "oni_horns.tres"), false)
	vis2.add_child(horns)
	var stubs := MeshInstance3D.new()
	stubs.name = "HornStubs"
	stubs.mesh = ProceduralMeshes.oni_horns(load(MAT + "oni_horns.tres"), true)
	vis2.add_child(stubs)
	var hh := _area("HornHurtbox", "res://scripts/combat/hurtbox.gd", &"enemy", _box_shape(Vector3(2.6, 1.8, 2.0)), Vector3(0, 2.0, -3.0))
	hh.set("part_id", &"horns")
	hh.set("health_path", NodePath("../../Health"))
	vis2.add_child(hh)
	var front := Node3D.new()
	front.name = "Front"
	k.add_child(front)
	front.add_child(_area("SlamHitbox", "res://scripts/combat/hitbox.gd", &"enemy", _box_shape(Vector3(6.0, 2.6, 5.0)), Vector3(0, 1.2, -4.2)))
	front.add_child(_warning_quad("SlamWarning", Vector2(6.5, 5.5), Vector3(0, 0.12, -4.3), "area_warning"))
	var spin_shape := SphereShape3D.new()
	spin_shape.radius = 2.8
	front.add_child(_area("SpinHitbox", "res://scripts/combat/hitbox.gd", &"enemy", spin_shape, Vector3(0, 1.2, 0)))
	front.add_child(_warning_quad("SpinWarning", Vector2(3.2, 14.0), Vector3(0, 0.12, -8.5), "attack_warning"))
	var hcomp := Node.new()
	hcomp.name = "Health"
	hcomp.set_script(load("res://scripts/combat/health_component.gd"))
	k.add_child(hcomp)
	var bh := _area("BodyHurtbox", "res://scripts/combat/hurtbox.gd", &"enemy", _box_shape(Vector3(3.6, 2.6, 4.6)), Vector3(0, 1.4, 0.2))
	bh.set("health_path", NodePath("../Health"))
	k.add_child(bh)
	var field := SphereShape3D.new()
	field.radius = 6.5
	k.add_child(_area("BurstHitbox", "res://scripts/combat/hitbox.gd", &"enemy", field, Vector3(0, 1.0, 0)))
	k.add_child(_warning_quad("BurstWarning", Vector2(13.0, 13.0), Vector3(0, 0.12, 0), "area_warning"))
	_pack(k, "res://scenes/bosses/ashen_oni_tortoise.tscn")


func _basalt(node_name: String, size: Vector3, pos: Vector3, climbable: bool = false) -> CSGBox3D:
	var b := _box(node_name, size, pos, "basalt_climb" if climbable else "basalt")
	if climbable:
		b.collision_layer = 1 | 4
	return b


func _emberwild_level() -> void:
	_root = Node3D.new()
	_root.name = "Emberwild"
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = load(MAT + "sky_ember.tres")
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.29, 0.23, 0.21)
	env.ambient_light_energy = 3.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.45
	env.fog_enabled = true
	env.fog_light_color = Color(0.2, 0.14, 0.11)
	env.fog_density = 0.018
	env.fog_sky_affect = 0.35
	env.fog_height = 0.0
	env.fog_height_density = 0.05
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 0.8
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.15
	env.adjustment_saturation = 0.82
	env_node.environment = env
	_root.add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.name = "Moonlight"  # Atmosphere/tests look for this name; here it is a low ember-red sun.
	sun.rotation_degrees = Vector3(-28, -40, 0)
	sun.light_color = Color(1.0, 0.7, 0.55)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.7
	sun.directional_shadow_max_distance = 55.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_root.add_child(sun)

	var terrain := Node3D.new()
	terrain.name = "Terrain"
	terrain.set_script(load("res://scripts/world/biome_terrain.gd"))
	terrain.set("material", load(MAT + "terrain_ash.tres"))
	terrain.set("config", load("res://data/biomes/emberwild_terrain.tres"))
	_root.add_child(terrain)
	var flora := Node3D.new()
	flora.name = "Flora"
	flora.set_script(load("res://scripts/world/flora_scatter.gd"))
	flora.set("terrain_path", NodePath("../Terrain"))
	flora.set("grass_material", load(MAT + "foliage_scorched.tres"))
	flora.set("leaf_material", load(MAT + "leaf_scorched.tres"))
	flora.set("vine_material", load(MAT + "foliage_scorched.tres"))
	flora.set("bark_material", load(MAT + "bark_vertex.tres"))
	flora.set("fungus_material", load(MAT + "glow_fungus.tres"))
	flora.set("rock_material", load(MAT + "rock_vertex.tres"))
	flora.set("stone_material", load(MAT + "basalt.tres"))
	flora.set("config", load("res://data/biomes/emberwild_flora.tres"))
	_root.add_child(flora)
	var fauna := Node3D.new()
	fauna.name = "Fauna"
	fauna.set_script(load("res://scripts/world/fauna/fauna_spawner.gd"))
	fauna.set("terrain_path", NodePath("../Terrain"))
	fauna.set("config", load("res://data/biomes/emberwild_fauna.tres"))
	fauna.set("bat_material", load(MAT + "bat.tres"))
	fauna.set("frog_material", load(MAT + "frog.tres"))
	fauna.set("eye_material", load(MAT + "lurker_eyes.tres"))
	fauna.set("firefly_material", load(MAT + "firefly.tres"))
	_root.add_child(fauna)
	var atmos := Node3D.new()
	atmos.name = "Atmosphere"
	atmos.set_script(load("res://scripts/world/biome_atmosphere.gd"))
	atmos.set("mood", load("res://data/mood/emberwild.tres"))  # Art pass stage 3 (tools/generate_moods.gd).
	atmos.set("terrain_path", NodePath("../Terrain"))
	atmos.set("sun_path", NodePath("../Moonlight"))
	atmos.set("environment_path", NodePath("../WorldEnvironment"))
	atmos.set("mist_material", load(MAT + "mist_ash.tres"))
	atmos.set("shaft_material", load(MAT + "shaft_ember.tres"))
	atmos.set("waterfall_material", load(MAT + "lava_fall.tres"))
	atmos.set("water_material", load(MAT + "lava.tres"))
	atmos.set("river_height", -1.6)
	atmos.set("lightning_interval", Vector2(14.0, 30.0))
	atmos.set("lightning_sky_flash", 0.4)
	atmos.set("lightning_sun_boost", 0.6)
	_root.add_child(atmos)
	var geo := Node3D.new()
	geo.name = "RouteGeometry"
	_root.add_child(geo)
	var spawn := Marker3D.new()
	spawn.name = "SpawnPoint"
	spawn.position = Vector3(0, 0.1, 0)
	_root.add_child(spawn)
	var cps := Node3D.new()
	cps.name = "Checkpoints"
	_root.add_child(cps)
	_checkpoint("CheckpointSpawn", Vector3(-4.5, 0, 1))
	_checkpoint("CheckpointLava", Vector3(-4.5, 0, -45))
	_checkpoint("CheckpointGate", Vector3(-4.5, 0, -78))

	var hazards := Node3D.new()
	hazards.name = "Hazards"
	_root.add_child(hazards)
	# 1) Vent field: basalt walls funnel the route past four vents erupting in a wave.
	_basalt("VentWallL", Vector3(1.5, 3.5, 20), Vector3(-4.2, 1.5, -17))
	_basalt("VentWallR", Vector3(1.5, 3.5, 20), Vector3(4.2, 1.5, -17))
	var vent_scene: PackedScene = load("res://scenes/world/fire_vent.tscn")
	var cycle := 2.6 + 1.2 + 0.9
	for i in 4:
		var vent: Node3D = vent_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		vent.name = "FireVent%d" % i
		vent.position = Vector3(0, 0, -10.0 - 5.0 * i)
		vent.set("phase_offset", fmod(cycle - 0.7 * i, cycle))
		hazards.add_child(vent)
	# 2) Heat zone across most of the route, with a cool lane along the right edge.
	var heat := Area3D.new()
	heat.name = "HeatZone"
	heat.set_script(load("res://scripts/world/hazards/heat_zone.gd"))
	var hc := CollisionShape3D.new()
	hc.shape = _box_shape(Vector3(8.5, 3.0, 8.0))
	heat.add_child(hc)
	heat.position = Vector3(-1.2, 1.0, -33)
	var shimmer := _warning_quad("Shimmer", Vector2(8.5, 8.0), Vector3(0, -0.92, 0), "heat_shimmer")
	shimmer.set_instance_shader_parameter("intensity", 0.12)
	heat.add_child(shimmer)
	hazards.add_child(heat)
	for i in 4:
		_box("CoolLaneMarker%d" % i, Vector3(0.6, 0.5, 0.6), Vector3(3.4, 0.25, -29.5 - 2.3 * i), "basalt")
	# 3) Lava river: sinking stones (all on one rhythm, a slight ripple), lava volume.
	var stone_scene: PackedScene = load("res://scenes/world/sinking_stone.tscn")
	var zs := [-53.5, -58.0, -62.5, -67.0]
	for i in zs.size():
		var st: Node3D = stone_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		st.name = "SinkingStone%d" % i
		st.position = Vector3(0, 0, zs[i])
		st.set("up_time", 4.0)
		st.set("phase_offset", -0.25 * i + 100.0)
		hazards.add_child(st)
	var lava := Area3D.new()
	lava.name = "LavaRiver"
	lava.set_script(load("res://scripts/world/hazards/lava_zone.gd"))
	var lcol := CollisionShape3D.new()
	lcol.shape = _box_shape(Vector3(160, 6, 20.6))
	lava.add_child(lcol)
	lava.position = Vector3(0, -4.0, -60.5)
	hazards.add_child(lava)
	# Optional shortcut on the right: crumbling basalt to an ember crystal on a pillar.
	var crumble_scene: PackedScene = load("res://scenes/world/crumble_platform.tscn")
	for i in 3:
		var cp: Node3D = crumble_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		cp.name = "Crumble%d" % i
		cp.position = Vector3(8.0, -0.2 + 0.1 * i, -54.5 - 4.6 * i)
		hazards.add_child(cp)
	_basalt("CrystalPillar", Vector3(2.4, 22, 2.4), Vector3(8.0, -10.7, -68.5))
	# Far bank: climbable basalt cliff.
	_basalt("FarBankWall", Vector3(30, 22.3, 3), Vector3(0, -8.85, -72.5), true)

	# Gate + arena (same layout as the Verdant Canopy).
	_box("GatePillarL", Vector3(1.6, 8, 1.6), Vector3(-4.2, 4, -94), "basalt")
	_box("GatePillarR", Vector3(1.6, 8, 1.6), Vector3(4.2, 4, -94), "basalt")
	_box("GateLintel", Vector3(11, 1.4, 2.0), Vector3(0, 8.5, -94), "basalt")
	_box("ArenaWallL", Vector3(40, 8, 1.5), Vector3(-25.0, 2, -94), "basalt")
	_box("ArenaWallR", Vector3(40, 8, 1.5), Vector3(25.0, 2, -94), "basalt")
	var trigger := Area3D.new()
	trigger.name = "BossArenaTrigger"
	trigger.set_script(load("res://scripts/world/boss_arena_trigger.gd"))
	var tcol := CollisionShape3D.new()
	tcol.shape = _box_shape(Vector3(160, 80, 54))
	trigger.add_child(tcol)
	trigger.position = Vector3(0, 10, -123)
	_root.add_child(trigger)
	for i in 10:
		var ang := TAU * float(i) / 10.0 + PI / 10.0
		if absf(wrapf(ang - PI / 2.0, -PI, PI)) < 0.5:
			continue
		var p := Vector3(cos(ang) * 17.0, 0, -120.0 + sin(ang) * 17.0)
		var c := CSGCylinder3D.new()
		c.name = "ArenaPillar%d" % i
		c.radius = 1.0
		c.height = 8.0
		c.sides = 7
		c.position = p + Vector3.UP * 4.0
		c.use_collision = true
		c.collision_mask = 0
		c.material = load(MAT + "basalt.tres")
		geo.add_child(c)
	var marker := Marker3D.new()
	marker.name = "ArenaGateMarker"
	marker.position = Vector3(0, 0, -94)
	_root.add_child(marker)
	_omni("ArenaGlow", Vector3(0, 5, -120), Color(1.0, 0.35, 0.1), 2.5, 24.0)
	_omni("GateGlow", Vector3(0, 4, -91), Color(1.0, 0.3, 0.05), 2.0, 14.0)
	var boss: Node3D = (load("res://scenes/bosses/ashen_oni_tortoise.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	boss.name = "Boss"
	boss.position = Vector3(0, 0.05, -121)
	boss.rotation.y = PI
	_root.add_child(boss)

	# Enemies, gatherables, lore.
	var enemies := Node3D.new()
	enemies.name = "Enemies"
	_root.add_child(enemies)
	for spec in [["ThornlingA", Vector3(-23, 0.2, -20)], ["ThornlingB", Vector3(-26, 0.2, -25)]]:
		var e: Node3D = (load("res://scenes/enemies/thornling.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		e.name = spec[0]
		e.position = spec[1]
		enemies.add_child(e)
	var gather := Node3D.new()
	gather.name = "Gatherables"
	_root.add_child(gather)
	var spots := [
		["ember_crystal", Vector3(4.6, 0, -33), true],        # Cool lane
		["ember_crystal", Vector3(-1.0, 0, -34), true],       # Middle of the heat (risky)
		["ember_crystal", Vector3(8.0, 0.65, -68.5), false],  # Crumble shortcut pillar
		["ember_crystal", Vector3(-24, 0, -22), true],        # Thornling hollow
		["ember_crystal", Vector3(6.0, 0, -83), true],
		["ruin_shard", Vector3(-7.5, 0, -40), true], ["ruin_shard", Vector3(9.5, 0, -12), true],
		["glowcap", Vector3(-27.5, 0, -18.5), true], ["glowcap", Vector3(-8.0, 0, -84), true],
	]
	for i in spots.size():
		var spot: Array = spots[i]
		var pk: Node3D = (load("res://scenes/world/pickup_%s.tscn" % spot[0]) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		pk.name = "%s_%d" % [spot[0], i]
		pk.position = spot[1]
		pk.set("snap_to_ground", spot[2])
		gather.add_child(pk)
	var ls: Node3D = (load("res://scenes/world/lore_stone.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	ls.name = "LoreStone0"
	ls.set("title", "The Ashen Oni")
	ls.set("text", "Its shell drinks fire and breathes it back. Only the rains ever cooled it; the old dojo's mist-charms were made for this. Strike the horns when it bows its head.")
	ls.position = Vector3(6.5, 0, -82)
	gather.add_child(ls)
	_pack(_root, "res://scenes/biomes/emberwild.tscn")


func _emberwild_unlock() -> void:
	var b: BiomeDefinition = load("res://data/biomes/biome_emberwild.tres")
	b.hunts = [load("res://data/hunts/ashen_oni_tortoise.tres")] as Array[HuntDefinition]
	b.unlocked = true
	b.requires_hunt = &"kurogale"
	b.expedition_scene = "res://scenes/main/expedition_emberwild.tscn"
	b.locked_note = "defeat Kurogale to unlock"
	_save(b, "res://data/biomes/biome_emberwild.tres")
	var board: PackedScene = load("res://scenes/ui/hunt_board.tscn")
	var inst := board.instantiate()
	var items: Array[ItemDefinition] = (load("res://data/crafting/catalog.tres") as CraftingCatalog).items
	inst.set("known_items", items)
	_pack(inst, "res://scenes/ui/hunt_board.tscn")


# ================================================================ Phase 9: Moonfen

func _moonfen() -> void:
	_moonfen_materials()
	_moonfen_data()
	_moonfen_scenes()
	_moonfen_level()
	_main_scene("res://scenes/biomes/moonfen.tscn", "res://data/hunts/nami.tres",
			"res://scenes/main/expedition_moonfen.tscn")
	_moonfen_unlock()


func _moonfen_materials() -> void:
	var detail: Resource = load(MAT + "noise_detail.tres")
	var ripples: Resource = load(MAT + "noise_ripples_normal.tres")
	_save(_shader_mat("terrain", {"detail_noise": detail, "macro_noise": load(MAT + "noise_macro.tres"),
			"moss_dark": Color(0.05, 0.05, 0.08), "moss_light": Color(0.12, 0.11, 0.18), "mud": Color(0.1, 0.08, 0.1),
			"rock": Color(0.18, 0.17, 0.22), "rock_dark": Color(0.06, 0.055, 0.08)}), MAT + "terrain_fen.tres")
	_save(_shader_mat("foliage", {"wind_strength": 0.1, "translucency": 0.45, "tint": Color(0.75, 0.6, 1.15),
			"brightness": 1.9}), MAT + "foliage_fen.tres")
	_save(_shader_mat("foliage", {"wind_strength": 0.06, "translucency": 0.4, "tint": Color(0.6, 0.7, 1.1),
			"brightness": 1.8}), MAT + "leaf_fen.tres")
	_save(_shader_mat("sky_gloom", {"cloud_noise": load(MAT + "noise_clouds.tres"), "zenith": Color(0.03, 0.02, 0.07),
			"horizon": Color(0.2, 0.12, 0.32), "glow_tint": Color(0.45, 0.25, 0.8), "flash_color": Color(0.6, 0.5, 1.0),
			"moon_dir": Vector3(0.35, 0.3, -0.88)}), MAT + "sky_moon.tres")
	_save(_shader_mat("mist_card", {"mist_noise": load(MAT + "noise_mist.tres"), "color": Color(0.32, 0.28, 0.45),
			"opacity": 0.34}), MAT + "mist_fen.tres")
	_save(_shader_mat("light_shaft", {"color": Color(0.5, 0.45, 0.9), "strength": 0.035}), MAT + "shaft_moon.tres")
	# Waters: each hazard reads differently at a glance (dark violet bog, brown mud, sickly green poison).
	_save(_shader_mat("water", {"ripple_noise": ripples, "deep": Color(0.025, 0.02, 0.06), "shallow": Color(0.14, 0.1, 0.32),
			"glow": 0.55, "flow_speed": 0.02}), MAT + "bog_water.tres")
	_save(_shader_mat("water", {"ripple_noise": ripples, "deep": Color(0.07, 0.05, 0.035), "shallow": Color(0.16, 0.12, 0.08),
			"glow": 0.02, "flow_speed": 0.004, "alpha": 0.97}), MAT + "mud.tres")
	_save(_shader_mat("water", {"ripple_noise": ripples, "deep": Color(0.08, 0.14, 0.02), "shallow": Color(0.45, 0.7, 0.1),
			"glow": 0.9, "flow_speed": 0.01, "alpha": 0.92}), MAT + "poison.tres")
	_save(_shader_mat("area_warning", {"color": Color(0.6, 1.0, 0.1)}), MAT + "poison_warning.tres")
	_save(_shader_mat("attack_warning", {"color": Color(1.0, 0.25, 0.5)}), MAT + "flood_warning.tres")
	_save(_shader_mat("basalt", {"detail_noise": detail, "rock_light": Color(0.24, 0.2, 0.12),
			"rock_dark": Color(0.08, 0.065, 0.04), "ember": Color(1.0, 0.3, 0.45), "scale": 1.4}), MAT + "reed.tres")
	_save(_shader_mat("creature", {"body_color": Color(0.07, 0.08, 0.14), "glow_color": Color(0.5, 0.9, 1.0),
			"glow_energy": 4.0, "spine_idle": Color(0.25, 0.18, 0.45), "spine_color": Color(0.7, 0.4, 1.0),
			"spine_strength": 3.0}), MAT + "nami_body.tres")
	_save(_shader_mat("creature", {"body_color": Color(0.12, 0.1, 0.16), "glow_color": Color(0.55, 0.95, 1.0),
			"glow_energy": 6.0, "spine_idle": Color(0.2, 0.18, 0.28), "spine_color": Color(0.6, 0.9, 1.0),
			"spine_strength": 1.5}), MAT + "nami_lantern.tres")


func _moonfen_data() -> void:
	var terrain := TerrainConfig.new()
	terrain.seed = 6262
	terrain.hill_height = 3.0  # Flat, sunken swamp.
	terrain.valley_wall_height = 14.0
	terrain.stream_z = -33.0
	terrain.stream_half_width = 2.5
	terrain.stream_depth = 0.7
	terrain.gorge_depth = -4.0  # Deep bog (surface at -0.35); the bog LavaZone handles falls.
	_save(terrain, "res://data/biomes/moonfen_terrain.tres")
	var flora := FloraConfig.new()
	flora.seed = 7373
	flora.grass_count = 3200
	flora.fern_count = 900
	flora.broadleaf_count = 260
	flora.mushroom_count = 520
	flora.rock_count = 420
	flora.jungle_tree_count = 55
	flora.dead_tree_count = 70
	flora.log_count = 30
	flora.pillar_count = 6
	flora.mushroom_glows = [Color(0.6, 0.3, 1.0), Color(0.3, 0.85, 1.0), Color(0.85, 0.4, 1.0)] as Array[Color]
	_save(flora, "res://data/biomes/moonfen_flora.tres")
	var fauna := FaunaConfig.new()
	fauna.seed = 909
	fauna.bat_flocks = [Vector3(-20, 14, -40), Vector3(24, 15, -70)] as Array[Vector3]
	fauna.frog_count = 40
	fauna.lurker_count = 14
	fauna.lurker_glow = Color(0.7, 0.4, 1.0)
	fauna.firefly_swarms = 26
	fauna.firefly_color = Color(0.45, 0.9, 1.0)  # Spirit motes.
	_save(fauna, "res://data/biomes/moonfen_fauna.tres")
	# Items.
	var moss := _item("spirit_moss", "Spirit Moss", "Fen moss that keeps a little moonlight in it after it is picked.",
			Color(0.55, 0.45, 1.0), 0)
	var pearl := _item("lantern_pearl", "Lantern Pearl", "The glowing lure of Nami's brow. It still pulls at the eye.",
			Color(0.6, 0.95, 1.0), 1)
	var scale := _item("nami_scale", "Nami's Scale", "A cold, iridescent scale from the Lantern Serpent.",
			Color(0.3, 0.35, 0.6), 0)
	# Boss: Nami, the Lantern Serpent (water / spirit; weak to lightning).
	var el := ElementProfile.new()
	el.affinity = &"water"
	el.multipliers = {&"lightning": 1.5, &"fire": 0.5, &"water": 0.5}
	var flood := _boss_attack("flood_wave", "Flood Wave", 1.2, 0.45, 1.3, 26.0, 11.0, 0.0, 11.0, 3.0, 4.0,
			"It rears up and the strip in front of it floods pink: step sideways out of the strip, or roll through it late.")
	flood.kind = BossAttackDefinition.Kind.FRONT
	flood.hitbox_node = NodePath("Front/FloodHitbox")
	flood.warning_node = NodePath("Front/FloodWarning")
	flood.telegraph_pitch = 0.4
	flood.glow = BossAttackDefinition.Glow.BODY
	flood.weakened_by_part = &"lantern"
	flood.element = &"water"
	var lure := _boss_attack("lantern_lure", "Lantern Lure", 1.4, 0.5, 1.0, 20.0, 5.0, 3.0, 26.0, 2.0, 6.0,
			"Its lantern flares and violet circles open under you: keep moving and get out before the spirits rise.")
	lure.kind = BossAttackDefinition.Kind.ERUPTIONS
	lure.eruption_offsets = PackedVector3Array([Vector3.ZERO, Vector3(2.8, 0, 1.6), Vector3(-2.8, 0, 1.6), Vector3(0, 0, -3.0)])
	lure.telegraph_pitch = 0.1
	lure.glow = BossAttackDefinition.Glow.PARTS
	lure.element = &"water"
	var dive := _boss_attack("dive_strike", "Dive Strike", 1.0, 1.1, 1.4, 28.0, 12.0, 6.0, 26.0, 2.0, 6.0,
			"It coils back and lunges along the line: roll sideways late; it stuns itself on the stone pillars.")
	dive.kind = BossAttackDefinition.Kind.DASH
	dive.hitbox_node = NodePath("Front/DiveHitbox")
	dive.warning_node = NodePath("Front/DiveWarning")
	dive.move_speed = 13.0
	dive.dash_homing = 0.6
	dive.stuns_on_wall = true
	dive.stun_time = 2.8
	dive.telegraph_pitch = -0.2
	dive.telegraph_wobble = 0.06
	dive.element = &"water"
	var rain := _boss_attack("spirit_rain", "Spirit Rain", 1.2, 0.5, 1.0, 22.0, 8.0, 0.0, 7.0, 2.0, 7.0,
			"Enraged: the ring around it glows; get out before the spirit rain falls.")
	rain.kind = BossAttackDefinition.Kind.RADIAL
	rain.enraged_only = true
	rain.hitbox_node = NodePath("BurstHitbox")
	rain.warning_node = NodePath("BurstWarning")
	rain.telegraph_pitch = 0.25
	rain.glow = BossAttackDefinition.Glow.BODY
	rain.tracks_player = false
	rain.element = &"water"
	var part := BossPartDefinition.new()
	part.id = &"lantern"
	part.display_name = "Lantern"
	part.break_health = 220.0
	part.reward = pearl
	part.reward_count = 1
	part.break_stagger_time = 2.4
	part.intact_node = NodePath("Visual/Lantern")
	part.broken_node = NodePath("Visual/LanternStub")
	var def := BossDefinition.new()
	def.id = &"nami"
	def.display_name = "Nami, the Lantern Serpent"
	def.max_health = 1000.0
	def.poise = 130.0
	def.stagger_time = 1.5
	def.elements = el
	def.attacks = [flood, lure, dive, rain] as Array[BossAttackDefinition]
	def.parts = [part] as Array[BossPartDefinition]
	def.victory_rewards = [scale] as Array[ItemDefinition]
	def.walk_speed = 3.0
	def.turn_sharpness = 3.5
	def.stalk_distance = 5.5
	def.attack_interval = 1.3
	def.head_down_pitch = -0.45
	def.lock_offset = Vector3(0, 2.8, -2.6)
	_save(def, "res://data/bosses/nami.tres")
	var h := HuntDefinition.new()
	h.id = &"nami"
	h.beast_name = "Nami"
	h.epithet = "the Lantern Serpent"
	h.element = "Water / Spirit"
	h.weakness = "Lightning"
	h.signature = "Flood wave, lantern lure"
	h.description = "A fen serpent that lures hunters into the bog with the lantern on its brow. Water barely wets it; storms frighten it."
	h.config = load("res://data/expedition/default_expedition.tres")
	_save(h, "res://data/hunts/nami.tres")
	# Crafting: Storm Charm (lightning talisman, from Emberwild materials) + two Moonfen recipes.
	var crystal: ItemDefinition = load("res://data/items/ember_crystal.tres")
	var shard: ItemDefinition = load("res://data/items/ruin_shard.tres")
	var storm := _gear("storm_charm", "Storm Charm",
			"Three ember crystals strung around a rune shard; they crackle when they touch. Talismans strike as lightning.",
			GearDefinition.Slot.CHARM, Color(0.75, 0.8, 1.0), {"skill_element": &"lightning", "skill_cooldown_reduction": 0.5})
	var moonfang := _gear("moonfang_blades", "Moonfang Blades",
			"Blades quenched in the Lantern Pearl's light. They leave a cold, wet shimmer — the Oni-Tortoise hates them.",
			GearDefinition.Slot.WEAPON, Color(0.55, 0.85, 1.0), {"blade_damage_multiplier": 1.35, "blade_element": &"water"})
	var fenscale := _gear("fenscale_mail", "Fenscale Mail",
			"Overlapping serpent scales on a moss lining. Light, and it sheds poison.", GearDefinition.Slot.ARMOR,
			Color(0.35, 0.4, 0.7), {"max_health_bonus": 30.0, "damage_reduction": 0.2})
	var catalog: CraftingCatalog = load("res://data/crafting/catalog.tres")
	catalog.recipes.append(_recipe("storm_charm", storm, [crystal, shard] as Array[ItemDefinition], [3, 1]))
	catalog.recipes.append(_recipe("moonfang_blades", moonfang, [pearl, moss] as Array[ItemDefinition], [1, 2]))
	catalog.recipes.append(_recipe("fenscale_mail", fenscale, [scale, moss] as Array[ItemDefinition], [1, 2]))
	catalog.items.append_array([moss, pearl, scale])
	_save(catalog, "res://data/crafting/catalog.tres")


func _moonfen_scenes() -> void:
	# Lantern Lure spirit spout (RootSnare behaviour: warn ring -> rise -> hit).
	var sp := Node3D.new()
	sp.name = "SpiritSpout"
	sp.set_script(load("res://scripts/bosses/root_snare.gd"))
	sp.add_child(_warning_quad("Ring", Vector2(3.4, 3.4), Vector3(0, 0.07, 0), "snare_warning"))
	var roots := Node3D.new()
	roots.name = "Roots"
	var rm := MeshInstance3D.new()
	rm.mesh = ProceduralMeshes.spirit_spout(load(MAT + "glow_fungus.tres"))
	roots.add_child(rm)
	sp.add_child(roots)
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.6
	cyl.height = 2.2
	sp.add_child(_area("Hitbox", "res://scripts/combat/hitbox.gd", &"enemy", cyl, Vector3(0, 1, 0)))
	_pack(sp, "res://scenes/bosses/spirit_spout.tscn")
	var def: BossDefinition = load("res://data/bosses/nami.tres")
	def.get_attack(&"lantern_lure").eruption_scene = load("res://scenes/bosses/spirit_spout.tscn")
	_save(def, "res://data/bosses/nami.tres")

	# Sinking reed raft.
	var r := AnimatableBody3D.new()
	r.name = "SinkingRaft"
	r.set_script(load("res://scripts/world/hazards/sinking_raft.gd"))
	r.collision_layer = 1
	var rc := CollisionShape3D.new()
	rc.shape = _box_shape(Vector3(3.0, 0.5, 3.0))
	rc.position.y = -0.25
	r.add_child(rc)
	var rmesh := MeshInstance3D.new()
	rmesh.name = "Mesh"
	rmesh.mesh = ProceduralMeshes.reed_raft(load(MAT + "reed.tres"))
	r.add_child(rmesh)
	var trig := Area3D.new()
	trig.name = "Trigger"
	var tc := CollisionShape3D.new()
	tc.shape = _box_shape(Vector3(2.8, 0.6, 2.8))
	tc.position.y = 0.3
	trig.add_child(tc)
	r.add_child(trig)
	_pack(r, "res://scenes/world/sinking_raft.tscn")

	# Spirit Moss pickup.
	var a := Area3D.new()
	a.name = "Pickup"
	a.set_script(load("res://scripts/world/pickup.gd"))
	a.set("item", load("res://data/items/spirit_moss.tres"))
	var ps := SphereShape3D.new()
	ps.radius = 1.0
	var pcol := CollisionShape3D.new()
	pcol.shape = ps
	pcol.position.y = 0.6
	a.add_child(pcol)
	var vis := Node3D.new()
	vis.name = "Visual"
	a.add_child(vis)
	var rng := RandomNumberGenerator.new()
	rng.seed = 124
	var tuft := MeshInstance3D.new()
	tuft.mesh = ProceduralMeshes.mushroom_cluster(rng, Color(0.6, 0.45, 1.0), load(MAT + "glow_fungus.tres"))
	tuft.scale = Vector3.ONE * 0.8
	vis.add_child(tuft)
	var mote := MeshInstance3D.new()
	var mq := QuadMesh.new()
	mq.size = Vector2(0.9, 0.9)
	mq.material = load(MAT + "spirit_flame.tres")
	mote.mesh = mq
	mote.position.y = 0.6
	mote.set_script(load("res://scripts/world/instance_tint.gd"))
	mote.set("color", Color(0.55, 0.45, 1.0) * 0.6)
	vis.add_child(mote)
	_pack(a, "res://scenes/world/pickup_spirit_moss.tscn")

	# Nami, the Lantern Serpent.
	var k := CharacterBody3D.new()
	k.name = "Nami"
	k.set_script(load("res://scripts/bosses/boss_controller.gd"))
	k.set("definition", load("res://data/bosses/nami.tres"))
	var col := CollisionShape3D.new()
	col.name = "Collision"
	col.shape = _box_shape(Vector3(3.0, 2.4, 4.6))
	col.position = Vector3(0, 1.2, 0.6)
	k.add_child(col)
	var vis2 := Node3D.new()
	vis2.name = "Visual"
	k.add_child(vis2)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = ProceduralMeshes.serpent_body(load(MAT + "nami_body.tres"))
	vis2.add_child(body)
	var lantern := MeshInstance3D.new()
	lantern.name = "Lantern"
	lantern.mesh = ProceduralMeshes.serpent_lantern(load(MAT + "nami_lantern.tres"), false)
	vis2.add_child(lantern)
	var stub := MeshInstance3D.new()
	stub.name = "LanternStub"
	stub.mesh = ProceduralMeshes.serpent_lantern(load(MAT + "nami_lantern.tres"), true)
	vis2.add_child(stub)
	var glow := OmniLight3D.new()
	glow.name = "LanternLight"
	glow.light_color = Color(0.55, 0.95, 1.0)
	glow.light_energy = 2.0
	glow.omni_range = 8.0
	glow.position = Vector3(0, 4.1, -3.7)
	lantern.add_child(glow)
	var lh := _area("LanternHurtbox", "res://scripts/combat/hurtbox.gd", &"enemy", _box_shape(Vector3(2.8, 2.6, 2.4)), Vector3(0, 3.6, -3.2))
	lh.set("part_id", &"lantern")
	lh.set("health_path", NodePath("../../Health"))
	vis2.add_child(lh)
	var front := Node3D.new()
	front.name = "Front"
	k.add_child(front)
	front.add_child(_area("FloodHitbox", "res://scripts/combat/hitbox.gd", &"enemy", _box_shape(Vector3(4.6, 2.6, 11.0)), Vector3(0, 1.2, -7.5)))
	front.add_child(_warning_quad("FloodWarning", Vector2(5.0, 11.5), Vector3(0, 0.12, -7.5), "flood_warning"))
	var dive_shape := SphereShape3D.new()
	dive_shape.radius = 2.4
	front.add_child(_area("DiveHitbox", "res://scripts/combat/hitbox.gd", &"enemy", dive_shape, Vector3(0, 1.2, -1.5)))
	front.add_child(_warning_quad("DiveWarning", Vector2(3.0, 14.0), Vector3(0, 0.12, -8.5), "attack_warning"))
	var hcomp := Node.new()
	hcomp.name = "Health"
	hcomp.set_script(load("res://scripts/combat/health_component.gd"))
	k.add_child(hcomp)
	var bh := _area("BodyHurtbox", "res://scripts/combat/hurtbox.gd", &"enemy", _box_shape(Vector3(3.2, 3.0, 5.4)), Vector3(0, 1.6, 0.0))
	bh.set("health_path", NodePath("../Health"))
	k.add_child(bh)
	var field := SphereShape3D.new()
	field.radius = 7.0
	k.add_child(_area("BurstHitbox", "res://scripts/combat/hitbox.gd", &"enemy", field, Vector3(0, 1.0, 0)))
	k.add_child(_warning_quad("BurstWarning", Vector2(14.0, 14.0), Vector3(0, 0.12, 0), "area_warning"))
	_pack(k, "res://scenes/bosses/nami.tscn")


## A spirit lantern on a post: the readable guide line through the fog bank.
func _spirit_lantern(node_name: String, pos: Vector3, parent: Node) -> void:
	var n := Node3D.new()
	n.name = node_name
	n.position = pos
	n.add_to_group("spirit_lanterns", true)
	var post := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.18, 1.6, 0.18)
	pm.material = load(MAT + "dark_wood.tres")
	post.mesh = pm
	post.position.y = 0.8
	n.add_child(post)
	var flame := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.7, 0.9)
	q.material = load(MAT + "spirit_flame.tres")
	flame.mesh = q
	flame.position.y = 1.85
	flame.set_script(load("res://scripts/world/instance_tint.gd"))
	flame.set("color", Color(0.45, 0.9, 1.0))
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(flame)
	var l := OmniLight3D.new()
	l.light_color = Color(0.45, 0.85, 1.0)
	l.light_energy = 1.6
	l.omni_range = 6.0
	l.position.y = 1.9
	n.add_child(l)
	parent.add_child(n)


## A round poison pool: SurfaceZone (damage + slight slow), sickly green water and a warning rim.
func _poison_pool(node_name: String, pos: Vector3, radius: float, parent: Node) -> void:
	var z := Area3D.new()
	z.name = node_name
	z.set_script(load("res://scripts/world/hazards/surface_zone.gd"))
	z.set("speed_multiplier", 0.8)
	z.set("damage_per_tick", 4.0)
	z.set("tick_time", 0.5)
	z.set("element", &"poison")
	z.set("attack_name", &"poison")
	z.add_to_group("poison_pools", true)
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 1.2
	var c := CollisionShape3D.new()
	c.shape = shape
	z.add_child(c)
	z.position = pos
	var water := MeshInstance3D.new()
	water.name = "Surface"
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.04
	cm.radial_segments = 20
	cm.material = load(MAT + "poison.tres")
	water.mesh = cm
	water.position.y = -0.52
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	z.add_child(water)
	var rim := _warning_quad("Rim", Vector2(radius * 2.1, radius * 2.1), Vector3(0, -0.48, 0), "poison_warning")
	rim.set_instance_shader_parameter("intensity", 0.25)
	z.add_child(rim)
	parent.add_child(z)


func _moonfen_level() -> void:
	_root = Node3D.new()
	_root.name = "Moonfen"
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = load(MAT + "sky_moon.tres")
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.24, 0.22, 0.34)
	env.ambient_light_energy = 4.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.17, 0.15, 0.26)
	env.fog_density = 0.02
	env.fog_sky_affect = 0.4
	env.fog_height = 0.5
	env.fog_height_density = 0.08
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_bloom = 0.07
	env.glow_hdr_threshold = 0.8
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 0.9
	env_node.environment = env
	_root.add_child(env_node)
	var moon := DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.rotation_degrees = Vector3(-38, 25, 0)
	moon.light_color = Color(0.7, 0.68, 1.0)
	moon.light_energy = 1.1
	moon.shadow_enabled = true
	moon.shadow_opacity = 0.7
	moon.directional_shadow_max_distance = 55.0
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_root.add_child(moon)

	var terrain := Node3D.new()
	terrain.name = "Terrain"
	terrain.set_script(load("res://scripts/world/biome_terrain.gd"))
	terrain.set("material", load(MAT + "terrain_fen.tres"))
	terrain.set("config", load("res://data/biomes/moonfen_terrain.tres"))
	_root.add_child(terrain)
	var flora := Node3D.new()
	flora.name = "Flora"
	flora.set_script(load("res://scripts/world/flora_scatter.gd"))
	flora.set("terrain_path", NodePath("../Terrain"))
	flora.set("grass_material", load(MAT + "foliage_fen.tres"))
	flora.set("leaf_material", load(MAT + "leaf_fen.tres"))
	flora.set("vine_material", load(MAT + "foliage_fen.tres"))
	flora.set("bark_material", load(MAT + "bark_vertex.tres"))
	flora.set("fungus_material", load(MAT + "glow_fungus.tres"))
	flora.set("rock_material", load(MAT + "rock_vertex.tres"))
	flora.set("stone_material", load(MAT + "stone.tres"))
	flora.set("config", load("res://data/biomes/moonfen_flora.tres"))
	_root.add_child(flora)
	var fauna := Node3D.new()
	fauna.name = "Fauna"
	fauna.set_script(load("res://scripts/world/fauna/fauna_spawner.gd"))
	fauna.set("terrain_path", NodePath("../Terrain"))
	fauna.set("config", load("res://data/biomes/moonfen_fauna.tres"))
	fauna.set("bat_material", load(MAT + "bat.tres"))
	fauna.set("frog_material", load(MAT + "frog.tres"))
	fauna.set("eye_material", load(MAT + "lurker_eyes.tres"))
	fauna.set("firefly_material", load(MAT + "firefly.tres"))
	_root.add_child(fauna)
	var atmos := Node3D.new()
	atmos.name = "Atmosphere"
	atmos.set_script(load("res://scripts/world/biome_atmosphere.gd"))
	atmos.set("mood", load("res://data/mood/moonfen.tres"))  # Art pass stage 3 (tools/generate_moods.gd).
	atmos.set("terrain_path", NodePath("../Terrain"))
	atmos.set("sun_path", NodePath("../Moonlight"))
	atmos.set("environment_path", NodePath("../WorldEnvironment"))
	atmos.set("mist_material", load(MAT + "mist_fen.tres"))
	atmos.set("shaft_material", load(MAT + "shaft_moon.tres"))
	atmos.set("waterfall_material", load(MAT + "waterfall.tres"))
	atmos.set("water_material", load(MAT + "bog_water.tres"))
	atmos.set("river_height", -0.35)
	atmos.set("waterfalls", [] as Array[Vector3])
	atmos.set("lightning_interval", Vector2(20.0, 45.0))
	atmos.set("lightning_sky_flash", 0.35)
	atmos.set("lightning_sun_boost", 0.5)
	_root.add_child(atmos)
	var geo := Node3D.new()
	geo.name = "RouteGeometry"
	_root.add_child(geo)
	var spawn := Marker3D.new()
	spawn.name = "SpawnPoint"
	spawn.position = Vector3(0, 0.1, 0)
	_root.add_child(spawn)
	var cps := Node3D.new()
	cps.name = "Checkpoints"
	_root.add_child(cps)
	_checkpoint("CheckpointSpawn", Vector3(-4.5, 0, 1))
	_checkpoint("CheckpointStream", Vector3(-4.5, 0, -26))
	_checkpoint("CheckpointBog", Vector3(-4.5, 0, -48.5))
	_checkpoint("CheckpointGate", Vector3(-4.5, 0, -78))

	var hazards := Node3D.new()
	hazards.name = "Hazards"
	_root.add_child(hazards)
	# 1) Mud flats between root walls: wade slowly (no jumping) or balance along the fallen log.
	_box("MudWallL", Vector3(1.2, 3.0, 16), Vector3(-4.6, 1.2, -15), "dark_wood")
	_box("MudWallR", Vector3(1.2, 3.0, 16), Vector3(4.6, 1.2, -15), "dark_wood")
	var mud := Area3D.new()
	mud.name = "MudFlats"
	mud.set_script(load("res://scripts/world/hazards/surface_zone.gd"))
	mud.set("speed_multiplier", 0.45)
	mud.set("blocks_jump", true)
	var mc := CollisionShape3D.new()
	mc.shape = _box_shape(Vector3(6.2, 0.9, 14.0))
	mud.add_child(mc)
	mud.position = Vector3(-0.7, 0.0, -15)
	var mud_quad := MeshInstance3D.new()
	mud_quad.name = "Surface"
	var mp := PlaneMesh.new()
	mp.size = Vector2(6.2, 14.0)
	mp.material = load(MAT + "mud.tres")
	mud_quad.mesh = mp
	mud_quad.position.y = 0.04
	mud_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mud.add_child(mud_quad)
	hazards.add_child(mud)
	_box("FallenLog", Vector3(0.9, 0.6, 17), Vector3(3.1, 0.3, -15), "dark_wood")
	# 2) Stream with a current pushing east, toward a poison pool downstream.
	var stream := Area3D.new()
	stream.name = "StreamCurrent"
	stream.set_script(load("res://scripts/world/hazards/surface_zone.gd"))
	stream.set("speed_multiplier", 0.8)
	stream.set("current", Vector3(2.2, 0, 0))
	var sc := CollisionShape3D.new()
	sc.shape = _box_shape(Vector3(60, 1.6, 5.0))
	stream.add_child(sc)
	stream.position = Vector3(0, -0.2, -33)
	hazards.add_child(stream)
	_poison_pool("PoisonPoolStream", Vector3(9.5, 0.1, -33), 2.6, hazards)
	# 3) Fog bank: the world closes in; spirit lanterns mark the safe line on the right,
	#    a poison pool hides on the left.
	var fog := Area3D.new()
	fog.name = "FogBank"
	fog.set_script(load("res://scripts/world/hazards/fog_zone.gd"))
	fog.set("environment_path", NodePath("../../WorldEnvironment"))
	var fc := CollisionShape3D.new()
	fc.shape = _box_shape(Vector3(40, 8, 11))
	fog.add_child(fc)
	fog.position = Vector3(0, 2, -43.5)
	hazards.add_child(fog)
	for i in 4:
		_spirit_lantern("SpiritLantern%d" % i, Vector3(2.6, 0, -38.0 - 3.3 * i), hazards)
	_poison_pool("PoisonPoolFog", Vector3(-2.6, 0.1, -44.0), 2.0, hazards)
	_poison_pool("PoisonPoolHollow", Vector3(-16.0, 0.1, -20.0), 2.4, hazards)
	# 4) Deep bog: sinking reed rafts (they sink under your weight), then the root-wall far bank.
	var raft_scene: PackedScene = load("res://scenes/world/sinking_raft.tscn")
	var zs := [-53.5, -58.0, -62.5, -67.0]
	for i in zs.size():
		var rf: Node3D = raft_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		rf.name = "SinkingRaft%d" % i
		rf.position = Vector3(0, 0, zs[i])
		hazards.add_child(rf)
	var bog := Area3D.new()
	bog.name = "DeepBog"
	bog.set_script(load("res://scripts/world/hazards/lava_zone.gd"))
	bog.set("damage", 20.0)
	bog.set("element", &"water")
	bog.set("attack_name", &"drowned")
	var bcol := CollisionShape3D.new()
	bcol.shape = _box_shape(Vector3(160, 6, 20.6))
	bog.add_child(bcol)
	bog.position = Vector3(0, -4.2, -60.5)
	hazards.add_child(bog)
	var wall := _box("FarBankWall", Vector3(30, 22.3, 3), Vector3(0, -8.85, -72.5), "climb_stone")
	wall.collision_layer = 1 | 4

	# Gate + arena (same layout as the other biomes).
	_box("GatePillarL", Vector3(1.6, 8, 1.6), Vector3(-4.2, 4, -94), "gate_stone")
	_box("GatePillarR", Vector3(1.6, 8, 1.6), Vector3(4.2, 4, -94), "gate_stone")
	_box("GateLintel", Vector3(11, 1.4, 2.0), Vector3(0, 8.5, -94), "gate_stone")
	_box("ArenaWallL", Vector3(40, 8, 1.5), Vector3(-25.0, 2, -94), "stone")
	_box("ArenaWallR", Vector3(40, 8, 1.5), Vector3(25.0, 2, -94), "stone")
	var trigger := Area3D.new()
	trigger.name = "BossArenaTrigger"
	trigger.set_script(load("res://scripts/world/boss_arena_trigger.gd"))
	var tcol := CollisionShape3D.new()
	tcol.shape = _box_shape(Vector3(160, 80, 54))
	trigger.add_child(tcol)
	trigger.position = Vector3(0, 10, -123)
	_root.add_child(trigger)
	for i in 10:
		var ang := TAU * float(i) / 10.0 + PI / 10.0
		if absf(wrapf(ang - PI / 2.0, -PI, PI)) < 0.5:
			continue
		var p := Vector3(cos(ang) * 17.0, 0, -120.0 + sin(ang) * 17.0)
		var c := CSGCylinder3D.new()
		c.name = "ArenaPillar%d" % i
		c.radius = 1.0
		c.height = 8.0
		c.sides = 7
		c.position = p + Vector3.UP * 4.0
		c.use_collision = true
		c.collision_mask = 0
		c.material = load(MAT + "stone.tres")
		geo.add_child(c)
	var marker := Marker3D.new()
	marker.name = "ArenaGateMarker"
	marker.position = Vector3(0, 0, -94)
	_root.add_child(marker)
	_omni("ArenaGlow", Vector3(0, 5, -120), Color(0.55, 0.4, 1.0), 2.5, 24.0)
	_omni("GateGlow", Vector3(0, 4, -91), Color(0.45, 0.85, 1.0), 2.0, 14.0)
	var boss: Node3D = (load("res://scenes/bosses/nami.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	boss.name = "Boss"
	boss.position = Vector3(0, 0.05, -121)
	boss.rotation.y = PI
	_root.add_child(boss)

	# Enemies, gatherables, lore.
	var enemies := Node3D.new()
	enemies.name = "Enemies"
	_root.add_child(enemies)
	for spec in [["ThornlingA", Vector3(-20, 0.2, -16)], ["ThornlingB", Vector3(-22, 0.2, -24)]]:
		var e: Node3D = (load("res://scenes/enemies/thornling.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		e.name = spec[0]
		e.position = spec[1]
		enemies.add_child(e)
	var gather := Node3D.new()
	gather.name = "Gatherables"
	_root.add_child(gather)
	var spots := [
		["spirit_moss", Vector3(3.1, 0.65, -22.5), false],  # End of the fallen log
		["spirit_moss", Vector3(-3.0, 0, -12), true],       # In the mud (slow to reach)
		["spirit_moss", Vector3(7.0, 0, -36.5), true],      # Downstream, beside the poison
		["spirit_moss", Vector3(-19, 0, -21), true],        # Thornling hollow
		["spirit_moss", Vector3(-7.0, 0, -84), true],
		["ruin_shard", Vector3(4.5, 0, -46), true], ["ruin_shard", Vector3(-9.5, 0, -6), true],
		["glowcap", Vector3(-12.5, 0, -40), true], ["glowcap", Vector3(8.0, 0, -82), true],
	]
	for i in spots.size():
		var spot: Array = spots[i]
		var pk: Node3D = (load("res://scenes/world/pickup_%s.tscn" % spot[0]) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		pk.name = "%s_%d" % [spot[0], i]
		pk.position = spot[1]
		pk.set("snap_to_ground", spot[2])
		gather.add_child(pk)
	var ls: Node3D = (load("res://scenes/world/lore_stone.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	ls.name = "LoreStone0"
	ls.set("title", "The Lantern Serpent")
	ls.set("text", "Do not follow the light over the water. Nami's lantern has drowned more hunters than its jaws. The old dojo forged storm-charms against it; water only feeds it. Cut the lantern down when it bows to strike.")
	ls.position = Vector3(6.5, 0, -82)
	gather.add_child(ls)
	_pack(_root, "res://scenes/biomes/moonfen.tscn")


func _moonfen_unlock() -> void:
	var b: BiomeDefinition = load("res://data/biomes/biome_moonfen.tres")
	b.hunts = [load("res://data/hunts/nami.tres")] as Array[HuntDefinition]
	b.unlocked = true
	b.requires_hunt = &"ashen_oni_tortoise"
	b.expedition_scene = "res://scenes/main/expedition_moonfen.tscn"
	b.locked_note = "defeat the Ashen Oni-Tortoise to unlock"
	_save(b, "res://data/biomes/biome_moonfen.tres")
	var board: PackedScene = load("res://scenes/ui/hunt_board.tscn")
	var inst := board.instantiate()
	var items: Array[ItemDefinition] = (load("res://data/crafting/catalog.tres") as CraftingCatalog).items
	inst.set("known_items", items)
	_pack(inst, "res://scenes/ui/hunt_board.tscn")


# ================================================================ Phase 10: Stormcrag

func _stormcrag() -> void:
	_stormcrag_materials()
	_stormcrag_data()
	_stormcrag_scenes()
	_stormcrag_level()
	_main_scene("res://scenes/biomes/stormcrag.tscn", "res://data/hunts/raijins_echo.tres",
			"res://scenes/main/expedition_stormcrag.tscn")
	_stormcrag_unlock()


func _stormcrag_materials() -> void:
	var detail: Resource = load(MAT + "noise_detail.tres")
	_save(_shader_mat("terrain", {"detail_noise": detail, "macro_noise": load(MAT + "noise_macro.tres"),
			"moss_dark": Color(0.06, 0.08, 0.07), "moss_light": Color(0.13, 0.17, 0.14), "mud": Color(0.11, 0.11, 0.12),
			"rock": Color(0.24, 0.26, 0.3), "rock_dark": Color(0.08, 0.09, 0.11)}), MAT + "terrain_crag.tres")
	_save(_shader_mat("stone", {"detail_noise": detail, "stone_light": Color(0.3, 0.32, 0.36),
			"stone_dark": Color(0.1, 0.11, 0.13), "moss": Color(0.08, 0.12, 0.1), "moss_amount": 0.3}), MAT + "crag_stone.tres")
	_save(_shader_mat("stone", {"detail_noise": detail, "stone_light": Color(0.24, 0.27, 0.32),
			"stone_dark": Color(0.06, 0.07, 0.09), "moss": Color(0.1, 0.13, 0.16), "moss_amount": 0.15,
			"rune_color": Color(0.5, 0.7, 1.0), "rune_strength": 0.25}), MAT + "wet_stone.tres")
	_save(_shader_mat("foliage", {"wind_strength": 0.35, "wind_speed": 2.4, "translucency": 0.25,
			"tint": Color(0.75, 0.85, 0.9), "brightness": 1.7}), MAT + "foliage_crag.tres")
	_save(_shader_mat("foliage", {"wind_strength": 0.25, "wind_speed": 2.2, "translucency": 0.25,
			"tint": Color(0.7, 0.8, 0.85), "brightness": 1.6}), MAT + "leaf_crag.tres")
	_save(_shader_mat("sky_gloom", {"cloud_noise": load(MAT + "noise_clouds.tres"), "zenith": Color(0.03, 0.04, 0.06),
			"horizon": Color(0.18, 0.21, 0.27), "glow_tint": Color(0.3, 0.35, 0.5), "flash_color": Color(0.75, 0.85, 1.0),
			"cloud_speed": 0.03, "moon_dir": Vector3(-0.2, 0.25, -0.95)}), MAT + "sky_storm.tres")
	_save(_shader_mat("mist_card", {"mist_noise": load(MAT + "noise_mist.tres"), "color": Color(0.3, 0.33, 0.38),
			"opacity": 0.3}), MAT + "mist_storm.tres")
	_save(_shader_mat("light_shaft", {"color": Color(0.55, 0.65, 0.85), "strength": 0.025}), MAT + "shaft_storm.tres")
	_save(_shader_mat("attack_warning", {"color": Color(0.7, 0.9, 1.0)}), MAT + "gust_warning.tres")
	_save(_shader_mat("area_warning", {"color": Color(0.5, 0.65, 1.0)}), MAT + "lightning_warning.tres")
	_save(_shader_mat("spirit_flame", {"energy": 6.0}), MAT + "bolt_flame.tres")
	_save(_shader_mat("creature", {"body_color": Color(0.12, 0.13, 0.17), "glow_color": Color(0.7, 0.9, 1.0),
			"glow_energy": 5.0, "spine_idle": Color(0.25, 0.3, 0.42), "spine_color": Color(0.7, 0.85, 1.0),
			"spine_strength": 3.0, "flap_amount": 0.18, "flap_speed": 2.2}), MAT + "roc_body.tres")
	_save(_shader_mat("creature", {"body_color": Color(0.2, 0.22, 0.3), "glow_color": Color(0.7, 0.9, 1.0),
			"glow_energy": 1.5, "spine_idle": Color(0.35, 0.45, 0.7), "spine_color": Color(0.75, 0.9, 1.0),
			"spine_strength": 2.0}), MAT + "roc_crest.tres")
	var rain := StandardMaterial3D.new()
	rain.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rain.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rain.albedo_color = Color(0.7, 0.8, 0.95, 0.35)
	rain.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	rain.cull_mode = BaseMaterial3D.CULL_DISABLED
	_save(rain, MAT + "rain.tres")


func _stormcrag_data() -> void:
	var terrain := TerrainConfig.new()
	terrain.seed = 8484
	terrain.hill_height = 9.0
	terrain.hill_frequency = 0.035
	terrain.valley_wall_height = 26.0
	terrain.border_height = 40.0
	terrain.stream_z = -1000.0  # No stream.
	terrain.stream_depth = 0.0
	terrain.gorge_depth = -40.0  # The chasm under the gale ridge: falling = back to safe ground.
	_save(terrain, "res://data/biomes/stormcrag_terrain.tres")
	var flora := FloraConfig.new()
	flora.seed = 9595
	flora.grass_count = 2600
	flora.fern_count = 300
	flora.broadleaf_count = 60
	flora.mushroom_count = 120
	flora.rock_count = 1400
	flora.jungle_tree_count = 30
	flora.dead_tree_count = 70
	flora.log_count = 12
	flora.pillar_count = 22
	flora.mushroom_glows = [Color(0.55, 0.75, 1.0), Color(0.8, 0.85, 1.0)] as Array[Color]
	_save(flora, "res://data/biomes/stormcrag_flora.tres")
	var fauna := FaunaConfig.new()
	fauna.seed = 1010
	fauna.bat_flocks = [Vector3(0, 22, -60), Vector3(-30, 25, -20), Vector3(30, 24, -90)] as Array[Vector3]
	fauna.frog_count = 0
	fauna.lurker_count = 8
	fauna.lurker_glow = Color(0.6, 0.8, 1.0)
	fauna.firefly_swarms = 8
	fauna.firefly_color = Color(0.7, 0.85, 1.0)  # Static sparks.
	_save(fauna, "res://data/biomes/stormcrag_fauna.tres")
	# Items.
	var glass := _item("storm_glass", "Storm Glass", "Sand fused by a lightning strike. It hums in your hand.",
			Color(0.65, 0.8, 1.0), 0)
	var crest := _item("storm_crest", "Storm Crest", "A crest feather of Raijin's Echo, still crackling.",
			Color(0.75, 0.9, 1.0), 1)
	var plume := _item("roc_plume", "Roc Plume", "A long flight feather from the Sky Roc. Wind will not tear it.",
			Color(0.35, 0.4, 0.5), 0)
	# Boss: Raijin's Echo, the Sky Roc (lightning; weak to earth).
	var el := ElementProfile.new()
	el.affinity = &"lightning"
	el.multipliers = {&"earth": 1.5, &"lightning": 0.25, &"water": 0.75}
	var shear := _boss_attack("wing_shear", "Wing Shear", 1.1, 0.4, 1.2, 26.0, 12.0, 0.0, 6.5, 3.0, 3.0,
			"It raises both wings: back out of the wide zone in front, then strike the crest as it lunges low.")
	shear.kind = BossAttackDefinition.Kind.FRONT
	shear.hitbox_node = NodePath("Front/ShearHitbox")
	shear.warning_node = NodePath("Front/ShearWarning")
	shear.telegraph_pitch = 0.4
	shear.glow = BossAttackDefinition.Glow.BODY
	shear.weakened_by_part = &"crest"
	shear.element = &"lightning"
	var call := _boss_attack("storm_call", "Storm Call", 1.3, 0.4, 1.0, 22.0, 6.0, 3.0, 26.0, 2.0, 6.0,
			"Its crest flares and pale circles open around you: step out before the bolts fall.")
	call.kind = BossAttackDefinition.Kind.ERUPTIONS
	call.eruption_offsets = PackedVector3Array([Vector3.ZERO, Vector3(3.0, 0, -1.0), Vector3(-3.0, 0, -1.0), Vector3(0, 0, 3.0)])
	call.telegraph_pitch = 0.3
	call.glow = BossAttackDefinition.Glow.PARTS
	call.element = &"lightning"
	var dive := _boss_attack("dive", "Thunder Dive", 1.0, 1.1, 1.5, 28.0, 13.0, 6.0, 26.0, 2.0, 6.0,
			"It crouches and launches low along the line: roll sideways late; it stuns itself on the pillars.")
	dive.kind = BossAttackDefinition.Kind.DASH
	dive.hitbox_node = NodePath("Front/DiveHitbox")
	dive.warning_node = NodePath("Front/DiveWarning")
	dive.move_speed = 14.0
	dive.dash_homing = 0.5
	dive.stuns_on_wall = true
	dive.stun_time = 2.6
	dive.telegraph_pitch = -0.25
	dive.telegraph_wobble = 0.05
	dive.element = &"lightning"
	var burst := _boss_attack("thunder_burst", "Thunder Burst", 1.2, 0.4, 1.0, 24.0, 10.0, 0.0, 6.5, 2.0, 7.0,
			"Enraged: the ground around it crackles; get out of the ring.")
	burst.kind = BossAttackDefinition.Kind.RADIAL
	burst.enraged_only = true
	burst.hitbox_node = NodePath("BurstHitbox")
	burst.warning_node = NodePath("BurstWarning")
	burst.telegraph_pitch = 0.2
	burst.glow = BossAttackDefinition.Glow.BODY
	burst.tracks_player = false
	burst.element = &"lightning"
	var part := BossPartDefinition.new()
	part.id = &"crest"
	part.display_name = "Crest"
	part.break_health = 240.0
	part.reward = crest
	part.reward_count = 1
	part.break_stagger_time = 2.3
	part.intact_node = NodePath("Visual/Crest")
	part.broken_node = NodePath("Visual/CrestStub")
	var def := BossDefinition.new()
	def.id = &"raijins_echo"
	def.display_name = "Raijin's Echo, the Sky Roc"
	def.max_health = 1050.0
	def.poise = 130.0
	def.stagger_time = 1.5
	def.elements = el
	def.attacks = [shear, call, dive, burst] as Array[BossAttackDefinition]
	def.parts = [part] as Array[BossPartDefinition]
	def.victory_rewards = [plume] as Array[ItemDefinition]
	def.walk_speed = 3.2
	def.turn_sharpness = 4.0
	def.stalk_distance = 5.0
	def.attack_interval = 1.25
	def.head_down_pitch = -0.5
	def.lock_offset = Vector3(0, 2.8, -1.6)
	_save(def, "res://data/bosses/raijins_echo.tres")
	var h := HuntDefinition.new()
	h.id = &"raijins_echo"
	h.beast_name = "Raijin's Echo"
	h.epithet = "the Sky Roc"
	h.element = "Lightning"
	h.weakness = "Earth"
	h.signature = "Wing shear, storm call, thunder dive"
	h.description = "A storm bird the size of a temple roof. Where it lands, lightning follows. Old stone grounds it."
	h.config = load("res://data/expedition/default_expedition.tres")
	_save(h, "res://data/hunts/raijins_echo.tres")
	# Crafting: Stone Charm (earth talisman from earlier materials) + two Stormcrag recipes.
	var shard: ItemDefinition = load("res://data/items/ruin_shard.tres")
	var moss: ItemDefinition = load("res://data/items/spirit_moss.tres")
	var stone := _gear("stone_charm", "Stone Charm",
			"Two ruin shards bound in spirit moss. Talismans strike like falling stone — they ground lightning.",
			GearDefinition.Slot.CHARM, Color(0.85, 0.6, 0.3), {"skill_element": &"earth", "skill_cooldown_reduction": 0.5})
	var thunder := _gear("thunderfang_blades", "Thunderfang Blades",
			"Blades fused with storm glass around a crest feather. They spark on every cut — Nami fears them.",
			GearDefinition.Slot.WEAPON, Color(0.7, 0.85, 1.0), {"blade_damage_multiplier": 1.45, "blade_element": &"lightning"})
	var gale := _gear("galeweave_garb", "Galeweave Garb",
			"Roc plumes woven over a storm-glass mail. Light enough to run in, hard enough to stop a talon.",
			GearDefinition.Slot.ARMOR, Color(0.45, 0.5, 0.65), {"max_health_bonus": 45.0, "damage_reduction": 0.25})
	var catalog: CraftingCatalog = load("res://data/crafting/catalog.tres")
	catalog.recipes.append(_recipe("stone_charm", stone, [shard, moss] as Array[ItemDefinition], [2, 2]))
	catalog.recipes.append(_recipe("thunderfang_blades", thunder, [crest, glass] as Array[ItemDefinition], [1, 2]))
	catalog.recipes.append(_recipe("galeweave_garb", gale, [plume, glass] as Array[ItemDefinition], [1, 2]))
	catalog.items.append_array([glass, crest, plume])
	_save(catalog, "res://data/crafting/catalog.tres")


func _stormcrag_scenes() -> void:
	# Storm Call bolt (RootSnare behaviour: warn ring -> bolt rises -> hit).
	var sb := Node3D.new()
	sb.name = "StormBolt"
	sb.set_script(load("res://scripts/bosses/root_snare.gd"))
	sb.add_child(_warning_quad("Ring", Vector2(3.4, 3.4), Vector3(0, 0.07, 0), "lightning_warning"))
	var roots := Node3D.new()
	roots.name = "Roots"
	var rm := MeshInstance3D.new()
	rm.mesh = ProceduralMeshes.lightning_bolt(load(MAT + "glow_fungus.tres"))
	roots.add_child(rm)
	sb.add_child(roots)
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.6
	cyl.height = 2.2
	sb.add_child(_area("Hitbox", "res://scripts/combat/hitbox.gd", &"enemy", cyl, Vector3(0, 1, 0)))
	_pack(sb, "res://scenes/bosses/storm_bolt.tscn")
	var def: BossDefinition = load("res://data/bosses/raijins_echo.tres")
	def.get_attack(&"storm_call").eruption_scene = load("res://scenes/bosses/storm_bolt.tscn")
	_save(def, "res://data/bosses/raijins_echo.tres")

	# Storm Glass pickup.
	var a := Area3D.new()
	a.name = "Pickup"
	a.set_script(load("res://scripts/world/pickup.gd"))
	a.set("item", load("res://data/items/storm_glass.tres"))
	var ps := SphereShape3D.new()
	ps.radius = 1.0
	var pcol := CollisionShape3D.new()
	pcol.shape = ps
	pcol.position.y = 0.6
	a.add_child(pcol)
	var vis := Node3D.new()
	vis.name = "Visual"
	a.add_child(vis)
	var gem := MeshInstance3D.new()
	var gm := PrismMesh.new()
	gm.size = Vector3(0.3, 0.7, 0.3)
	gm.material = load(MAT + "roc_crest.tres")  # Pale glowing glass (creature shader, emissive).
	gem.mesh = gm
	vis.add_child(gem)
	var mote := MeshInstance3D.new()
	var mq := QuadMesh.new()
	mq.size = Vector2(0.9, 0.9)
	mq.material = load(MAT + "spirit_flame.tres")
	mote.mesh = mq
	mote.position.y = 0.6
	mote.set_script(load("res://scripts/world/instance_tint.gd"))
	mote.set("color", Color(0.6, 0.75, 1.0) * 0.6)
	vis.add_child(mote)
	_pack(a, "res://scenes/world/pickup_storm_glass.tscn")

	# Raijin's Echo, the Sky Roc.
	var k := CharacterBody3D.new()
	k.name = "RaijinsEcho"
	k.set_script(load("res://scripts/bosses/boss_controller.gd"))
	k.set("definition", load("res://data/bosses/raijins_echo.tres"))
	var col := CollisionShape3D.new()
	col.name = "Collision"
	col.shape = _box_shape(Vector3(2.6, 3.2, 3.8))
	col.position = Vector3(0, 1.6, 0.2)
	k.add_child(col)
	var vis2 := Node3D.new()
	vis2.name = "Visual"
	k.add_child(vis2)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = ProceduralMeshes.sky_roc_body(load(MAT + "roc_body.tres"))
	vis2.add_child(body)
	var crest := MeshInstance3D.new()
	crest.name = "Crest"
	crest.mesh = ProceduralMeshes.roc_crest(load(MAT + "roc_crest.tres"), false)
	vis2.add_child(crest)
	var stub := MeshInstance3D.new()
	stub.name = "CrestStub"
	stub.mesh = ProceduralMeshes.roc_crest(load(MAT + "roc_crest.tres"), true)
	vis2.add_child(stub)
	var ch := _area("CrestHurtbox", "res://scripts/combat/hurtbox.gd", &"enemy", _box_shape(Vector3(2.8, 2.6, 2.4)), Vector3(0, 3.6, -2.4))
	ch.set("part_id", &"crest")
	ch.set("health_path", NodePath("../../Health"))
	vis2.add_child(ch)
	var front := Node3D.new()
	front.name = "Front"
	k.add_child(front)
	front.add_child(_area("ShearHitbox", "res://scripts/combat/hitbox.gd", &"enemy", _box_shape(Vector3(8.0, 2.8, 4.5)), Vector3(0, 1.3, -3.8)))
	front.add_child(_warning_quad("ShearWarning", Vector2(8.5, 5.0), Vector3(0, 0.12, -3.9), "area_warning"))
	var dive_shape := SphereShape3D.new()
	dive_shape.radius = 2.3
	front.add_child(_area("DiveHitbox", "res://scripts/combat/hitbox.gd", &"enemy", dive_shape, Vector3(0, 1.3, -1.2)))
	front.add_child(_warning_quad("DiveWarning", Vector2(3.0, 14.0), Vector3(0, 0.12, -8.5), "attack_warning"))
	var hcomp := Node.new()
	hcomp.name = "Health"
	hcomp.set_script(load("res://scripts/combat/health_component.gd"))
	k.add_child(hcomp)
	var bh := _area("BodyHurtbox", "res://scripts/combat/hurtbox.gd", &"enemy", _box_shape(Vector3(2.8, 3.2, 4.4)), Vector3(0, 1.8, 0.0))
	bh.set("health_path", NodePath("../Health"))
	k.add_child(bh)
	var field := SphereShape3D.new()
	field.radius = 6.5
	k.add_child(_area("BurstHitbox", "res://scripts/combat/hitbox.gd", &"enemy", field, Vector3(0, 1.0, 0)))
	k.add_child(_warning_quad("BurstWarning", Vector2(13.0, 13.0), Vector3(0, 0.12, 0), "area_warning"))
	_pack(k, "res://scenes/bosses/raijins_echo.tscn")


## A rock overhang: a slab on two stones with a StormShelter area underneath.
func _overhang(node_name: String, pos: Vector3, parent: Node) -> void:
	_box(node_name + "Roof", Vector3(3.6, 0.6, 3.0), pos + Vector3(0, 2.6, 0), "crag_stone")
	_box(node_name + "PostA", Vector3(0.6, 2.4, 0.6), pos + Vector3(-1.4, 1.2, -1.0), "crag_stone")
	_box(node_name + "PostB", Vector3(0.6, 2.4, 0.6), pos + Vector3(1.4, 1.2, 1.0), "crag_stone")
	var sh := Area3D.new()
	sh.name = node_name
	sh.set_script(load("res://scripts/world/hazards/storm_shelter.gd"))
	var c := CollisionShape3D.new()
	c.shape = _box_shape(Vector3(3.2, 2.2, 2.6))
	sh.add_child(c)
	sh.position = pos + Vector3(0, 1.1, 0)
	parent.add_child(sh)


func _stormcrag_level() -> void:
	_root = Node3D.new()
	_root.name = "Stormcrag"
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = load(MAT + "sky_storm.tres")
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.24, 0.27, 0.32)
	env.ambient_light_energy = 4.2
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.2, 0.23, 0.28)
	env.fog_density = 0.022
	env.fog_sky_affect = 0.5
	env.fog_height = 0.0
	env.fog_height_density = 0.04
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.85
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.15
	env.adjustment_saturation = 0.75
	env_node.environment = env
	_root.add_child(env_node)
	var moon := DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.rotation_degrees = Vector3(-45, -20, 0)
	moon.light_color = Color(0.75, 0.82, 1.0)
	moon.light_energy = 1.0
	moon.shadow_enabled = true
	moon.shadow_opacity = 0.65
	moon.directional_shadow_max_distance = 55.0
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_root.add_child(moon)

	var terrain := Node3D.new()
	terrain.name = "Terrain"
	terrain.set_script(load("res://scripts/world/biome_terrain.gd"))
	terrain.set("material", load(MAT + "terrain_crag.tres"))
	terrain.set("config", load("res://data/biomes/stormcrag_terrain.tres"))
	_root.add_child(terrain)
	var flora := Node3D.new()
	flora.name = "Flora"
	flora.set_script(load("res://scripts/world/flora_scatter.gd"))
	flora.set("terrain_path", NodePath("../Terrain"))
	flora.set("grass_material", load(MAT + "foliage_crag.tres"))
	flora.set("leaf_material", load(MAT + "leaf_crag.tres"))
	flora.set("vine_material", load(MAT + "foliage_crag.tres"))
	flora.set("bark_material", load(MAT + "bark_vertex.tres"))
	flora.set("fungus_material", load(MAT + "glow_fungus.tres"))
	flora.set("rock_material", load(MAT + "rock_vertex.tres"))
	flora.set("stone_material", load(MAT + "crag_stone.tres"))
	flora.set("config", load("res://data/biomes/stormcrag_flora.tres"))
	_root.add_child(flora)
	var fauna := Node3D.new()
	fauna.name = "Fauna"
	fauna.set_script(load("res://scripts/world/fauna/fauna_spawner.gd"))
	fauna.set("terrain_path", NodePath("../Terrain"))
	fauna.set("config", load("res://data/biomes/stormcrag_fauna.tres"))
	fauna.set("bat_material", load(MAT + "bat.tres"))
	fauna.set("frog_material", load(MAT + "frog.tres"))
	fauna.set("eye_material", load(MAT + "lurker_eyes.tres"))
	fauna.set("firefly_material", load(MAT + "firefly.tres"))
	_root.add_child(fauna)
	var atmos := Node3D.new()
	atmos.name = "Atmosphere"
	atmos.set_script(load("res://scripts/world/biome_atmosphere.gd"))
	atmos.set("mood", load("res://data/mood/stormcrag.tres"))  # Art pass stage 3 (tools/generate_moods.gd).
	atmos.set("terrain_path", NodePath("../Terrain"))
	atmos.set("sun_path", NodePath("../Moonlight"))
	atmos.set("environment_path", NodePath("../WorldEnvironment"))
	atmos.set("mist_material", load(MAT + "mist_storm.tres"))
	atmos.set("shaft_material", load(MAT + "shaft_storm.tres"))
	atmos.set("waterfall_material", load(MAT + "waterfall.tres"))
	atmos.set("water_material", load(MAT + "water.tres"))
	atmos.set("river_height", -30.0)
	atmos.set("lightning_interval", Vector2(4.0, 11.0))  # The storm never stops.
	atmos.set("lightning_sky_flash", 0.9)
	atmos.set("lightning_sun_boost", 1.6)
	_root.add_child(atmos)
	var rain := CPUParticles3D.new()
	rain.name = "Rain"
	rain.set_script(load("res://scripts/world/rain_fx.gd"))
	var drop := QuadMesh.new()
	drop.size = Vector2(0.025, 0.7)
	drop.material = load(MAT + "rain.tres")
	rain.mesh = drop
	rain.lifetime = 1.0
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(16, 1, 16)
	rain.direction = Vector3(0.15, -1, 0)
	rain.spread = 4.0
	rain.gravity = Vector3(0, -6, 0)
	rain.initial_velocity_min = 14.0
	rain.initial_velocity_max = 18.0
	_root.add_child(rain)
	var geo := Node3D.new()
	geo.name = "RouteGeometry"
	_root.add_child(geo)
	var spawn := Marker3D.new()
	spawn.name = "SpawnPoint"
	spawn.position = Vector3(0, 0.1, 0)
	_root.add_child(spawn)
	var cps := Node3D.new()
	cps.name = "Checkpoints"
	_root.add_child(cps)
	_checkpoint("CheckpointSpawn", Vector3(-4.5, 0, 1))
	_checkpoint("CheckpointPlateau", Vector3(-4.5, 4.0, -13.5))
	_checkpoint("CheckpointRidge", Vector3(-4.5, 0, -46))
	_checkpoint("CheckpointGate", Vector3(-4.5, 0, -78))

	var hazards := Node3D.new()
	hazards.name = "Hazards"
	_root.add_child(hazards)
	# 1) Cliff: climbable face up to the storm plateau (top at y 4).
	_climb_box("CragCliff", Vector3(16, 5, 2), Vector3(0, 1.5, -10.5))
	_box("StormPlateau", Vector3(16, 5, 28), Vector3(0, 1.5, -25.5), "crag_stone")
	# 2) Storm plateau: lightning chases anyone standing in the open; two overhangs give shelter.
	var caller := Area3D.new()
	caller.name = "StormCaller"
	caller.set_script(load("res://scripts/world/hazards/storm_caller.gd"))
	caller.set("warning_material", load(MAT + "lightning_warning.tres"))
	caller.set("bolt_material", load(MAT + "bolt_flame.tres"))
	var cc := CollisionShape3D.new()
	cc.shape = _box_shape(Vector3(16, 4, 28))
	caller.add_child(cc)
	caller.position = Vector3(0, 6.0, -25.5)
	hazards.add_child(caller)
	_overhang("ShelterA", Vector3(-5.2, 4.0, -19), hazards)
	_overhang("ShelterB", Vector3(5.2, 4.0, -31), hazards)
	# 3) Gale ridge: a narrow, rain-slick stone spine over the chasm; gusts alternate sides.
	_box("GaleRidge", Vector3(2.4, 1.0, 23), Vector3(0, -0.5, -60.5), "wet_stone")
	var gust := Area3D.new()
	gust.name = "GaleGust"
	gust.set_script(load("res://scripts/world/hazards/gust_zone.gd"))
	gust.set("traction", 0.35)
	var gc := CollisionShape3D.new()
	gc.shape = _box_shape(Vector3(8, 5, 23))
	gust.add_child(gc)
	gust.position = Vector3(0, 2.0, -60.5)
	# Chevron strips along the ridge; GustZone turns them to sweep the way the wind will blow.
	var warn := Node3D.new()
	warn.name = "Warning"
	warn.visible = false
	for i in 5:
		warn.add_child(_warning_quad("Strip%d" % i, Vector2(2.0, 6.0), Vector3(0, -1.9, -9.0 + 4.5 * i), "gust_warning"))
	gust.add_child(warn)
	hazards.add_child(gust)
	for z in [-52.0, -60.5, -69.0]:
		_box("RidgeCairn%d" % int(-z), Vector3(0.5, 0.9, 0.5), Vector3(-1.0, 0.45, z), "crag_stone")

	# Gate + arena.
	_box("GatePillarL", Vector3(1.6, 8, 1.6), Vector3(-4.2, 4, -94), "gate_stone")
	_box("GatePillarR", Vector3(1.6, 8, 1.6), Vector3(4.2, 4, -94), "gate_stone")
	_box("GateLintel", Vector3(11, 1.4, 2.0), Vector3(0, 8.5, -94), "gate_stone")
	_box("ArenaWallL", Vector3(40, 8, 1.5), Vector3(-25.0, 2, -94), "crag_stone")
	_box("ArenaWallR", Vector3(40, 8, 1.5), Vector3(25.0, 2, -94), "crag_stone")
	var trigger := Area3D.new()
	trigger.name = "BossArenaTrigger"
	trigger.set_script(load("res://scripts/world/boss_arena_trigger.gd"))
	var tcol := CollisionShape3D.new()
	tcol.shape = _box_shape(Vector3(160, 80, 54))
	trigger.add_child(tcol)
	trigger.position = Vector3(0, 10, -123)
	_root.add_child(trigger)
	for i in 10:
		var ang := TAU * float(i) / 10.0 + PI / 10.0
		if absf(wrapf(ang - PI / 2.0, -PI, PI)) < 0.5:
			continue
		var p := Vector3(cos(ang) * 17.0, 0, -120.0 + sin(ang) * 17.0)
		var c := CSGCylinder3D.new()
		c.name = "ArenaPillar%d" % i
		c.radius = 1.0
		c.height = 8.0
		c.sides = 7
		c.position = p + Vector3.UP * 4.0
		c.use_collision = true
		c.collision_mask = 0
		c.material = load(MAT + "crag_stone.tres")
		geo.add_child(c)
	# Landmark: the storm temple, a stepped pyramid beyond the arena (scenery, no collision).
	for i in 6:
		var step := CSGBox3D.new()
		step.name = "TempleStep%d" % i
		var w := 30.0 - i * 4.6
		step.size = Vector3(w, 4.0, w)
		step.position = Vector3(26, 2.0 + i * 4.0, -170)
		step.material = load(MAT + "crag_stone.tres")
		geo.add_child(step)
	_omni("TempleBeacon", Vector3(26, 27, -170), Color(0.6, 0.8, 1.0), 4.0, 30.0)
	var marker := Marker3D.new()
	marker.name = "ArenaGateMarker"
	marker.position = Vector3(0, 0, -94)
	_root.add_child(marker)
	_omni("ArenaGlow", Vector3(0, 5, -120), Color(0.55, 0.7, 1.0), 2.5, 24.0)
	_omni("GateGlow", Vector3(0, 4, -91), Color(0.6, 0.8, 1.0), 2.0, 14.0)
	var boss: Node3D = (load("res://scenes/bosses/raijins_echo.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	boss.name = "Boss"
	boss.position = Vector3(0, 0.05, -121)
	boss.rotation.y = PI
	_root.add_child(boss)

	# Enemies, gatherables, lore.
	var enemies := Node3D.new()
	enemies.name = "Enemies"
	_root.add_child(enemies)
	for spec in [["ThornlingA", Vector3(-18, 0.2, -82)], ["ThornlingB", Vector3(18, 0.2, -84)]]:
		var e: Node3D = (load("res://scenes/enemies/thornling.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		e.name = spec[0]
		e.position = spec[1]
		enemies.add_child(e)
	var gather := Node3D.new()
	gather.name = "Gatherables"
	_root.add_child(gather)
	var spots := [
		["storm_glass", Vector3(-5.2, 4.0, -19), false],   # Under shelter A
		["storm_glass", Vector3(6.5, 4.0, -36), false],    # Open plateau corner (strikes!)
		["storm_glass", Vector3(0, 0.0, -60.5), false],    # Middle of the gale ridge
		["storm_glass", Vector3(-17, 0, -83), true],       # Thornling flank
		["storm_glass", Vector3(9.0, 0, -45), true],
		["ruin_shard", Vector3(-8.0, 0, -4), true], ["ruin_shard", Vector3(6.0, 0, -86), true],
		["spirit_moss", Vector3(-7.5, 0, -47), true], ["glowcap", Vector3(8.5, 0, -6), true],
	]
	for i in spots.size():
		var spot: Array = spots[i]
		var pk: Node3D = (load("res://scenes/world/pickup_%s.tscn" % spot[0]) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		pk.name = "%s_%d" % [spot[0], i]
		pk.position = spot[1]
		pk.set("snap_to_ground", spot[2])
		gather.add_child(pk)
	var ls: Node3D = (load("res://scenes/world/lore_stone.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	ls.name = "LoreStone0"
	ls.set("title", "Raijin's Echo")
	ls.set("text", "The storm god left; his echo stayed, and grew wings. Lightning cannot touch what is rooted in old stone — the dojo's stone-charms ground its fury. Strike the crest when it bows to shear.")
	ls.position = Vector3(6.5, 0, -80)
	gather.add_child(ls)
	_pack(_root, "res://scenes/biomes/stormcrag.tscn")


func _stormcrag_unlock() -> void:
	var b: BiomeDefinition = load("res://data/biomes/biome_stormcrag.tres")
	b.hunts = [load("res://data/hunts/raijins_echo.tres")] as Array[HuntDefinition]
	b.unlocked = true
	b.requires_hunt = &"nami"
	b.expedition_scene = "res://scenes/main/expedition_stormcrag.tscn"
	b.locked_note = "defeat Nami to unlock"
	_save(b, "res://data/biomes/biome_stormcrag.tres")
