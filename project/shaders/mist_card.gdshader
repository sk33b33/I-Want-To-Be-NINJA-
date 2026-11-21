// Soft ground-mist billboard. Fades out when the camera is close so cards never "cut" the view.
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D mist_noise : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform vec3 color : source_color = vec3(0.32, 0.38, 0.36);
uniform float opacity = 0.22;
uniform float near_fade = 6.0;

void vertex() {
	// Cylindrical billboard (keeps the card upright).
	vec3 cam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	vec3 fwd = normalize(vec3(cam.x, 0.0, cam.z));
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), fwd));
	VERTEX = right * VERTEX.x + vec3(0.0, 1.0, 0.0) * VERTEX.y;
}

void fragment() {
	vec2 c = UV - 0.5;
	float radial = 1.0 - smoothstep(0.15, 0.5, length(c * vec2(1.0, 1.6)));
	float n = texture(mist_noise, UV * 0.8 + vec2(TIME * 0.01, 0.0)).r;
	float dist = length(VERTEX);
	ALBEDO = color;
	ALPHA = radial * n * opacity * smoothstep(1.0, near_fade, dist);
}
