// Leaf cards around canopy cores (Medium/High only — QualityPreset.leaf_cards): the CC0
// leaf-spray sprite (assets/textures/cc0/leaf_spray.png) with alpha scissor, tinted by the
// jungle's foliage colours (painterly: the texture gives the shapes, `tint` the colour), with the
// same wind sway as foliage.gdshader. COLOR.rgb = base colour, COLOR.a = sway weight.
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform sampler2D leaves : source_color, hint_default_white, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(1.0);
uniform float wind_strength = 0.12;
uniform float wind_speed = 1.3;
uniform float translucency = 0.35;
uniform float brightness = 2.0;
uniform float photo_colour : hint_range(0.0, 1.0) = 0.25;
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.45;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = wp.x * 0.35 + wp.z * 0.27;
	float sway = sin(TIME * wind_speed + phase) * 0.7 + sin(TIME * wind_speed * 2.3 + phase * 1.7) * 0.3;
	VERTEX.x += sway * wind_strength * COLOR.a;
	VERTEX.z += cos(TIME * wind_speed * 0.8 + phase) * wind_strength * 0.6 * COLOR.a;
}

void fragment() {
	vec4 t = texture(leaves, UV);
	vec3 avg = textureLod(leaves, vec2(0.5), 12.0).rgb;
	float l = dot(t.rgb, vec3(0.299, 0.587, 0.114)) / max(dot(avg, vec3(0.299, 0.587, 0.114)), 0.001);
	vec3 base = COLOR.rgb * tint * brightness;
	vec3 c = mix(base * l, t.rgb / max(avg, vec3(0.001)) * base, photo_colour);
	ALBEDO = c;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = 0.7;
	SPECULAR = 0.25;
	BACKLIGHT = c * translucency;
}
