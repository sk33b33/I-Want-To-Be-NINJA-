// Molten lava: slow-flowing crust with bright glowing cracks. World-space UVs, no screen reads.
shader_type spatial;
render_mode diffuse_burley, cull_disabled;

uniform sampler2D flow_noise : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform vec3 crust : source_color = vec3(0.06, 0.025, 0.02);
uniform vec3 hot : source_color = vec3(1.0, 0.35, 0.05);
uniform vec3 white_hot : source_color = vec3(1.0, 0.8, 0.4);
uniform float speed = 0.02;
uniform vec2 flow_dir = vec2(1.0, 0.15);
uniform float glow = 2.2;
// Waterfall-style use: scroll along UV.y instead of world XZ.
uniform bool falling = false;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = falling ? vec2(UV.x * 1.5, UV.y * 4.0 - TIME * 0.6) : world_pos.xz * 0.08 + flow_dir * TIME * speed;
	float n1 = texture(flow_noise, uv).r;
	float n2 = texture(flow_noise, uv * 2.3 + vec2(TIME * speed * 0.7, 0.0)).r;
	float cracks = smoothstep(0.42, 0.5, abs(n1 - n2) < 0.06 ? 1.0 : 0.0) + smoothstep(0.6, 0.9, n2) * 0.6;
	float pulse = 0.85 + 0.15 * sin(TIME * 1.3 + n1 * 6.0);
	vec3 heat = mix(hot, white_hot, smoothstep(0.7, 1.0, n2));
	ALBEDO = mix(crust, heat * 0.4, cracks);
	ROUGHNESS = 0.85;
	EMISSION = heat * cracks * glow * pulse + hot * 0.08;
}
