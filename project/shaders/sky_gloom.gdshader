// Ominous dusk sky: bruised purple-teal gradient, slow storm clouds, a hidden moon glow and
// `flash` (0..1) driven by Atmosphere for distant lightning.
shader_type sky;

uniform sampler2D cloud_noise : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform vec3 zenith : source_color = vec3(0.04, 0.05, 0.08);
uniform vec3 horizon : source_color = vec3(0.2, 0.23, 0.26);
uniform vec3 glow_tint : source_color = vec3(0.32, 0.2, 0.25);
uniform vec3 ground : source_color = vec3(0.02, 0.025, 0.02);
uniform vec3 moon_dir = vec3(0.4, 0.35, -0.85);
uniform vec3 flash_color : source_color = vec3(0.55, 0.6, 0.85);
uniform float flash = 0.0;
uniform float cloud_speed = 0.006;

void sky() {
	vec3 d = EYEDIR;
	float up = clamp(d.y, 0.0, 1.0);
	vec3 col = mix(horizon, zenith, pow(up, 0.55));
	// Sickly glow near the horizon.
	col += glow_tint * pow(1.0 - up, 6.0) * 0.5;
	// Clouds projected onto a dome.
	vec2 cuv = d.xz / (d.y + 0.25) * 0.35;
	float c1 = texture(cloud_noise, cuv + vec2(TIME * cloud_speed, 0.0)).r;
	float c2 = texture(cloud_noise, cuv * 2.1 - vec2(0.0, TIME * cloud_speed * 1.4)).r;
	float clouds = smoothstep(0.35, 0.8, c1 * 0.7 + c2 * 0.4) * smoothstep(-0.05, 0.25, d.y);
	vec3 m = normalize(moon_dir);
	float moon = pow(max(dot(d, m), 0.0), 900.0) * 3.0;
	float halo = pow(max(dot(d, m), 0.0), 18.0) * 0.25;
	col += vec3(0.65, 0.7, 0.8) * (moon * (1.0 - clouds) + halo);
	col = mix(col, horizon * 0.55 + glow_tint * 0.08, clouds * 0.85);
	col += flash_color * flash * (0.4 + clouds * 1.6) * smoothstep(-0.1, 0.3, d.y);
	if (d.y < 0.0) {
		col = mix(col, ground, smoothstep(0.0, -0.15, d.y));
	}
	COLOR = col;
}
