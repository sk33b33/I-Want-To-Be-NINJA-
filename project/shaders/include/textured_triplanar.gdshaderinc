// Shared triplanar CC0 texture detail for stone-like shaders (stone, basalt).
// Declares the uniforms; call tt_detail() for a brightness ratio around 1.0 (texture detail to
// multiply into a palette colour) and tt_normal() for a world-space normal with the map's bumps.
// With no texture assigned the white default gives a ratio of exactly 1.0 (no change).

uniform sampler2D tt_tex : source_color, hint_default_white, repeat_enable, filter_linear_mipmap;
uniform sampler2D tt_nrm : hint_normal, repeat_enable, filter_linear_mipmap;
// Metres per texture repeat.
uniform float tt_tile = 2.5;
// How much of the shader's older procedural noise pattern stays (1 = all; lower it when a
// texture is assigned so the texture carries the detail).
uniform float noise_amount : hint_range(0.0, 1.0) = 1.0;
uniform float tt_strength : hint_range(0.0, 1.5) = 0.9;
uniform float tt_normal_strength : hint_range(0.0, 2.0) = 1.0;
// Set from QualityPreset.detail_normals (see project.godot [shader_globals]).
global uniform bool detail_normals;

float tt_detail(vec3 p, vec3 w) {
	vec3 q = p / tt_tile;
	vec3 t = texture(tt_tex, q.zy).rgb * w.x + texture(tt_tex, q.xz).rgb * w.y + texture(tt_tex, q.xy).rgb * w.z;
	vec3 avg = textureLod(tt_tex, vec2(0.5), 12.0).rgb;
	float l = dot(t, vec3(0.299, 0.587, 0.114)) / max(dot(avg, vec3(0.299, 0.587, 0.114)), 0.001);
	return mix(1.0, l, tt_strength);
}

vec3 tt_normal(vec3 p, vec3 n, vec3 w) {
	vec3 q = p / tt_tile;
	vec2 sx = (texture(tt_nrm, q.zy).xy * 2.0 - 1.0) * tt_normal_strength;
	vec2 sy = (texture(tt_nrm, q.xz).xy * 2.0 - 1.0) * tt_normal_strength;
	vec2 sz = (texture(tt_nrm, q.xy).xy * 2.0 - 1.0) * tt_normal_strength;
	return normalize(n + vec3(0.0, sx.y, sx.x) * w.x + vec3(sy.x, 0.0, -sy.y) * w.y + vec3(sz.x, sz.y, 0.0) * w.z);
}

// Weather (ConditionsDirector, set once per expedition): rain makes stone darker and shinier.
global uniform float wetness;

void tt_wet(inout vec3 albedo, inout float roughness) {
	albedo *= 1.0 - wetness * 0.3;
	roughness = mix(roughness, 0.3, wetness * 0.75);
}

