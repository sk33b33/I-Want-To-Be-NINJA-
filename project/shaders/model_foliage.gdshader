// Imported tree models (CC0, assets/models/cc0): one texture atlas for bark and leaf cards,
// alpha-tested, double-sided, with wind sway that grows with height above the base (imported
// meshes have no sway weights in vertex colour, unlike our code-built foliage), a jungle tint, and
// leaf backlight. Painterly: the atlas gives the detail, `tint` the jungle's colour.
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform sampler2D atlas : source_color, hint_default_white, repeat_enable, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(1.0);
uniform float brightness = 1.0;
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.5;
uniform float translucency = 0.25;
uniform float wind_strength = 0.6;
uniform float wind_speed = 1.1;
// Height (metres, in the model's own space) where the sway reaches full strength.
uniform float sway_height = 18.0;
// Weather (ConditionsDirector, once per expedition): storms sway the trees harder.
global uniform float wind_boost;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = wp.x * 0.21 + wp.z * 0.17;
	float h = clamp(VERTEX.y / sway_height, 0.0, 1.0);
	float w = h * h;
	float sway = sin(TIME * wind_speed + phase) * 0.7 + sin(TIME * wind_speed * 2.1 + phase * 1.6) * 0.3;
	VERTEX.x += sway * wind_strength * wind_boost * w;
	VERTEX.z += cos(TIME * wind_speed * 0.8 + phase) * wind_strength * 0.6 * wind_boost * w;
}

void fragment() {
	vec4 t = texture(atlas, UV);
	vec3 c = t.rgb * tint * brightness;
	ALBEDO = c;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = 0.8;
	SPECULAR = 0.2;
	BACKLIGHT = c * translucency;
}
