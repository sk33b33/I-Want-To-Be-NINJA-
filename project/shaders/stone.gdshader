// Ancient mossy stone for ruins and route pieces (triplanar, world space, no UVs needed).
shader_type spatial;

uniform sampler2D detail_noise : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform vec3 stone_light : source_color = vec3(0.32, 0.32, 0.3);
uniform vec3 stone_dark : source_color = vec3(0.12, 0.125, 0.125);
uniform vec3 moss : source_color = vec3(0.1, 0.18, 0.07);
uniform float scale = 0.4;
uniform float moss_amount = 0.6;
// Optional glowing carved runes (used on the boss gate).
uniform vec3 rune_color : source_color = vec3(0.0);
uniform float rune_strength = 0.0;
// Climbable surfaces: rows of carved handholds with a faint glow (1 = on).
uniform float climb_marks = 0.0;
uniform vec3 climb_glow : source_color = vec3(0.25, 0.85, 0.8);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 w = pow(abs(world_normal), vec3(4.0));
	w /= (w.x + w.y + w.z);
	float n = texture(detail_noise, world_pos.zy * scale).r * w.x
			+ texture(detail_noise, world_pos.xz * scale).r * w.y
			+ texture(detail_noise, world_pos.xy * scale).r * w.z;
	float big = texture(detail_noise, world_pos.xz * scale * 0.15 + world_pos.y * 0.05).r;
	vec3 col = mix(stone_dark, stone_light, n);
	// Block seams.
	float seam = smoothstep(0.03, 0.0, abs(fract(world_pos.y * 0.9) - 0.5) - 0.47);
	col *= 1.0 - seam * 0.5;
	float moss_w = smoothstep(0.35, 0.85, world_normal.y + big * 0.6 - 0.3) * moss_amount;
	moss_w = max(moss_w, smoothstep(0.65, 0.9, big) * moss_amount * 0.7);
	col = mix(col, moss * (0.6 + n * 0.8), moss_w);
	if (climb_marks > 0.0) {
		// Staggered handhold notches on vertical faces only.
		float side = 1.0 - w.y;
		vec2 g = vec2(dot(world_pos.xz, normalize(vec2(world_normal.z, -world_normal.x) + 0.0001)), world_pos.y);
		vec2 cell = vec2(g.x * 1.4 + floor(g.y * 1.6) * 0.5, g.y * 1.6);
		vec2 f = fract(cell) - 0.5;
		float notch = (1.0 - smoothstep(0.06, 0.1, abs(f.y))) * (1.0 - smoothstep(0.12, 0.18, abs(f.x)));
		notch *= side * climb_marks;
		col = mix(col, stone_dark * 0.4, notch * 0.7);
		EMISSION = climb_glow * notch * 0.12;
	}
	ALBEDO = col;
	ROUGHNESS = 0.9;
	if (rune_strength > 0.0) {
		float rune = step(0.82, texture(detail_noise, world_pos.xy * 1.7).r) * (1.0 - w.y);
		float pulse = 0.6 + 0.4 * sin(TIME * 1.7);
		EMISSION = rune_color * rune * rune_strength * pulse;
	}
}
