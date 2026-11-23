@tool
class_name QualityProfile
extends RefCounted
## Picks and applies the graphics preset (Phase 11). The choice comes from, in order:
##   1. `-- --quality=low|medium|high` (or the older `-- --low-quality`) on the command line,
##   2. the pause-menu setting (GameSettings.quality) unless it is "auto",
##   3. auto: LOW on phones (Android), HIGH on PC.
## Budgets live in data/quality/<id>.tres (QualityPreset).

const TIERS: Array[StringName] = [&"low", &"medium", &"high"]
const PRESET_DIR := "res://data/quality/"

static var _override: StringName = &""  # Tests force a tier with force_tier().


static func tier() -> StringName:
	if Engine.is_editor_hint():
		return &"high"
	if _override != &"":
		return _override
	for arg in OS.get_cmdline_user_args():
		if arg == "--low-quality":
			return &"low"
		if arg.begins_with("--quality="):
			var t := StringName(arg.get_slice("=", 1))
			if TIERS.has(t):
				return t
	var chosen := StringName(GameSettings.get_quality())
	if TIERS.has(chosen):
		return chosen
	return auto_tier()


static func auto_tier() -> StringName:
	return &"low" if OS.has_feature("mobile") else &"high"


static func current() -> QualityPreset:
	return load(PRESET_DIR + String(tier()) + ".tres") as QualityPreset


static func is_low() -> bool:
	return tier() == &"low"


## Test hook: pin a tier (&"" to clear).
static func force_tier(t: StringName) -> void:
	_override = t


## Apply the scene-wide parts of the preset (called by ExpeditionManager when an expedition
## starts). World builders (terrain, flora, atmosphere, rain) read the preset themselves.
static func apply_to_scene(root: Node) -> void:
	var q := current()
	var vp := root.get_viewport()
	if vp:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = q.render_scale
	for n in root.find_children("*", "WorldEnvironment", true, false):
		var env := (n as WorldEnvironment).environment
		if env:
			env.glow_enabled = env.glow_enabled and q.glow
			if not q.sky_reflections:
				env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
				if env.sky:
					env.sky.radiance_size = Sky.RADIANCE_SIZE_32
	apply_brightness(root)
	apply_surface_detail(q)
	for n in root.find_children("*", "DirectionalLight3D", true, false):
		var sun := n as DirectionalLight3D
		sun.shadow_enabled = sun.shadow_enabled and q.moon_shadows
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if q.shadow_splits == 1 \
				else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_max_distance = minf(sun.directional_shadow_max_distance, q.shadow_distance)
	for n in root.find_children("*", "OmniLight3D", true, false):
		var l := n as OmniLight3D
		l.distance_fade_enabled = true
		l.distance_fade_begin = q.light_fade_distance
		l.distance_fade_length = 6.0
		l.shadow_enabled = false


## What apply_surface_detail() last set (the renderer cannot be read back when headless).
static var surface_detail: Dictionary = {}


## Surface detail switches for every CC0-textured material at once (global shader uniforms,
## so no per-material writes; set once per expedition, never per frame).
static func apply_surface_detail(q: QualityPreset) -> void:
	surface_detail = {&"detail_normals": q.detail_normals, &"anti_tile": q.anti_tile}
	RenderingServer.global_shader_parameter_set(&"detail_normals", q.detail_normals)
	RenderingServer.global_shader_parameter_set(&"anti_tile", q.anti_tile)


## Picture brightness (GameSettings.brightness) on every WorldEnvironment under `root`. The
## level's own values are remembered, so changing the slider never compounds.
static func apply_brightness(root: Node) -> void:
	var b := GameSettings.brightness
	for n in root.find_children("*", "WorldEnvironment", true, false):
		var env := (n as WorldEnvironment).environment
		if env == null:
			continue
		if not env.has_meta(&"base_exposure"):
			env.set_meta(&"base_exposure", env.tonemap_exposure)
			env.set_meta(&"base_ambient", env.ambient_light_energy)
		env.tonemap_exposure = float(env.get_meta(&"base_exposure")) * b
		env.ambient_light_energy = float(env.get_meta(&"base_ambient")) * b
