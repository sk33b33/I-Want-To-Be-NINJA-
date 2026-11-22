@tool
class_name BiomeTerrain
extends Node3D
## Builds the biome's sculpted terrain mesh and matching HeightMapShape3D collision from a
## TerrainConfig. Other systems (flora, fauna) query it through get_height()/route_distance().
## Generated children have no owner, so they are rebuilt on load and never saved into the scene.

@export var config: TerrainConfig:
	set(value):
		config = value
		if is_inside_tree():
			rebuild()
@export var material: Material

var _heights: PackedFloat32Array = PackedFloat32Array()
var _width: int = 0
var _depth: int = 0
var _hill_noise := FastNoiseLite.new()
var _detail_noise := FastNoiseLite.new()
var _tint_noise := FastNoiseLite.new()
var _built: bool = false


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	for child in get_children():
		if child.owner == null:
			child.free()
	_built = false
	if config == null:
		return
	_setup_noise()
	_bake_heights()
	_build_mesh()
	_build_collision()
	_built = true


func is_built() -> bool:
	return _built


## Sculpted height at world X/Z (analytic; matches the mesh at vertices).
func get_height(x: float, z: float) -> float:
	var c := config
	var d := route_distance(x, z)
	var wild := _hill_noise.get_noise_2d(x, z) * c.hill_height
	wild += smoothstep(0.0, c.valley_wall_distance, d) * c.valley_wall_height \
			* (0.65 + 0.35 * _detail_noise.get_noise_2d(x * 0.2, z * 0.2))
	wild += _detail_noise.get_noise_2d(x, z) * c.detail_height
	var outside := smoothstep(c.corridor_half_width, c.corridor_half_width + c.corridor_blend, d)
	var h := lerpf(c.route_height, wild, outside)

	var stream_dist := absf(z - c.stream_z)
	if stream_dist < c.stream_half_width + 2.0:
		h -= c.stream_depth * (1.0 - smoothstep(c.stream_half_width - 1.0, c.stream_half_width + 2.0, stream_dist))

	var edge := minf(minf(x - c.min_corner.x, c.max_corner.x - x), minf(z - c.min_corner.y, c.max_corner.y - z))
	h += (1.0 - smoothstep(0.0, c.border_width, edge)) * c.border_height

	if z < c.gorge_start_z and z > c.gorge_end_z:
		h = c.gorge_depth
	return h


## Bilinear height from the baked grid (what the collision shape uses).
func get_height_interpolated(x: float, z: float) -> float:
	var fx := (x - config.min_corner.x) / config.cell_size
	var fz := (z - config.min_corner.y) / config.cell_size
	var ix := clampi(int(floor(fx)), 0, _width - 2)
	var iz := clampi(int(floor(fz)), 0, _depth - 2)
	var tx := clampf(fx - ix, 0.0, 1.0)
	var tz := clampf(fz - iz, 0.0, 1.0)
	var h00 := _heights[iz * _width + ix]
	var h10 := _heights[iz * _width + ix + 1]
	var h01 := _heights[(iz + 1) * _width + ix]
	var h11 := _heights[(iz + 1) * _width + ix + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func get_normal(x: float, z: float) -> Vector3:
	var e := config.cell_size
	var hx := get_height(x + e, z) - get_height(x - e, z)
	var hz := get_height(x, z + e) - get_height(x, z - e)
	return Vector3(-hx, 2.0 * e, -hz).normalized()


## Distance from the walkable route (segments and clearings), 0 inside the flat corridor centre.
func route_distance(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := INF
	var pts := config.route_points
	for i in range(0, pts.size() - 1, 2):
		best = minf(best, _segment_distance(p, pts[i], pts[i + 1]))
	for clearing in config.clearings:
		best = minf(best, maxf(0.0, p.distance_to(Vector2(clearing.x, clearing.y)) - clearing.z + config.corridor_half_width))
	return best


func is_in_gorge(z: float, margin: float = 0.0) -> bool:
	return z < config.gorge_start_z + margin and z > config.gorge_end_z - margin


func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _setup_noise() -> void:
	_hill_noise.seed = config.seed
	_hill_noise.frequency = config.hill_frequency
	_hill_noise.fractal_octaves = 4
	_detail_noise.seed = config.seed + 1
	_detail_noise.frequency = config.detail_frequency
	_detail_noise.fractal_octaves = 2
	_tint_noise.seed = config.seed + 2
	_tint_noise.frequency = 0.08


func _bake_heights() -> void:
	var size := config.max_corner - config.min_corner
	_width = int(round(size.x / config.cell_size)) + 1
	_depth = int(round(size.y / config.cell_size)) + 1
	_heights.resize(_width * _depth)
	for iz in _depth:
		for ix in _width:
			var x := config.min_corner.x + ix * config.cell_size
			var z := config.min_corner.y + iz * config.cell_size
			_heights[iz * _width + ix] = get_height(x, z)


func _grid_normal(ix: int, iz: int) -> Vector3:
	var l := _heights[iz * _width + maxi(ix - 1, 0)]
	var r := _heights[iz * _width + mini(ix + 1, _width - 1)]
	var d := _heights[maxi(iz - 1, 0) * _width + ix]
	var u := _heights[mini(iz + 1, _depth - 1) * _width + ix]
	return Vector3(l - r, 2.0 * config.cell_size, d - u).normalized()


func _build_mesh() -> void:
	# The render mesh may skip height samples (QualityPreset.terrain_mesh_step) to save triangles
	# on phones; the last row/column is always kept so the edges line up. Collision uses every sample.
	var step := QualityProfile.current().terrain_mesh_step if not Engine.is_editor_hint() else 1
	var xs := _sample_indices(_width, step)
	var zs := _sample_indices(_depth, step)
	var w := xs.size()
	var count := w * zs.size()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(count)
	normals.resize(count)
	colors.resize(count)
	for jz in zs.size():
		for jx in w:
			var ix: int = xs[jx]
			var iz: int = zs[jz]
			var i := jz * w + jx
			var x := config.min_corner.x + ix * config.cell_size
			var z := config.min_corner.y + iz * config.cell_size
			var h := _heights[iz * _width + ix]
			var n := _grid_normal(ix, iz)
			verts[i] = Vector3(x, h, z)
			normals[i] = n
			# Vertex colour = material blend weights read by terrain.gdshader:
			# r = rock (steep slopes, gorge walls), g = trodden mud (route), b = moss tint noise,
			# a = wetness (stream banks and low ground).
			var rock := smoothstep(0.55, 0.85, 1.0 - n.y)
			var path := 1.0 - smoothstep(1.5, config.corridor_half_width + 1.0, route_distance(x, z))
			var tint := _tint_noise.get_noise_2d(x, z) * 0.5 + 0.5
			var wet := 1.0 - smoothstep(0.0, config.stream_half_width + 4.0, absf(z - config.stream_z))
			wet = maxf(wet, 1.0 - smoothstep(-2.0, 0.5, h - config.route_height))
			colors[i] = Color(rock, path * (1.0 - rock), tint, wet)
	var indices := PackedInt32Array()
	indices.resize((w - 1) * (zs.size() - 1) * 6)
	var k := 0
	for jz in zs.size() - 1:
		for jx in w - 1:
			var a := jz * w + jx
			var b := a + 1
			var c := a + w
			var d := c + 1
			indices[k] = a; indices[k + 1] = b; indices[k + 2] = c
			indices[k + 3] = b; indices[k + 4] = d; indices[k + 5] = c
			k += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if material:
		mesh.surface_set_material(0, material)
	var mi := MeshInstance3D.new()
	mi.name = "TerrainMesh"
	mi.mesh = mesh
	add_child(mi)


static func _sample_indices(n: int, step: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var i := 0
	while i < n - 1:
		out.append(i)
		i += maxi(step, 1)
	out.append(n - 1)
	return out


## Triangles in the render mesh (for budgets/tests).
func render_triangle_count() -> int:
	var mi := get_node_or_null("TerrainMesh") as MeshInstance3D
	if mi == null or mi.mesh == null:
		return 0
	return (mi.mesh as ArrayMesh).surface_get_array_index_len(0) / 3


func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := HeightMapShape3D.new()
	shape.map_width = _width
	shape.map_depth = _depth
	shape.map_data = _heights
	var col := CollisionShape3D.new()
	col.shape = shape
	col.scale = Vector3(config.cell_size, 1.0, config.cell_size)
	var centre := (config.min_corner + config.max_corner) * 0.5
	body.position = Vector3(centre.x, 0.0, centre.y)
	body.add_child(col)
	add_child(body)
