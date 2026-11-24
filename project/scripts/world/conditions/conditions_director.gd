class_name ConditionsDirector
extends Node
## Phase 13 part 4 (day/night & weather): applies an expedition's forecast (Conditions) on top of
## the jungle's JungleMood — sun, ambient, exposure, fog, sky colours, rain, wet ground, wind,
## lightning — ONCE at load. A mid-hunt weather turn changes fog, wetness and wind in a few steps
## (TURN_STEPS over TURN_SECONDS; one step on Low) and never touches the sky material, so there
## are no per-frame material writes (CLAUDE.md: Mali crash rule).
## Created by ExpeditionManager before the shader warm-up, so any rain it adds is warmed up.

signal weather_turned(weather: WeatherDefinition)

const TURN_STEPS := 10
const TURN_SECONDS := 30.0

## What the last expedition set (the renderer's global uniforms cannot be read back headless).
static var applied: Dictionary = {}

var forecast: Dictionary = {}
var time: TimeOfDay
var weather: WeatherDefinition
var turn: WeatherDefinition
var turn_at: float = 0.0
## Number of stepped changes made by a weather turn (tests: stays small, never per frame).
var turn_steps_done: int = 0
var turned: bool = false

var _level: Node
var _env: Environment
var _sun: DirectionalLight3D
var _atmos: BiomeAtmosphere
var _rain: RainFX
var _elapsed: float = 0.0
var _turn_t: float = -1.0
var _from: Dictionary = {}


## `level`: the jungle scene root ("Level"). An empty forecast = neutral (globals reset only).
func setup(level: Node, f: Dictionary) -> void:
	_level = level
	forecast = f
	var env_node := level.find_children("*", "WorldEnvironment", true, false)
	_env = (env_node[0] as WorldEnvironment).environment if not env_node.is_empty() else null
	var suns := level.find_children("*", "DirectionalLight3D", true, false)
	_sun = suns[0] as DirectionalLight3D if not suns.is_empty() else null
	var atmos := level.find_children("*", "BiomeAtmosphere", true, false)
	_atmos = atmos[0] as BiomeAtmosphere if not atmos.is_empty() else null
	var rains := level.find_children("*", "RainFX", true, false)
	_rain = rains[0] as RainFX if not rains.is_empty() else null
	time = f.get("time") as TimeOfDay
	weather = f.get("weather") as WeatherDefinition
	turn = f.get("turn") as WeatherDefinition
	turn_at = float(f.get("turn_at", 0.0))
	_set_globals(weather.wetness if weather else 0.0, weather.wind if weather else 1.0)
	if f.is_empty():
		applied.merge({"time": &"", "weather": &""}, true)
		set_process(false)
		return
	_apply_time()
	_apply_weather_once()
	applied.merge({"time": time.id if time else &"", "weather": weather.id if weather else &""}, true)
	CrashReport.note("conditions: %s" % Conditions.describe(f))
	set_process(turn != null)


func _set_globals(wet: float, wind: float) -> void:
	RenderingServer.global_shader_parameter_set(&"wetness", wet)
	RenderingServer.global_shader_parameter_set(&"wind_boost", wind)
	applied["wetness"] = wet
	applied["wind_boost"] = wind


func _apply_time() -> void:
	if time == null:
		return
	if _sun:
		_sun.light_color = _sun.light_color * time.sun_color
		_sun.light_energy *= time.sun_energy
		if time.sun_elevation >= 0.0:
			var yaw := _sun.global_rotation.y + deg_to_rad(time.sun_turn)
			_sun.global_rotation = Vector3(-deg_to_rad(time.sun_elevation), yaw, 0.0)
	if _env:
		_env.ambient_light_color *= time.ambient_color
		_env.ambient_light_energy *= time.ambient_energy
		_env.tonemap_exposure *= time.exposure
		_env.fog_light_color *= time.fog_color
		# The brightness slider scales these (QualityProfile.apply_brightness runs after this).
		_env.set_meta(&"base_exposure", _env.tonemap_exposure)
		_env.set_meta(&"base_ambient", _env.ambient_light_energy)
	_tint_sky(time.sky_zenith, time.sky_horizon, time.sky_glow, weather.sky if weather else 1.0)


## The sky is written once, here, at load (never during the hunt). The sky material is shared
## between expeditions, so its own colours are remembered and every tint starts from them.
func _tint_sky(zenith: Color, horizon: Color, glow: Color, darken: float) -> void:
	if _env == null or _env.sky == null or not _env.sky.sky_material is ShaderMaterial:
		return
	var sky := _env.sky.sky_material as ShaderMaterial
	for k in ["zenith", "horizon", "glow_tint"]:
		if not sky.has_meta(k):
			var v: Variant = sky.get_shader_parameter(k)
			sky.set_meta(k, v if v is Color else Color(v.x, v.y, v.z) if v is Vector3 else Color(1, 1, 1))
	var base_z := sky.get_meta("zenith") as Color
	var base_h := sky.get_meta("horizon") as Color
	var base_g := sky.get_meta("glow_tint") as Color
	sky.set_shader_parameter("zenith", base_z * zenith * darken)
	sky.set_shader_parameter("horizon", base_h * horizon * darken)
	sky.set_shader_parameter("glow_tint", base_g * glow)
	if _sun:
		sky.set_shader_parameter("moon_dir", _sun.global_basis.z)


func _apply_weather_once() -> void:
	if weather == null:
		return
	if _env:
		_env.fog_density *= weather.fog_density
		_env.fog_height_density *= weather.fog_height_density
		_env.fog_light_color *= weather.fog_color
	if _atmos and weather.lightning_interval != Vector2.ZERO:
		_atmos.lightning_interval = weather.lightning_interval
	var wants_rain := weather.rain > 0.0 or (turn != null and turn.rain > 0.0)
	if wants_rain and _rain == null:
		_rain = RainFX.new()
		_rain.name = "WeatherRain"
		_level.add_child(_rain)
	if _rain:
		_set_rain(weather.rain)


func _set_rain(amount: float) -> void:
	if _rain == null:
		return
	var on := amount > 0.0
	_rain.emitting = on
	_rain.visible = on  # Hidden (but present for the shader warm-up) until it rains.
	if on:
		_rain.amount = maxi(50, int(_rain.amount_high * QualityProfile.current().rain_scale * amount))


func _process(delta: float) -> void:
	_elapsed += delta
	if not turned and turn and _elapsed >= turn_at:
		_begin_turn()
	if _turn_t < 0.0:
		return
	_turn_t += delta
	var steps := 1 if QualityProfile.is_low() else TURN_STEPS
	var target_step := mini(int(_turn_t / (TURN_SECONDS / steps)) + 1, steps)
	while turn_steps_done < target_step:
		turn_steps_done += 1
		_step_turn(float(turn_steps_done) / steps)
	if turn_steps_done >= steps:
		_turn_t = -1.0
		weather = turn
		set_process(false)


func _begin_turn() -> void:
	turned = true
	_turn_t = 0.0
	if _env:
		_from = {"fog": _env.fog_density, "height": _env.fog_height_density}
	_from["wet"] = float(applied.get("wetness", 0.0))
	_from["wind"] = float(applied.get("wind_boost", 1.0))
	if turn.rain > 0.0:
		_set_rain(turn.rain)
	if _atmos and turn.lightning_interval != Vector2.ZERO:
		_atmos.lightning_interval = turn.lightning_interval
	CrashReport.note("weather turns: %s" % turn.display_name)
	weather_turned.emit(turn)


## One step of the turn (k = 0..1): fog, wetness and wind only — the sky stays as loaded.
func _step_turn(k: float) -> void:
	var w0 := weather if weather else turn
	if _env:
		var f_target := float(_from["fog"]) / maxf(w0.fog_density, 0.001) * turn.fog_density
		var h_target := float(_from["height"]) / maxf(w0.fog_height_density, 0.001) * turn.fog_height_density
		_env.fog_density = lerpf(float(_from["fog"]), f_target, k)
		_env.fog_height_density = lerpf(float(_from["height"]), h_target, k)
	_set_globals(lerpf(float(_from["wet"]), turn.wetness, k), lerpf(float(_from["wind"]), turn.wind, k))
