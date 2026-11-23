// Blade slash trail (WeaponTrail). The mesh is built ONCE (a strip of MAX_POINTS pairs, UV.x =
// point index, UV.y = 0 guard / 1 tip); every frame only these uniforms change. No per-frame
// geometry uploads: those crashed the Godot app on the owner's Android phone (Phase 12+ fix).
// gl_compatibility-safe: no screen/depth reads; 3 x 32 uniform slots.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, world_vertex_coords, fog_disabled;

const int MAX_POINTS = 32;
uniform vec3 base_points[32];
uniform vec3 tip_points[32];
uniform float fades[32];
uniform int point_count = 0;
uniform vec4 trail_color : source_color = vec4(0.55, 0.75, 0.95, 1.0);
uniform float tip_alpha = 0.42;
uniform float base_alpha = 0.06;

varying float v_alpha;

void vertex() {
	int i = clamp(int(UV.x + 0.5), 0, MAX_POINTS - 1);
	// Unused slots sit on the last real point, so the joining triangles have zero area
	// (collapsing them to the world origin drew a streak to the ground).
	int j = clamp(min(i, point_count - 1), 0, MAX_POINTS - 1);
	VERTEX = mix(base_points[j], tip_points[j], UV.y);
	float f = i < point_count ? fades[j] : 0.0;
	v_alpha = mix(f * f * base_alpha, f * tip_alpha, UV.y);
}

void fragment() {
	ALBEDO = trail_color.rgb;
	ALPHA = v_alpha;
}
