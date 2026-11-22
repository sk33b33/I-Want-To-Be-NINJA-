// Billboarded enemy health bar. `fill` is per instance (0..1).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, shadows_disabled, fog_disabled;

instance uniform float fill = 1.0;
uniform vec3 fill_color : source_color = vec3(0.85, 0.15, 0.1);
uniform vec3 back_color : source_color = vec3(0.05, 0.05, 0.05);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	float border = step(0.04, UV.x) * step(UV.x, 0.96) * step(0.18, UV.y) * step(UV.y, 0.82);
	vec3 c = mix(back_color, fill_color, step(UV.x, 0.04 + fill * 0.92));
	ALBEDO = mix(vec3(0.0), c, border);
	ALPHA = 0.9;
}
