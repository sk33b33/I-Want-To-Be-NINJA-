// Falling water sheet: UV.y runs top (0) to bottom (1). Streaks scroll down, edges fade.
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, depth_draw_never;

uniform sampler2D streaks : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform vec3 color : source_color = vec3(0.55, 0.7, 0.72);
uniform float speed = 1.4;
uniform float brightness = 0.55;

void fragment() {
	vec2 uv = vec2(UV.x * 2.0, UV.y * 3.0 - TIME * speed);
	float s = texture(streaks, uv).r * 0.7 + texture(streaks, uv * vec2(0.5, 0.7) + 0.3).r * 0.5;
	float edge = smoothstep(0.0, 0.18, UV.x) * smoothstep(1.0, 0.82, UV.x);
	float foam_bottom = smoothstep(0.75, 1.0, UV.y);
	ALBEDO = color * brightness * (0.6 + s * 0.8 + foam_bottom);
	ALPHA = clamp((0.25 + s * 0.6) * edge + foam_bottom * edge * 0.3, 0.0, 0.9);
}
