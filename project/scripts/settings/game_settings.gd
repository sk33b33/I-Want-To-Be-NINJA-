class_name GameSettings
extends RefCounted
## Player-facing comfort / readability options (Phase 9 accessibility pass), saved in
## user://settings.cfg. Static so any system can read them without a scene reference.
##   screen_shake       - camera shake on hits and boss slams (off for motion-sensitive players)
##   bold_warnings      - attack/hazard warning zones drawn brighter and with a thicker rim

const DEFAULT_PATH := "user://settings.cfg"
## Every telegraph/hazard warning material (shader area_warning.gdshader, uniform `boost`).
const WARNING_MATERIALS: Array[String] = [
	"res://data/materials/area_warning.tres", "res://data/materials/attack_warning.tres",
	"res://data/materials/snare_warning.tres", "res://data/materials/lava_warning.tres",
	"res://data/materials/vent_glow.tres", "res://data/materials/heat_shimmer.tres",
	"res://data/materials/poison_warning.tres", "res://data/materials/flood_warning.tres",
]
const BOLD_BOOST := 1.8

static var path: String = DEFAULT_PATH
static var screen_shake: bool = true
static var bold_warnings: bool = false
static var _loaded: bool = false


## Load once per run, and (re)apply to the warning materials of the scene that is starting.
static func ensure_loaded() -> void:
	if not _loaded:
		load_settings()
	else:
		apply()


static func load_settings() -> void:
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		screen_shake = bool(cfg.get_value("comfort", "screen_shake", true))
		bold_warnings = bool(cfg.get_value("readability", "bold_warnings", false))
	else:
		screen_shake = true
		bold_warnings = false
	apply()


static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("comfort", "screen_shake", screen_shake)
	cfg.set_value("readability", "bold_warnings", bold_warnings)
	cfg.save(path)


static func set_screen_shake(on: bool) -> void:
	screen_shake = on
	save_settings()


static func set_bold_warnings(on: bool) -> void:
	bold_warnings = on
	save_settings()
	apply()


## Push the readability settings into the shared warning materials. Godot frees a material
## nobody uses and reloads it fresh from disk later, so every scene that shows warnings calls
## this when it starts (PauseMenu in expeditions, HuntBoard in the dojo); the materials it
## uses are loaded by then and share the cached instance.
static func apply() -> void:
	var boost := BOLD_BOOST if bold_warnings else 1.0
	for p in WARNING_MATERIALS:
		if ResourceLoader.exists(p):
			var m := load(p) as ShaderMaterial
			if m:
				m.set_shader_parameter("boost", boost)
