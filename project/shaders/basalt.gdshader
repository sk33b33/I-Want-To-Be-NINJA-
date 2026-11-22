// Basalt rock for Emberwild route pieces: dark, rough, with faint ember veins.
// `rune_glow` (per instance, 0..1) makes the veins blaze — used as a hazard warning
// (sinking stones, crumbling platforms).
shader_type spatial;

uniform sampler2D detail_noise : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform vec3 rock_light : source_color = vec3(0.17, 0.15, 0.14);
uniform vec3 rock_dark : source_color = vec3(0.05, 0.045, 0.045);
uniform vec3 ember : source_color = vec3(1.0, 0.3, 0.05);
uniform float scale = 0.45;
uniform float climb_marks = 0.0;
instance uniform float rune_glow = 0.0;

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
	float vein = smoothstep(0.03, 0.0, abs(n - 0.52));
	vec3 col = mix(rock_dark, rock_light, smoothstep(0.3, 0.8, n));
	ALBEDO = col * (1.0 - vein * 0.5);
	ROUGHNESS = 0.95;
	EMISSION = ember * vein * (0.06 + rune_glow * 4.0);
	if (climb_marks > 0.0) {
		float side = 1.0 - w.y;
		vec2 g = vec2(dot(world_pos.xz, normalize(vec2(world_normal.z, -world_normal.x) + 0.0001)), world_pos.y);
		vec2 f = fract(vec2(g.x * 1.4 + floor(g.y * 1.6) * 0.5, g.y * 1.6)) - 0.5;
		float notch = (1.0 - smoothstep(0.06, 0.1, abs(f.y))) * (1.0 - smoothstep(0.12, 0.18, abs(f.x))) * side;
		EMISSION += vec3(1.0, 0.55, 0.2) * notch * 0.15 * climb_marks;
	}
}
