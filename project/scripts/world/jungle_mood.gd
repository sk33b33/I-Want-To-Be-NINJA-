class_name JungleMood
extends Resource
## Art pass stage 3 (lighting & mood): one per jungle in data/mood/, applied once at expedition
## load by BiomeAtmosphere (never per frame). Graded toward the concept art in docs/concept-art/
## (warm-vs-cool contrast, saturated accents) while keeping each jungle's gloom.
## All values are absolute (applying twice gives the same result), and the brightness slider
## (QualityProfile.apply_brightness) scales the exposure/ambient set here.

@export_group("Sun / moon")
@export var sun_color: Color = Color(0.55, 0.64, 0.82)
@export var sun_energy: float = 1.35

@export_group("Ambient")
@export var ambient_color: Color = Color(0.24, 0.3, 0.32)
@export var ambient_energy: float = 4.3
@export var exposure: float = 1.5

@export_group("Fog")
## Height fog pools in valleys and gorges; `fog_sun_scatter` glows towards the sun (back-light).
@export var fog_color: Color = Color(0.17, 0.21, 0.23)
@export var fog_density: float = 0.016
@export var fog_sky_affect: float = 0.3
@export var fog_height: float = 0.5
@export var fog_height_density: float = 0.04
@export var fog_sun_scatter: float = 0.0

@export_group("Grade")
@export var saturation: float = 1.0
@export var contrast: float = 1.1
## Split toning via a per-channel curve (Environment colour correction): shadows lean towards
## `shadow_tint`, highlights towards `highlight_tint`. Off on Low (QualityPreset.color_grade_lut).
@export var shadow_tint: Color = Color(0.0, 0.02, 0.03)
@export var highlight_tint: Color = Color(1.0, 0.96, 0.88)

@export_group("Light shafts")
@export var shaft_color: Color = Color(0.6, 0.75, 0.9)
@export var shaft_strength: float = 0.035
@export var shaft_width: float = 2.5

@export_group("Water")
@export var water_shallow: Color = Color(0.12, 0.22, 0.24)
@export var water_deep: Color = Color(0.02, 0.05, 0.06)


## The colour-correction curve for split toning (a 1D LUT: each channel is looked up on its own).
func grade_curve() -> GradientTexture1D:
	var g := Gradient.new()
	g.set_offset(0, 0.0)
	g.set_color(0, shadow_tint)
	g.set_offset(1, 1.0)
	g.set_color(1, highlight_tint)
	g.add_point(0.5, Color(0.5, 0.5, 0.5).lerp((shadow_tint + highlight_tint) * 0.5, 0.15))
	var t := GradientTexture1D.new()
	t.gradient = g
	t.width = 256
	return t
