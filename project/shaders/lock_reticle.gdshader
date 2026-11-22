// Lock-on reticle: billboarded ring with four rotating ticks.
shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, shadows_disabled, cull_disabled, fog_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.35, 0.2);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	float ring = smoothstep(0.72, 0.78, r) * (1.0 - smoothstep(0.84, 0.9, r));
	float ang = atan(p.y, p.x) + TIME * 1.5;
	float ticks = step(0.92, cos(ang * 4.0)) * smoothstep(0.55, 0.62, r) * (1.0 - smoothstep(0.95, 1.0, r));
	ALBEDO = color * (ring * 0.8 + ticks) * 1.5;
}
