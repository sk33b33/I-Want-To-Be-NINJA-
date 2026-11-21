// Tiny glowing particle (fireflies, spores). Billboarded; brightness > 1 feeds the glow pass.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, cull_disabled, fog_disabled;

uniform float energy = 4.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float core = 1.0 - smoothstep(0.0, 1.0, d);
	ALBEDO = COLOR.rgb * energy * core * core * COLOR.a;
}
