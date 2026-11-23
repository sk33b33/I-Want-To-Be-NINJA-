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
}

## Per-material overrides by file name (reed rafts use the basalt shader but are woven reed).
const BY_MATERIAL := {
	"reed": {"tt": "bark"},
}


## Shader file name of a material ("terrain" for res://shaders/terrain.gdshader), or "".
static func shader_name(mat: Material) -> String:
	var sm := mat as ShaderMaterial
	if sm == null or sm.shader == null:
		return ""
	return sm.shader.resource_path.get_file().get_basename()


## Give `mat` its CC0 textures. `file` is the material's file name without extension ("reed"),
## for BY_MATERIAL overrides. Returns true if the material uses a textured shader.
static func apply(mat: Material, file: String = "") -> bool:
	var slots: Dictionary = BY_MATERIAL.get(file, BY_SHADER.get(shader_name(mat), {}))
	if slots.is_empty():
		return false
	var sm := mat as ShaderMaterial
	for slot: String in slots:
		sm.set_shader_parameter(slot + "_tex", load(DIR + slots[slot] + "_albedo.jpg"))
		sm.set_shader_parameter(slot + "_nrm", load(DIR + slots[slot] + "_normal.jpg"))
	if shader_name(mat) == "stone":
		sm.set_shader_parameter("seams", 0.0)  # The stone-block texture has its own seams.
	return true
