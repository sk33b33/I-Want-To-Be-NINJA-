// Checkpoint spirit flame: billboarded flickering teardrop. Colour is per-instance so each
// shrine can switch from dormant red to active teal without unique materials.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, cull_disabled, fog_disabled;

instance uniform vec3 flame_color : source_color = vec3(0.6, 0.12, 0.05);
uniform float energy = 3.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 uv = UV - vec2(0.5, 0.6);
	float flicker = 0.85 + 0.15 * sin(TIME * 13.0) * sin(TIME * 7.3);
	uv.x += sin(TIME * 5.0 + UV.y * 6.0) * 0.04 * (1.0 - UV.y);
	// Teardrop: narrower toward the top.
	float w = mix(0.12, 0.32, smoothstep(0.0, 0.75, UV.y));
	float shape = 1.0 - smoothstep(0.0, 1.0, length(vec2(uv.x / w, uv.y * 2.2)));
	ALBEDO = flame_color * energy * shape * shape * flicker;
}
