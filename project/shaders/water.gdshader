// Dark jungle water: deep teal, moving ripples, strong fresnel sheen. No screen reads (phone-safe).
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D ripple_noise : hint_normal, repeat_enable, filter_linear_mipmap;
uniform vec3 deep : source_color = vec3(0.04, 0.1, 0.11);
uniform vec3 shallow : source_color = vec3(0.12, 0.26, 0.26);
uniform float flow_speed = 0.04;
uniform vec2 flow_dir = vec2(1.0, 0.2);
uniform float alpha = 0.88;
uniform float glow = 0.25;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz * 0.12;
	vec3 n1 = texture(ripple_noise, uv + flow_dir * TIME * flow_speed).rgb;
	vec3 n2 = texture(ripple_noise, uv * 1.7 - flow_dir.yx * TIME * flow_speed * 1.3).rgb;
	NORMAL_MAP = normalize(n1 + n2 - 1.0);
	NORMAL_MAP_DEPTH = 0.6;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = mix(deep, shallow, fres * 0.6 + n1.r * 0.2);
	ROUGHNESS = 0.04;
	METALLIC = 0.2;
	SPECULAR = 0.8;
	EMISSION = shallow * glow;
	ALPHA = mix(alpha, 1.0, fres);
}
