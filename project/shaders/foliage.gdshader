// Plants: vertex-coloured, double-sided, with wind sway. COLOR.a = how much the vertex sways
// (0 at the root, 1 at the tip). Works for single meshes and MultiMesh instances.
//
// Art pass stage 2 (painterly, cheap on every tier — no extra geometry):
//  - leaf veins drawn from UV (u = across the blade -1..1, v = 1 + base 0 .. tip 1) when `veins`
//    > 0 — only where UV.y >= 1 (broadleaf blades); UV-less meshes read UV = 0 and get none;
//  - `leaf_detail`: the CC0 leaf-spray texture projected in world space onto canopy blobs (all
//    surfaces that are not leaf blades), so the solid canopy cores read as leaves;
//  - darker bases (fake ambient occlusion from the sway weight) and slow, large-scale colour
//    variation so neighbouring plants are never the identical green.
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform vec3 tint : source_color = vec3(1.0);
uniform float wind_strength = 0.12;
uniform float wind_speed = 1.3;
uniform float translucency = 0.35;
uniform float brightness = 2.0;
uniform float veins : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D leaf_detail : source_color, hint_default_white, repeat_enable, filter_linear_mipmap;
uniform float detail_amount : hint_range(0.0, 1.0) = 0.0;
uniform float detail_tile = 2.2;
// Second colour mixed in by a slow world-space pattern (sun-touched leaves).
uniform vec3 variation : source_color = vec3(1.25, 1.2, 0.8);
uniform float variation_amount : hint_range(0.0, 1.0) = 0.35;
uniform float base_darkening : hint_range(0.0, 1.0) = 0.45;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = wp.x * 0.35 + wp.z * 0.27;
	float sway = sin(TIME * wind_speed + phase) * 0.7 + sin(TIME * wind_speed * 2.3 + phase * 1.7) * 0.3;
	VERTEX.x += sway * wind_strength * COLOR.a;
	VERTEX.z += cos(TIME * wind_speed * 0.8 + phase) * wind_strength * 0.6 * COLOR.a;
	world_pos = wp;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = COLOR.rgb * tint * brightness;
	// Slow colour variation across the jungle (two crossed sines; no texture read).
	float v = sin(world_pos.x * 0.11 + sin(world_pos.z * 0.07) * 2.0) * sin(world_pos.z * 0.09 + 1.3);
	c *= mix(vec3(1.0), variation, clamp(v * 0.5 + 0.5, 0.0, 1.0) * variation_amount);
	// Darker towards the root / inside of the plant.
	c *= mix(1.0 - base_darkening, 1.0, clamp(COLOR.a * 1.6, 0.0, 1.0));
	bool blade = UV.y >= 1.0;
	if (blade && veins > 0.0) {
		float across = abs(UV.x);
		float midrib = 1.0 - smoothstep(0.02, 0.06, across);
		// Side veins run diagonally from the midrib towards the tip.
		float side = smoothstep(0.84, 0.95, abs(fract((UV.y - 1.0 - across * 0.55) * 7.0) - 0.5) * 2.0);
		side *= smoothstep(0.05, 0.12, across) * (1.0 - smoothstep(0.8, 1.0, across));
		float edge = smoothstep(0.75, 1.0, across);
		c = mix(c, c * 1.7 + vec3(0.02, 0.03, 0.0), clamp(midrib + side * 0.6, 0.0, 1.0) * veins);
		c *= 1.0 - edge * 0.35 * veins;
	}
	if (!blade && detail_amount > 0.0) {
		// Leaf spray projected from the side and from above, blended by the surface direction.
		vec3 w = pow(abs(world_normal), vec3(3.0));
		w /= (w.x + w.y + w.z);
		vec3 q = world_pos / detail_tile;
		vec4 d = texture(leaf_detail, q.zy) * w.x + texture(leaf_detail, q.xz) * w.y + texture(leaf_detail, q.xy) * w.z;
		vec3 avg = textureLod(leaf_detail, vec2(0.5), 12.0).rgb;
		float l = dot(d.rgb, vec3(0.299, 0.587, 0.114)) / max(dot(avg, vec3(0.299, 0.587, 0.114)), 0.001);
		// Gaps between leaves read as deep shadow inside the canopy.
		c *= mix(1.0, mix(0.35, l, d.a), detail_amount);
	}
	ALBEDO = c;
	ROUGHNESS = 0.75;
	SPECULAR = 0.25;
	BACKLIGHT = c * translucency;
}
