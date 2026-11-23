@tool
class_name FloraScatter
extends Node3D
## Scatters procedural vegetation, rocks, logs and ruins over a BiomeTerrain using MultiMeshes
## grouped into chunks (each chunk culls and fades out on its own: phone friendly).
## Deterministic for a given FloraConfig.seed. Generated children are not saved into the scene.

@export var terrain_path: NodePath
@export var config: FloraConfig
@export_group("Materials")
@export var grass_material: Material
@export var leaf_material: Material
@export var vine_material: Material
@export var bark_material: Material
@export var fungus_material: Material
@export var rock_material: Material
@export var stone_material: Material

var _terrain: BiomeTerrain
var _rng := RandomNumberGenerator.new()
## kind -> Vector2i chunk -> Array[Transform3D]
var _buckets: Dictionary = {}
var _tree_positions: Array[Vector3] = []
var _low: bool = false
var _preset: QualityPreset


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	for child in get_children():
		if child.owner == null:
			child.free()
	_terrain = get_node_or_null(terrain_path) as BiomeTerrain
	if _terrain == null or config == null:
		return
	if not _terrain.is_built():
		_terrain.rebuild()
	_rng.seed = config.seed
	_low = QualityProfile.is_low()
	_preset = QualityProfile.current()
	_buckets.clear()
	_tree_positions.clear()
	_place_trees()
	_place_ground_cover()
	_place_logs()
	_place_pillars()


func get_tree_positions() -> Array[Vector3]:
	return _tree_positions


# ---------------------------------------------------------------- placement

func _random_point() -> Vector2:
	var c := _terrain.config
	return Vector2(_rng.randf_range(c.min_corner.x + 2.0, c.max_corner.x - 2.0),
			_rng.randf_range(c.min_corner.y + 2.0, c.max_corner.y - 2.0))


func _density_ok(d: float) -> bool:
	var keep := lerpf(config.near_route_density, config.far_density,
			smoothstep(config.density_falloff_start, config.density_falloff_end, d))
	return _rng.randf() < keep


func _ground_transform(x: float, z: float, scale: float, align: float = 0.6) -> Transform3D:
	var n := _terrain.get_normal(x, z)
	var up := Vector3.UP.lerp(n, align).normalized()
	var basis := Basis(Vector3.UP, _rng.randf() * TAU)
	basis = Basis(Quaternion(Vector3.UP, up)) * basis
	return Transform3D(basis.scaled(Vector3.ONE * scale), Vector3(x, _terrain.get_height_interpolated(x, z), z))


func _add(kind: String, t: Transform3D) -> void:
	if not _buckets.has(kind):
		_buckets[kind] = {}
	var chunk := Vector2i(floori(t.origin.x / config.chunk_size), floori(t.origin.z / config.chunk_size))
	var per_chunk: Dictionary = _buckets[kind]
	if not per_chunk.has(chunk):
		per_chunk[chunk] = []
	(per_chunk[chunk] as Array).append(t)


func _place_trees() -> void:
	var cfg := config
	var jungle_meshes: Array[ArrayMesh] = []
	var dead_meshes: Array[ArrayMesh] = []
	# Leaf cards around canopies (Medium/High); made once from this jungle's canopy material.
	var cards: Material = Cc0Surfaces.leaf_cards_for(leaf_material) if QualityProfile.current().leaf_cards else null
	for v in cfg.tree_variants:
		var vr := RandomNumberGenerator.new()
		vr.seed = cfg.seed * 31 + v
		jungle_meshes.append(ProceduralMeshes.jungle_tree(vr, bark_material, leaf_material, vine_material, cards))
		dead_meshes.append(ProceduralMeshes.dead_tree(vr, bark_material, vine_material))
	var jungle_xf: Array = []
	var dead_xf: Array = []
	for v in cfg.tree_variants:
		jungle_xf.append([])
		dead_xf.append([])
	var placed := 0
	var attempts := 0
	var tree_scale := _preset.tree_density
	var jungle_count := int(cfg.jungle_tree_count * tree_scale)
	var total := jungle_count + int(cfg.dead_tree_count * tree_scale)
	while placed < total and attempts < total * 40:
		attempts += 1
		var p := _random_point()
		var d := _terrain.route_distance(p.x, p.y)
		if d < cfg.tree_route_clearance or _terrain.is_in_gorge(p.y, 3.0):
			continue
		if 1.0 - _terrain.get_normal(p.x, p.y).y > 0.5 or not _density_ok(d * 0.6):
			continue
		var too_close := false
		for other in _tree_positions:
			if Vector2(other.x, other.z).distance_to(p) < 5.5:
				too_close = true
				break
		if too_close:
			continue
		var is_dead := placed >= jungle_count
		var scale := _rng.randf_range(0.8, 1.25)
		var t := _ground_transform(p.x, p.y, scale, 0.0)
		t.origin.y -= 0.3
		var variant := _rng.randi_range(0, cfg.tree_variants - 1)
		if is_dead:
			dead_xf[variant].append(t)
		else:
			jungle_xf[variant].append(t)
		_tree_positions.append(t.origin)
		if d < cfg.tree_collision_distance:
			_add_trunk_collision(t.origin, (0.6 if is_dead else 1.0) * scale)
		placed += 1
	for v in cfg.tree_variants:
		_spawn_multimesh("JungleTrees%d" % v, jungle_meshes[v], jungle_xf[v], 0.0, true)
		_spawn_multimesh("DeadTrees%d" % v, dead_meshes[v], dead_xf[v], 0.0, true)


func _add_trunk_collision(at: Vector3, radius: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 8.0
	col.shape = shape
	body.position = at + Vector3.UP * 4.0
	body.add_child(col)
	add_child(body)


func _place_ground_cover() -> void:
	var cfg := config
	var k := _preset.flora_density
	_scatter("Grass", int(cfg.grass_count * k), 2.2, 0.8, 1.4)
	_scatter("Fern", int(cfg.fern_count * k), 3.5, 0.7, 1.5)
	_scatter("Broadleaf", int(cfg.broadleaf_count * k), 4.5, 0.8, 1.6)
	_scatter("Rock", int(cfg.rock_count * k), 3.5, 0.4, 2.2, 0.85)
	# Mushrooms: half hug tree roots, half are scattered along the route edges.
	for i in int(cfg.mushroom_count * k):
		var kind := "Mushroom%d" % (i % cfg.mushroom_glows.size())
		var p: Vector2
		if i % 2 == 0 and not _tree_positions.is_empty():
			var tree := _tree_positions[_rng.randi_range(0, _tree_positions.size() - 1)]
			var ang := _rng.randf() * TAU
			p = Vector2(tree.x, tree.z) + Vector2(cos(ang), sin(ang)) * _rng.randf_range(1.2, 3.5)
		else:
			p = _random_point()
			if not _density_ok(_terrain.route_distance(p.x, p.y) * 1.5):
				continue
		if _terrain.is_in_gorge(p.y, 1.0) or _terrain.route_distance(p.x, p.y) < 3.0:
			continue
		_add(kind, _ground_transform(p.x, p.y, _rng.randf_range(0.7, 1.6)))
	var meshes := {
		"Grass": ProceduralMeshes.grass_clump(_variant_rng(1), grass_material),
		"Fern": ProceduralMeshes.fern(_variant_rng(2), grass_material),
		"Broadleaf": ProceduralMeshes.broadleaf(_variant_rng(3), leaf_material),
		"Rock": ProceduralMeshes.rock(_variant_rng(4), rock_material),
	}
	for i in cfg.mushroom_glows.size():
		meshes["Mushroom%d" % i] = ProceduralMeshes.mushroom_cluster(_variant_rng(10 + i), cfg.mushroom_glows[i], fungus_material)
	for kind: String in _buckets.keys():
		var draw := cfg.rock_draw_distance if kind == "Rock" else cfg.ground_cover_draw_distance
		draw *= _preset.draw_distance_scale
		var per_chunk: Dictionary = _buckets[kind]
		for chunk: Vector2i in per_chunk.keys():
			_spawn_multimesh("%s_%d_%d" % [kind, chunk.x, chunk.y], meshes[kind], per_chunk[chunk], draw, kind == "Rock")


func _scatter(kind: String, count: int, min_route: float, min_scale: float, max_scale: float, align: float = 0.6) -> void:
	for i in count:
		var p := _random_point()
		var d := _terrain.route_distance(p.x, p.y)
		if d < min_route or _terrain.is_in_gorge(p.y, 0.5):
			continue
		if 1.0 - _terrain.get_normal(p.x, p.y).y > config.max_ground_slope or not _density_ok(d):
			continue
		_add(kind, _ground_transform(p.x, p.y, _rng.randf_range(min_scale, max_scale), align))


func _place_logs() -> void:
	for i in config.log_count:
		var p := _random_point()
		var d := _terrain.route_distance(p.x, p.y)
		if d < 7.0 or d > 35.0 or _terrain.is_in_gorge(p.y, 4.0):
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = ProceduralMeshes.log_mesh(_variant_rng(100 + i), bark_material)
		mi.position = Vector3(p.x, _terrain.get_height_interpolated(p.x, p.y) - 0.15, p.y)
		mi.rotation.y = _rng.randf() * TAU
		add_child(mi)


func _place_pillars() -> void:
	# Ruins line the route edges, like the remains of an old processional way.
	var placed := 0
	var tries := 0
	while placed < config.pillar_count and tries < config.pillar_count * 30:
		tries += 1
		var z := _rng.randf_range(-105.0, 20.0)
		if _terrain.is_in_gorge(z, 3.0):
			continue
		var x := (_rng.randf_range(7.5, 14.0)) * (1.0 if _rng.randf() < 0.5 else -1.0)
		if _terrain.route_distance(x, z) < 6.5 or _in_clearing(x, z):
			continue
		var radius := _rng.randf_range(0.45, 0.8)
		var height := _rng.randf_range(1.5, 6.5)
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var base_y := _terrain.get_height_interpolated(x, z) - 0.3
		body.position = Vector3(x, base_y, z)
		var mi := MeshInstance3D.new()
		mi.mesh = ProceduralMeshes.broken_pillar(_variant_rng(200 + placed), radius, height, stone_material)
		body.add_child(mi)
		var col := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		col.shape = shape
		col.position.y = height * 0.5
		body.add_child(col)
		# Some pillars have toppled.
		if _rng.randf() < 0.3:
			body.rotation = Vector3(deg_to_rad(_rng.randf_range(60, 85)), _rng.randf() * TAU, 0)
			body.position.y += radius * 0.6
		add_child(body)
		placed += 1


func _in_clearing(x: float, z: float) -> bool:
	for c in _terrain.config.clearings:
		if Vector2(x, z).distance_to(Vector2(c.x, c.y)) < c.z + 1.5:
			return true
	return false


func _variant_rng(offset: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = config.seed * 7 + offset
	return r


func _spawn_multimesh(node_name: String, mesh: Mesh, transforms: Array, draw_distance: float, shadows: bool) -> void:
	if transforms.is_empty():
		return
	# Visibility range is measured from the node origin, so centre each chunk node on its contents.
	var centre := Vector3.ZERO
	for t: Transform3D in transforms:
		centre += t.origin
	centre /= transforms.size()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		var t: Transform3D = transforms[i]
		t.origin -= centre
		mm.set_instance_transform(i, t)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.position = centre
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if draw_distance > 0.0:
		mmi.visibility_range_end = draw_distance
		mmi.visibility_range_end_margin = 8.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(mmi)
