class_name GameSettings
extends RefCounted
## Player-facing comfort / readability options (Phase 9 accessibility pass), saved in
## user://settings.cfg. Static so any system can read them without a scene reference.
##   screen_shake       - camera shake on hits and boss slams (off for motion-sensitive players)
##   bold_warnings      - attack/hazard warning zones drawn brighter and with a thicker rim
##   quality            - graphics preset: "auto", "low", "medium" or "high" (QualityProfile)
##   master/music/sfx_volume - 0..1 linear, applied to the audio buses

const DEFAULT_PATH := "user://settings.cfg"
## Every telegraph/hazard warning material (shader area_warning.gdshader, uniform `boost`).
const WARNING_MATERIALS: Array[String] = [
	"res://data/materials/area_warning.tres", "res://data/materials/attack_warning.tres",
	"res://data/materials/snare_warning.tres", "res://data/materials/lava_warning.tres",
	"res://data/materials/vent_glow.tres", "res://data/materials/heat_shimmer.tres",
	"res://data/materials/poison_warning.tres", "res://data/materials/flood_warning.tres",
	"res://data/materials/gust_warning.tres", "res://data/materials/lightning_warning.tres",
]
const BOLD_BOOST := 1.8

static var path: String = DEFAULT_PATH
static var screen_shake: bool = true
static var bold_warnings: bool = false
static var quality: String = "auto"
static var master_volume: float = 1.0
static var music_volume: float = 0.7
static var sfx_volume: float = 1.0
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
		quality = String(cfg.get_value("graphics", "quality", "auto"))
		master_volume = float(cfg.get_value("audio", "master", 1.0))
		music_volume = float(cfg.get_value("audio", "music", 0.7))
		sfx_volume = float(cfg.get_value("audio", "sfx", 1.0))
	else:
		screen_shake = true
		bold_warnings = false
		quality = "auto"
		master_volume = 1.0
		music_volume = 0.7
		sfx_volume = 1.0
	apply()


static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("comfort", "screen_shake", screen_shake)
	cfg.set_value("readability", "bold_warnings", bold_warnings)
	cfg.set_value("graphics", "quality", quality)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.save(path)


static func set_screen_shake(on: bool) -> void:
	screen_shake = on
	save_settings()


static func set_bold_warnings(on: bool) -> void:
	bold_warnings = on
	save_settings()
	apply()


## Graphics preset choice ("auto" = QualityProfile.auto_tier()). Read without touching materials.
static func get_quality() -> String:
	if not _loaded:
		load_settings()
	return quality


static func set_quality(q: String) -> void:
	quality = q
	save_settings()


static func set_volume(bus: String, value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	match bus:
		"Master": master_volume = value
		"Music": music_volume = value
		"SFX": sfx_volume = value
	save_settings()
	apply_volumes()


## Push the volume settings into the audio buses (missing buses are ignored).
static func apply_volumes() -> void:
	for pair in [["Master", master_volume], ["Music", music_volume], ["SFX", sfx_volume], ["Ambience", sfx_volume]]:
		var idx := AudioServer.get_bus_index(pair[0])
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(float(pair[1]), 0.0001)))
			AudioServer.set_bus_mute(idx, float(pair[1]) <= 0.001)


## Push the readability settings into the shared warning materials. Godot frees a material
## nobody uses and reloads it fresh from disk later, so every scene that shows warnings calls
## this when it starts (PauseMenu in expeditions, HuntBoard in the dojo); the materials it
## uses are loaded by then and share the cached instance.
static func apply() -> void:
	apply_volumes()
	var boost := BOLD_BOOST if bold_warnings else 1.0
	for p in WARNING_MATERIALS:
		if ResourceLoader.exists(p):
			var m := load(p) as ShaderMaterial
			if m:
				m.set_shader_parameter("boost", boost)
