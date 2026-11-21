// Faint cold light shaft through the canopy (additive). UV.y 0 = top.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 color : source_color = vec3(0.35, 0.45, 0.55);
uniform float strength = 0.03;

void fragment() {
	float edge = sin(UV.x * 3.14159);
	float fall = mix(1.0, 0.0, UV.y);
	float shimmer = 0.85 + 0.15 * sin(TIME * 0.7 + UV.x * 9.0);
	float dist = length(VERTEX);
	ALBEDO = color * edge * edge * fall * strength * shimmer * smoothstep(2.0, 10.0, dist) * (1.0 - smoothstep(30.0, 60.0, dist));
}
