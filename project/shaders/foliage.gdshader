// Plants: vertex-coloured, double-sided, with wind sway. COLOR.a = how much the vertex sways
// (0 at the root, 1 at the tip). Works for single meshes and MultiMesh instances.
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform vec3 tint : source_color = vec3(1.0);
uniform float wind_strength = 0.12;
uniform float wind_speed = 1.3;
uniform float translucency = 0.35;
uniform float brightness = 2.0;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = wp.x * 0.35 + wp.z * 0.27;
	float sway = sin(TIME * wind_speed + phase) * 0.7 + sin(TIME * wind_speed * 2.3 + phase * 1.7) * 0.3;
	VERTEX.x += sway * wind_strength * COLOR.a;
	VERTEX.z += cos(TIME * wind_speed * 0.8 + phase) * wind_strength * 0.6 * COLOR.a;
}

void fragment() {
	vec3 c = COLOR.rgb * tint * brightness;
	ALBEDO = c;
	ROUGHNESS = 0.75;
	SPECULAR = 0.25;
	BACKLIGHT = c * translucency;
}
