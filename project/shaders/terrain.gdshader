// Gloomy jungle floor: moss, wet mud trail, dark rock on slopes. Blend weights come from the
// vertex colour baked by BiomeTerrain (r rock, g path, b tint noise, a wetness).
shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D detail_noise : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform sampler2D macro_noise : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform vec3 moss_dark : source_color = vec3(0.07, 0.12, 0.065);
uniform vec3 moss_light : source_color = vec3(0.16, 0.24, 0.1);
uniform vec3 mud : source_color = vec3(0.17, 0.13, 0.09);
uniform vec3 rock : source_color = vec3(0.26, 0.27, 0.28);
uniform vec3 rock_dark : source_color = vec3(0.1, 0.105, 0.11);
uniform float detail_scale = 0.35;
uniform float macro_scale = 0.03;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float triplanar(sampler2D tex, vec3 p, vec3 n, float s) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(tex, p.zy * s).r * w.x + texture(tex, p.xz * s).r * w.y + texture(tex, p.xy * s).r * w.z;
}

void fragment() {
	float d = texture(detail_noise, world_pos.xz * detail_scale).r;
	float m = texture(macro_noise, world_pos.xz * macro_scale).r;
	vec3 moss = mix(moss_dark, moss_light, clamp(COLOR.b * 0.7 + m * 0.6 - 0.2, 0.0, 1.0));
	moss *= 0.75 + d * 0.5;
	// Mud trail with puddle-dark wet patches.
	vec3 trail = mud * (0.7 + d * 0.6);
	float rock_n = triplanar(detail_noise, world_pos, world_normal, 0.25);
	vec3 stone = mix(rock_dark, rock, rock_n);
	// Moss creeps over rock on its upward-facing parts.
	stone = mix(stone, moss_dark, smoothstep(0.55, 0.9, world_normal.y) * 0.6);
	float path_w = smoothstep(0.2, 0.8, COLOR.g + (d - 0.5) * 0.5);
	vec3 col = mix(moss, trail, path_w);
	col = mix(col, stone, smoothstep(0.3, 0.7, COLOR.r + (rock_n - 0.5) * 0.4));
	float wet = COLOR.a;
	ALBEDO = col * (1.0 - wet * 0.35);
	ROUGHNESS = mix(0.92, 0.35, wet * (0.5 + path_w * 0.5));
	SPECULAR = 0.3 + wet * 0.3;
}
