// Faint glowing ring under the player so the dark ninja stays readable (esp. in top-down).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, cull_disabled, fog_disabled;

uniform vec3 color : source_color = vec3(0.35, 0.75, 0.8);
uniform float strength = 0.35;

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float ring = smoothstep(0.62, 0.8, r) * (1.0 - smoothstep(0.8, 0.98, r));
	float pulse = 0.8 + 0.2 * sin(TIME * 2.0);
	ALBEDO = color * ring * strength * pulse;
}
