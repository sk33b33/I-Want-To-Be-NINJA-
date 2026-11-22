// Ground warning for an incoming attack: a red pulsing strip along the attack path.
// Drawn flat (QuadMesh facing up); `intensity` 0..1 grows as the attack gets closer.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, cull_disabled, fog_disabled;

instance uniform float intensity = 0.0;
uniform vec3 color : source_color = vec3(1.0, 0.1, 0.03);
// Readability option (GameSettings.bold_warnings): brighter, with solid edges.
uniform float boost = 1.0;

void fragment() {
	float edge = smoothstep(0.0, 0.25, UV.x) * smoothstep(1.0, 0.75, UV.x);
	float along = smoothstep(1.0, 0.85, UV.y);
	// Chevrons sweeping in the attack direction.
	float chev = step(0.5, fract(UV.y * 5.0 + abs(UV.x - 0.5) * 2.0 + TIME * 2.5));
	float a = edge * along * (0.35 + 0.65 * chev) * intensity * boost;
	a += (1.0 - smoothstep(0.0, 0.06, min(UV.x, 1.0 - UV.x))) * intensity * (boost - 1.0) * 0.6;
	ALBEDO = color * a * 2.0;
}
