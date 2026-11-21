// Bioluminescent caps: COLOR.rgb = glow colour, COLOR.a = glow amount (0 on stems).
shader_type spatial;
render_mode diffuse_burley;

uniform float glow_energy = 2.2;
uniform float pulse_speed = 0.9;
uniform vec3 stem_color : source_color = vec3(0.12, 0.11, 0.09);

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float pulse = 0.7 + 0.3 * sin(TIME * pulse_speed + wp.x * 1.3 + wp.z * 0.9);
	ALBEDO = mix(stem_color, COLOR.rgb * 0.35, COLOR.a);
	EMISSION = COLOR.rgb * COLOR.a * glow_energy * pulse;
	ROUGHNESS = 0.5;
}
