class_name BiomeAtmosphere
extends Node3D
## Mood layer for a biome: distant lightning flicker, drifting ground mist, cold light shafts and
## waterfalls into the gorge. Values are scene data (edit on the node in the inspector).

@export var terrain_path: NodePath
@export var sun_path: NodePath
@export var environment_path: NodePath
@export var seed: int = 555

## Lighting & mood (art pass stage 3), applied once in _ready. Null = keep the scene's values.
@export var mood: JungleMood

@export_group("Lightning")
@export var lightning_interval: Vector2 = Vector2(9.0, 24.0)
@export var lightning_sun_boost: float = 1.6
@export var lightning_sky_flash: float = 0.9

@export_group("Mist")
@export var mist_material: Material
@export var mist_cards: int = 70
@export var mist_size: Vector2 = Vector2(14, 4)

@export_group("Light shafts")
@export var shaft_material: Material
## x, z, tilt-degrees for each shaft.
@export var shafts: Array[Vector3] = [Vector3(13, -4, 14), Vector3(-14, -24, -12), Vector3(14, -78, 10), Vector3(-12, -96, -16)]

@export_group("Waterfalls")
@export var waterfall_material: Material
@export var water_material: Material
## x, z (cliff edge), width of each waterfall.
@export var waterfalls: Array[Vector3] = [Vector3(-26, -50.5, 7), Vector3(31, -70.5, 9)]
@export var river_height: float = -21.0
@export var stream_water_height: float = -0.35

var _terrain: BiomeTerrain
var _sun: DirectionalLight3D
var _sky_material: ShaderMaterial
var _sun_base_energy: float = 1.0
var _rng := RandomNumberGenerator.new()
var _next_flash: float = 5.0
var _sky_flash_value: float = -1.0
var _sky_flash_allowed: bool = true
## How many times the sky material was changed (tests: must stay rare).
var sky_updates: int = 0
var _flash_t: float = -1.0


func _ready() -> void:
	_sky_flash_allowed = QualityProfile.current().sky_flash
	_rng.seed = seed
	_terrain = get_node_or_null(terrain_path) as BiomeTerrain
	_sun = get_node_or_null(sun_path) as DirectionalLight3D
	var env_node := get_node_or_null(environment_path) as WorldEnvironment
	apply_mood(env_node.environment if env_node else null)
	if _sun:
		_sun_base_energy = _sun.light_energy
	if env_node and env_node.environment and env_node.environment.sky:
		_sky_material = env_node.environment.sky.sky_material as ShaderMaterial
	if _terrain == null:
		return
	if not _terrain.is_built():
		_terrain.rebuild()
	_build_water()
	_build_waterfalls()
	mist_cards = int(mist_cards * QualityProfile.current().mist_scale)
	_build_mist()
	_build_shafts()


## Apply `mood` to the environment, sun, light shafts and water (once; values are absolute).
## Runs before QualityProfile.apply_brightness(), and records the brightness base values itself so
## the slider always scales this mood's exposure/ambient.
func apply_mood(env: Environment) -> void:
	if mood == null:
		return
	CrashReport.note("mood: %s" % mood.resource_path.get_file())
	if _sun:
		_sun.light_color = mood.sun_color
		_sun.light_energy = mood.sun_energy
	if env:
		env.ambient_light_color = mood.ambient_color
		env.ambient_light_energy = mood.ambient_energy
		env.tonemap_exposure = mood.exposure
		env.set_meta(&"base_exposure", mood.exposure)
		env.set_meta(&"base_ambient", mood.ambient_energy)
		env.fog_light_color = mood.fog_color
		env.fog_density = mood.fog_density
		env.fog_sky_affect = mood.fog_sky_affect
		env.fog_height = mood.fog_height
		env.fog_height_density = mood.fog_height_density
		env.fog_sun_scatter = mood.fog_sun_scatter
		env.adjustment_enabled = true
		env.adjustment_saturation = mood.saturation
		env.adjustment_contrast = mood.contrast
		env.adjustment_color_correction = mood.grade_curve() if QualityProfile.current().color_grade_lut else null
	if shaft_material is ShaderMaterial:
		shaft_material.set_shader_parameter("color", mood.shaft_color)
		shaft_material.set_shader_parameter("strength", mood.shaft_strength)
	if water_material is ShaderMaterial:
		water_material.set_shader_parameter("shallow", mood.water_shallow)
		water_material.set_shader_parameter("deep", mood.water_deep)


func _process(delta: float) -> void:
	_next_flash -= delta
	if _next_flash <= 0.0:
		_flash_t = 0.0
		_next_flash = _rng.randf_range(lightning_interval.x, lightning_interval.y)
		CrashReport.note("lightning flash (sky %s)" % ("on" if _sky_flash_allowed else "off"))
	var flash := 0.0
	if _flash_t >= 0.0:
		_flash_t += delta
		# Double flicker: two quick pulses then fade.
		flash = maxf(exp(-_flash_t * 14.0), exp(-absf(_flash_t - 0.22) * 18.0) * 0.8)
		if _flash_t > 1.0:
			_flash_t = -1.0
	# Only touch the sky when the value changes: every change to the sky material makes the
	# renderer re-bake the sky (on phones: a likely cause of the Mali GPU crashes). Phones keep
	# the sky still and flash through the moonlight only (QualityPreset.sky_flash).
	var sky_value := flash * lightning_sky_flash if _sky_flash_allowed else 0.0
	if _sky_material and not is_equal_approx(sky_value, _sky_flash_value):
		_sky_flash_value = sky_value
		_sky_material.set_shader_parameter("flash", sky_value)
		sky_updates += 1
	if _sun:
		_sun.light_energy = _sun_base_energy * (1.0 + flash * lightning_sun_boost)


func _build_water() -> void:
	var c := _terrain.config
	var width := c.max_corner.x - c.min_corner.x
	_water_plane("StreamWater", Vector3(0, stream_water_height, c.stream_z), Vector2(width, c.stream_half_width * 2.0 + 1.0))
	var gorge_len := c.gorge_start_z - c.gorge_end_z
	_water_plane("GorgeRiver", Vector3(0, river_height, (c.gorge_start_z + c.gorge_end_z) * 0.5), Vector2(width, gorge_len))


func _water_plane(node_name: String, at: Vector3, size: Vector2) -> void:
	var plane := PlaneMesh.new()
	plane.size = size
	plane.subdivide_width = 0
	plane.material = water_material
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = plane
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_waterfalls() -> void:
	for i in waterfalls.size():
		var w := waterfalls[i]
		var top := maxf(_terrain.get_height(w.x, w.y + (1.5 if w.y > -60.0 else -1.5)), 2.0)
		var height := top - river_height
		var quad := QuadMesh.new()
		quad.size = Vector2(w.z, height)
		quad.material = waterfall_material
		var mi := MeshInstance3D.new()
		mi.name = "Waterfall%d" % i
		mi.mesh = quad
		mi.position = Vector3(w.x, river_height + height * 0.5, w.y)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		# Spray at the bottom.
		var spray := CPUParticles3D.new()
		spray.name = "WaterfallSpray%d" % i
		var q := QuadMesh.new()
		q.size = Vector2(2.5, 2.5)
		q.material = mist_material
		spray.mesh = q
		spray.amount = 16
		spray.lifetime = 3.0
		spray.preprocess = 3.0
		spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		spray.emission_box_extents = Vector3(w.z * 0.5, 0.5, 1.0)
		spray.direction = Vector3.UP
		spray.spread = 40.0
		spray.gravity = Vector3(0, 0.3, 0)
		spray.initial_velocity_min = 0.5
		spray.initial_velocity_max = 1.5
		spray.position = Vector3(w.x, river_height + 0.5, w.y)
		add_child(spray)


func _build_mist() -> void:
	var quad := QuadMesh.new()
	quad.size = mist_size
	quad.center_offset = Vector3(0, mist_size.y * 0.35, 0)
	quad.material = mist_material
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = mist_cards
	for i in mist_cards:
		var x := _rng.randf_range(-35.0, 35.0)
		var z := _rng.randf_range(-115.0, 30.0)
		var y := _terrain.get_height(x, z) if not _terrain.is_in_gorge(z) else _rng.randf_range(-12.0, -2.0)
		var s := _rng.randf_range(0.7, 1.6)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(s, s * 0.8, s)), Vector3(x, y, z)))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "GroundMist"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _build_shafts() -> void:
	for i in shafts.size():
		var s := shafts[i]
		var quad := QuadMesh.new()
		quad.size = Vector2(mood.shaft_width if mood else 2.5, 26.0)
		quad.material = shaft_material
		for k in 2:  # Two crossed planes read as a volume.
			var mi := MeshInstance3D.new()
			mi.name = "LightShaft%d_%d" % [i, k]
			mi.mesh = quad
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position = Vector3(s.x, _terrain.get_height(s.x, s.y) + 12.0, s.y)
			mi.rotation = Vector3(0, deg_to_rad(90.0 * k + 20.0), deg_to_rad(s.z))
			add_child(mi)
