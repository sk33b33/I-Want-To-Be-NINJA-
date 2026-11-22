// Small fauna (bats, frogs, moths): flat dark colour + optional emissive eyes via COLOR.a.
// Wings (COLOR.r > 0.5 marks wing vertices, UV.x = side) flap in the vertex shader.
// COLOR.g > 0.5 marks spines that glow with `spine_glow` (attack telegraph); `hit_flash` whitens on hit.
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform vec3 body_color : source_color = vec3(0.04, 0.035, 0.04);
uniform vec3 glow_color : source_color = vec3(0.9, 0.3, 0.1);
uniform float flap_speed = 14.0;
uniform float flap_amount = 0.0;
uniform float glow_energy = 3.0;
uniform vec3 spine_color : source_color = vec3(1.0, 0.12, 0.04);
uniform vec3 spine_idle : source_color = vec3(0.08, 0.16, 0.06);
instance uniform float spine_glow = 0.0;
instance uniform float hit_flash = 0.0;

void vertex() {
	if (COLOR.r > 0.5 && flap_amount > 0.0) {
		float phase = float(INSTANCE_ID) * 1.7;
		float a = sin(TIME * flap_speed + phase) * flap_amount;
		float side = sign(VERTEX.x);
		VERTEX.y += abs(VERTEX.x) * sin(a) * 1.2;
		VERTEX.x = side * abs(VERTEX.x) * cos(a);
	}
}

void fragment() {
	float spine = step(0.5, COLOR.g);
	ALBEDO = mix(body_color, spine_idle, spine);
	ROUGHNESS = 0.8;
	EMISSION = glow_color * COLOR.a * glow_energy + spine_color * spine * spine_glow * 4.0 + vec3(hit_flash * 1.5);
}
