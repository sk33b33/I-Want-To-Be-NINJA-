class_name FaunaSpawner
extends Node3D
## Spawns the biome's ambient wildlife from a FaunaConfig: bat flocks, frogs, lurking eyes and
## firefly swarms. Finds the player through the "player" group. Runtime only (not in the editor).

@export var terrain_path: NodePath
@export var flora_path: NodePath
@export var config: FaunaConfig
@export var bat_material: Material
@export var frog_material: Material
@export var eye_material: Material
@export var firefly_material: Material

var _terrain: BiomeTerrain
var _rng := RandomNumberGenerator.new()
var _player: Node3D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_terrain = get_node_or_null(terrain_path) as BiomeTerrain
	if _terrain == null or config == null:
		return
	_rng.seed = config.seed
	_player = get_tree().get_first_node_in_group("player") as Node3D
	_spawn_bats()
	_spawn_frogs()
	_spawn_lurkers()
	_spawn_fireflies()


func _process(_delta: float) -> void:
	# The player may be added after the level; pick it up late and hand it to the critters.
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player:
			for child in get_children():
				if child is FrogCritter or child is LurkerEyes:
					child.set("player", _player)
	else:
		set_process(false)


func _spawn_bats() -> void:
	var mesh := ProceduralMeshes.bat(bat_material)
	for i in config.bat_flocks.size():
		var c := config.bat_flocks[i]
		var flock := BatFlock.new()
		flock.name = "BatFlock%d" % i
		flock.position = Vector3(c.x, _terrain.get_height(c.x, c.z) if not _terrain.is_in_gorge(c.z) else 0.0, c.z) + Vector3.UP * c.y
		add_child(flock)
		flock.setup(mesh, config.bats_per_flock, config.bat_orbit_radius, config.bat_speed, _rng)


func _spawn_frogs() -> void:
	var mesh := ProceduralMeshes.frog(frog_material)
	var placed := 0
	var tries := 0
	while placed < config.frog_count and tries < config.frog_count * 30:
		tries += 1
		var x := _rng.randf_range(-14.0, 14.0)
		var z := _rng.randf_range(-100.0, 20.0)
		var d := _terrain.route_distance(x, z)
		if _terrain.is_in_gorge(z, 2.0) or d < 2.0 or d > 12.0:
			continue
		var frog := FrogCritter.new()
		frog.name = "Frog%d" % placed
		frog.mesh = mesh
		frog.terrain = _terrain
		frog.player = _player
		frog.flee_radius = config.frog_flee_radius
		frog.hop_distance = config.frog_hop_distance
		frog.hop_time = config.frog_hop_time
		frog.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		frog.position = Vector3(x, _terrain.get_height_interpolated(x, z), z)
		frog.rotation.y = _rng.randf() * TAU
		add_child(frog)
		placed += 1


func _lurker_spot() -> Vector3:
	for i in 50:
		var x := _rng.randf_range(-45.0, 45.0)
		var z := _rng.randf_range(-110.0, 25.0)
		var d := _terrain.route_distance(x, z)
		if d >= config.lurker_distance.x and d <= config.lurker_distance.y and not _terrain.is_in_gorge(z, 2.0):
			return Vector3(x, _terrain.get_height(x, z) + _rng.randf_range(0.6, 2.2), z)
	return Vector3(40, 2, 0)


func _spawn_lurkers() -> void:
	var mesh := ProceduralMeshes.eye_pair(eye_material)
	for i in config.lurker_count:
		var eyes := LurkerEyes.new()
		eyes.name = "LurkerEyes%d" % i
		eyes.mesh = mesh
		eyes.player = _player
		eyes.vanish_radius = config.lurker_vanish_radius
		eyes.relocate = _lurker_spot
		eyes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eyes.position = _lurker_spot()
		add_child(eyes)


func _spawn_fireflies() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	quad.material = firefly_material
	var ramp := Gradient.new()
	ramp.set_color(0, Color(config.firefly_color, 0.0))
	ramp.set_color(1, Color(config.firefly_color, 0.0))
	ramp.add_point(0.3, Color(config.firefly_color, 1.0))
	ramp.add_point(0.7, Color(config.firefly_color, 1.0))
	for i in config.firefly_swarms:
		var z := _rng.randf_range(-105.0, 25.0)
		if _terrain.is_in_gorge(z, 1.0):
			z = _rng.randf_range(-45.0, 25.0)
		var x := _rng.randf_range(-12.0, 12.0)
		var p := CPUParticles3D.new()
		p.name = "Fireflies%d" % i
		p.mesh = quad
		p.amount = config.fireflies_per_swarm
		p.lifetime = 5.0
		p.preprocess = 5.0
		p.randomness = 1.0
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(6, 1.5, 6)
		p.direction = Vector3.UP
		p.spread = 180.0
		p.gravity = Vector3.ZERO
		p.initial_velocity_min = 0.1
		p.initial_velocity_max = 0.5
		p.angular_velocity_min = 0.0
		p.color_ramp = ramp
		p.position = Vector3(x, _terrain.get_height(x, z) + 1.5, z)
		add_child(p)
