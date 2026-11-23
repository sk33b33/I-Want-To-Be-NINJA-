class_name WeaponTrail
extends MeshInstance3D
## Slash trail for one blade (owner request): a fading ribbon traced by the blade's guard and tip
## during the swing of a light or heavy attack (PlayerCombat.swing_active()). The mesh is built
## ONCE; each frame only shader uniforms change (shaders/slash_trail.gdshader). The first version
## rebuilt an ImmediateMesh every frame, which crashed the Godot app on the owner's Android phone.
## Width/brightness per attack (AttackDefinition.trail_*), colour from the blade element.

var config: TrailConfig
var blade: Node3D
var combat: PlayerCombat
## Vertices written last frame (tests / debugging; the dummy renderer keeps no mesh data).
var last_vertex_count: int = 0
## Width multiplier of the swing being drawn (1 = light).
var current_width: float = 1.0
var current_color: Color = Color.WHITE

const MAX_POINTS := 32  # Must match slash_trail.gdshader.

var _samples: Array[Dictionary] = []  # {a: Vector3, b: Vector3, t: float}
var _material: ShaderMaterial
var _time: float = 0.0


func setup(blade_node: Node3D, combat_node: PlayerCombat, cfg: TrailConfig) -> void:
	blade = blade_node
	combat = combat_node
	config = cfg
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _build_strip()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shader moves the vertices anywhere in the world: never cull the trail by its mesh box.
	custom_aabb = AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000))
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/slash_trail.gdshader")
	_material.set_shader_parameter("tip_alpha", cfg.tip_alpha)
	_material.set_shader_parameter("base_alpha", cfg.base_alpha)
	material_override = _material
	visible = false


## A fixed strip of MAX_POINTS guard/tip pairs, built once. UV.x = point index, UV.y = 0/1.
static func _build_strip() -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in MAX_POINTS:
		for side in 2:
			verts.append(Vector3.ZERO)
			uvs.append(Vector2(i, side))
	for i in MAX_POINTS - 1:
		var a := i * 2
		idx.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


func sample_count() -> int:
	return _samples.size()


func _process(delta: float) -> void:
	if blade == null or combat == null or config == null:
		return
	_time += delta
	if combat.swing_active(config.lead, config.tail) and blade.is_visible_in_tree():
		var a := combat.current_attack
		current_width = a.trail_width
		current_color = _color() * a.trail_intensity
		var g := blade.global_transform
		var tip := g * Vector3(0, config.tip, 0)
		var base := g * Vector3(0, config.base, 0)
		# Heavier swings draw a wider band: extend it down the blade.
		base = tip.lerp(base, clampf(current_width, 0.5, 2.0))
		_samples.append({"a": base, "b": tip, "t": _time})
	while not _samples.is_empty() and _time - float(_samples[0]["t"]) > config.lifetime:
		_samples.pop_front()
	_upload()


func _color() -> Color:
	var el := combat.blade_element
	return config.element_colors.get(el, config.color) if el != &"" else config.color


## Smooth the recent samples (cubic) and send at most MAX_POINTS of them to the shader.
func _upload() -> void:
	last_vertex_count = 0
	if _samples.size() < 2:
		visible = false
		return
	var subdiv := config.low_subdivisions if QualityProfile.is_low() else config.subdivisions
	var pts_a := PackedVector3Array()
	var pts_b := PackedVector3Array()
	var fades := PackedFloat32Array()
	for i in _samples.size() - 1:
		var s0 := _samples[maxi(i - 1, 0)]
		var s1 := _samples[i]
		var s2 := _samples[i + 1]
		var s3 := _samples[mini(i + 2, _samples.size() - 1)]
		for k in subdiv + 1:
			var u := float(k) / float(subdiv + 1)
			pts_a.append((s1["a"] as Vector3).cubic_interpolate(s2["a"], s0["a"], s3["a"], u))
			pts_b.append((s1["b"] as Vector3).cubic_interpolate(s2["b"], s0["b"], s3["b"], u))
			fades.append(_fade(_time - lerpf(s1["t"], s2["t"], u)))
	pts_a.append(_samples[-1]["a"])
	pts_b.append(_samples[-1]["b"])
	fades.append(_fade(_time - float(_samples[-1]["t"])))
	# Keep the newest MAX_POINTS (the oldest are nearly faded anyway).
	var n := pts_a.size()
	if n > MAX_POINTS:
		pts_a = pts_a.slice(n - MAX_POINTS)
		pts_b = pts_b.slice(n - MAX_POINTS)
		fades = fades.slice(n - MAX_POINTS)
		n = MAX_POINTS
	pts_a.resize(MAX_POINTS)
	pts_b.resize(MAX_POINTS)
	fades.resize(MAX_POINTS)
	_material.set_shader_parameter("base_points", pts_a)
	_material.set_shader_parameter("tip_points", pts_b)
	_material.set_shader_parameter("fades", fades)
	_material.set_shader_parameter("point_count", n)
	_material.set_shader_parameter("trail_color", current_color)
	visible = true
	last_vertex_count = n * 2


func _fade(age: float) -> float:
	return clampf(1.0 - age / config.lifetime, 0.0, 1.0)
