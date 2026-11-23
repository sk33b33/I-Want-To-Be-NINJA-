class_name Cc0Surfaces
extends RefCounted
## Which CC0 texture (assets/textures/cc0, ledger in assets/ASSET_LEDGER.md) each surface
## shader uses. One shared set for all four jungles: the textures give detail, each material's
## palette colours give the jungle its look. Used by tools/generate_visual_pass.gd (so a re-run
## keeps the textures) and tools/apply_cc0_textures.gd (patches existing materials).

const DIR := "res://assets/textures/cc0/"

## shader file name -> {uniform: texture base name ("<name>_albedo.jpg" / "<name>_normal.jpg")}.
const BY_SHADER := {
	"terrain": {"ground": "forest_floor", "path": "mud_path", "rock": "cliff_rock"},
	"stone": {"tt": "stone_blocks"},
	"basalt": {"tt": "cliff_rock"},
	"painted": {"tt": "cliff_rock"},
}

## Per-material overrides by file name (reed rafts use the basalt shader but are woven reed).
const BY_MATERIAL := {
	"reed": {"tt": "bark"},
	"bark_vertex": {"tt": "bark"},
	"dark_wood": {"tt": "bark"},
}

## Per-shader / per-material tuning (material file name wins over shader name).
const TUNING := {
	"stone": {"tt_tile": 4.0, "tt_strength": 0.7, "tt_normal_strength": 0.6, "seams": 0.0, "noise_amount": 0.25},
	"basalt": {"tt_tile": 5.0, "tt_strength": 1.0, "noise_amount": 0.3},
	"bark_vertex": {"tt_tile": 1.3, "tt_strength": 1.25, "tt_normal_strength": 1.4},
	"dark_wood": {"tt_tile": 1.6, "tt_strength": 0.8},
	"reed": {"tt_tile": 1.2},
	"rock_vertex": {"tt_tile": 3.0, "tt_strength": 0.8},
}

## Canopy/broadleaf foliage materials (foliage.gdshader): leaf-spray detail on canopy cores and
## veins on broadleaf blades (art pass stage 2). File name -> extra parameters.
const LEAF_FOLIAGE := {
	"foliage_leaf": {}, "leaf_scorched": {}, "leaf_crag": {},
	# Moonfen's bioluminescence (concept art: cyan and magenta glow in deep blue) — stage 3.
	"leaf_fen": {"glow_color": Color(0.1, 0.9, 1.0) * 0.9, "glow_color_b": Color(1.0, 0.2, 0.85) * 0.9},
}
const LEAF_SPRAY := "leaf_spray.png"


## Materials that used to be StandardMaterial3D and are now `painted` (file -> base colour).
const PAINTED := {
	"bark_vertex": [Color(1, 1, 1), 0.95],
	"rock_vertex": [Color(1, 1, 1), 0.9],
	"dark_wood": [Color(0.17, 0.12, 0.08), 0.9],  # Lighter in stage 3 (Moonfen walls read as black).
}


## Leaf-card material (leaf_card.gdshader) matching a canopy foliage material's colours and wind.
## Built once when the flora is generated (never per frame).
static func leaf_cards_for(foliage: Material) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/leaf_card.gdshader")
	m.set_shader_parameter("leaves", load(DIR + LEAF_SPRAY))
	var src := foliage as ShaderMaterial
	if src:
		for k in ["tint", "wind_strength", "wind_speed", "translucency", "brightness", "glow_color", "glow_color_b"]:
			var v: Variant = src.get_shader_parameter(k)
			if v != null:
				m.set_shader_parameter(k, v)
	return m


## A `painted` material for one of PAINTED (textures and tuning applied).
static func make_painted(file: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/painted.gdshader")
	m.set_shader_parameter("base_color", PAINTED[file][0])
	m.set_shader_parameter("roughness", PAINTED[file][1])
	apply(m, file)
	return m


## Shader file name of a material ("terrain" for res://shaders/terrain.gdshader), or "".
static func shader_name(mat: Material) -> String:
	var sm := mat as ShaderMaterial
	if sm == null or sm.shader == null:
		return ""
	return sm.shader.resource_path.get_file().get_basename()


## Give `mat` its CC0 textures. `file` is the material's file name without extension ("reed"),
## for BY_MATERIAL overrides. Returns true if the material uses a textured shader.
static func apply(mat: Material, file: String = "") -> bool:
	if LEAF_FOLIAGE.has(file) and shader_name(mat) == "foliage":
		var fm := mat as ShaderMaterial
		fm.set_shader_parameter("leaf_detail", load(DIR + LEAF_SPRAY))
		fm.set_shader_parameter("detail_amount", 0.8)
		fm.set_shader_parameter("veins", 1.0)
		for k: String in LEAF_FOLIAGE[file]:
			fm.set_shader_parameter(k, LEAF_FOLIAGE[file][k])
		return true
	var slots: Dictionary = BY_MATERIAL.get(file, BY_SHADER.get(shader_name(mat), {}))
	if slots.is_empty():
		return false
	var sm := mat as ShaderMaterial
	for slot: String in slots:
		sm.set_shader_parameter(slot + "_tex", load(DIR + slots[slot] + "_albedo.jpg"))
		sm.set_shader_parameter(slot + "_nrm", load(DIR + slots[slot] + "_normal.jpg"))
	var tuning: Dictionary = TUNING.get(file, TUNING.get(shader_name(mat), {}))
	for k: String in tuning:
		sm.set_shader_parameter(k, tuning[k])
	return true
