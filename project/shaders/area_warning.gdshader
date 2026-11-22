// Circular area warning (thorn burst, root snare): filled disc with a bright pulsing rim.
// Flat QuadMesh facing up; `intensity` 0..1 rises as the attack approaches.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, cull_disabled, fog_disabled;

instance uniform float intensity = 0.0;
uniform vec3 color : source_color = vec3(1.0, 0.1, 0.03);

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float inside = 1.0 - step(1.0, r);
	float rim = smoothstep(0.82, 0.95, r) * inside;
	float pulse = 0.6 + 0.4 * sin(TIME * 10.0);
	float fill = inside * (0.18 + 0.25 * intensity);
	ALBEDO = color * (fill + rim * (0.6 + intensity) * pulse) * (0.4 + intensity);
}
