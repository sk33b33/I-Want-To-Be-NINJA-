class_name WeaponTrail
extends MeshInstance3D
## Slash trail for one blade (owner request): a fading ribbon traced by the blade's guard and tip
## during the swing of a light or heavy attack (PlayerCombat.swing_active()). Built every frame
## with ImmediateMesh in world space; unshaded additive vertex-colour material (gl_compatibility
## safe). Width/brightness per attack (AttackDefinition.trail_*), colour from the blade element.

var config: TrailConfig
var blade: Node3D
var combat: PlayerCombat
## Vertices written last frame (tests / debugging; the dummy renderer keeps no mesh data).
var last_vertex_count: int = 0
## Width multiplier of the swing being drawn (1 = light).
var current_width: float = 1.0
var current_color: Color = Color.WHITE

var _samples: Array[Dictionary] = []  # {a: Vector3, b: Vector3, t: float}
var _imesh := ImmediateMesh.new()
var _time: float = 0.0


func setup(blade_node: Node3D, combat_node: PlayerCombat, cfg: TrailConfig) -> void:
	blade = blade_node
	combat = combat_node
	config = cfg
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _imesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = false
	material_override = mat


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
	_rebuild()


func _color() -> Color:
	var el := combat.blade_element
	return config.element_colors.get(el, config.color) if el != &"" else config.color


func _rebuild() -> void:
	_imesh.clear_surfaces()
	last_vertex_count = 0
	if _samples.size() < 2:
		return
	var subdiv := config.low_subdivisions if QualityProfile.is_low() else config.subdivisions
	var pts_a: Array[Vector3] = []
	var pts_b: Array[Vector3] = []
	var ages: Array[float] = []
	for i in _samples.size() - 1:
		var s0 := _samples[maxi(i - 1, 0)]
		var s1 := _samples[i]
		var s2 := _samples[i + 1]
		var s3 := _samples[mini(i + 2, _samples.size() - 1)]
		for k in subdiv + 1:
			var u := float(k) / float(subdiv + 1)
			pts_a.append((s1["a"] as Vector3).cubic_interpolate(s2["a"], s0["a"], s3["a"], u))
			pts_b.append((s1["b"] as Vector3).cubic_interpolate(s2["b"], s0["b"], s3["b"], u))
			ages.append(_time - lerpf(s1["t"], s2["t"], u))
	pts_a.append(_samples[-1]["a"])
	pts_b.append(_samples[-1]["b"])
	ages.append(_time - float(_samples[-1]["t"]))
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in pts_a.size():
		var fade := clampf(1.0 - ages[i] / config.lifetime, 0.0, 1.0)
		# Additive + scene glow: keep it a translucent streak, brightest at the tip, fading to
		# nothing at the guard and at the tail.
		var c := current_color
		_imesh.surface_set_color(Color(c.r, c.g, c.b, fade * fade * config.base_alpha))
		_imesh.surface_add_vertex(pts_a[i])
		_imesh.surface_set_color(Color(c.r, c.g, c.b, fade * config.tip_alpha))
		_imesh.surface_add_vertex(pts_b[i])
	_imesh.surface_end()
	last_vertex_count = pts_a.size() * 2
