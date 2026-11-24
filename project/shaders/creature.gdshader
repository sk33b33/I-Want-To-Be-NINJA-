// Creatures. Small fauna (bats, frogs, moths): flat dark colour + optional emissive eyes via COLOR.a.
// Wings (COLOR.r > 0.5 marks wing vertices, UV.x = side) flap in the vertex shader.
// COLOR.g > 0.5 marks spines that glow with `spine_glow` (attack telegraph); `hit_flash` whitens on hit.
//
// Art pass stage 4 (beasts; every option below defaults to OFF so small fauna are unchanged):
//  - skin: a CC0 texture (assets/textures/cc0: scales, hide, bark, rock) projected triplanar in
//    the creature's OWN space, so the pattern moves with the body; painterly — the texture gives
//    detail, `body_color` the colour. Normal map only with the global `detail_normals` (not Low);
//  - back-to-belly shading (lighter back, darker belly) for a painted, readable form;
//  - glowing markings along the back in `glow_color`: a slow pulse at rest that FLARES with
//    `spine_glow` during attack telegraphs (extra warning, never the only one);
//  - rim light so the silhouette reads against dark jungle.
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform vec3 body_color : source_color = vec3(0.04, 0.035, 0.04);
uniform vec3 glow_color : source_color = vec3(0.9, 0.3, 0.1);
uniform float flap_speed = 14.0;
uniform float flap_amount = 0.0;
uniform float glow_energy = 3.0;
uniform vec3 spine_color : source_color = vec3(1.0, 0.12, 0.04);
uniform vec3 spine_idle : source_color = vec3(0.08, 0.16, 0.06);
uniform float spine_strength = 4.0;
instance uniform float spine_glow = 0.0;
instance uniform float hit_flash = 0.0;

group_uniforms skin;
uniform sampler2D skin_tex : source_color, hint_default_white, repeat_enable, filter_linear_mipmap;
uniform sampler2D skin_nrm : hint_normal, repeat_enable, filter_linear_mipmap;
// Metres per texture repeat (in the creature's own space).
uniform float skin_tile = 1.5;
uniform float skin_strength : hint_range(0.0, 1.5) = 0.0;
uniform float skin_normal_strength : hint_range(0.0, 2.0) = 1.0;
// Back lighter / belly darker (0 = off).
uniform float back_light : hint_range(0.0, 1.0) = 0.0;
uniform float belly_dark : hint_range(0.0, 1.0) = 0.0;
group_uniforms markings;
uniform float marking_amount : hint_range(0.0, 1.0) = 0.0;
// Stripes per metre along the body and how far down the flanks they reach (0 back only .. 1).
uniform float marking_scale = 1.6;
uniform float marking_reach : hint_range(0.0, 1.0) = 0.45;
uniform float marking_idle : hint_range(0.0, 2.0) = 0.6;
group_uniforms rim;
uniform vec3 rim_color : source_color = vec3(0.0);
uniform float rim_strength = 0.0;
group_uniforms;
global uniform bool detail_normals;

varying vec3 obj_pos;
varying vec3 obj_normal;

void vertex() {
	if (COLOR.r > 0.5 && flap_amount > 0.0) {
		float phase = float(INSTANCE_ID) * 1.7;
		float a = sin(TIME * flap_speed + phase) * flap_amount;
		float side = sign(VERTEX.x);
		VERTEX.y += abs(VERTEX.x) * sin(a) * 1.2;
		VERTEX.x = side * abs(VERTEX.x) * cos(a);
	}
	obj_pos = VERTEX;
	obj_normal = NORMAL;
}

void fragment() {
	float spine = step(0.5, COLOR.g);
	vec3 col = mix(body_color, spine_idle, spine);
	vec3 emission = glow_color * COLOR.a * glow_energy + spine_color * spine * spine_glow * spine_strength;
	if (skin_strength > 0.0) {
		vec3 w = pow(abs(obj_normal), vec3(4.0));
		w /= (w.x + w.y + w.z);
		vec3 q = obj_pos / skin_tile;
		vec3 t = texture(skin_tex, q.zy).rgb * w.x + texture(skin_tex, q.xz).rgb * w.y + texture(skin_tex, q.xy).rgb * w.z;
		vec3 avg = textureLod(skin_tex, vec2(0.5), 12.0).rgb;
		float l = dot(t, vec3(0.299, 0.587, 0.114)) / max(dot(avg, vec3(0.299, 0.587, 0.114)), 0.001);
		col *= mix(1.0, l, skin_strength);
		if (detail_normals) {
			vec2 sx = (texture(skin_nrm, q.zy).xy * 2.0 - 1.0) * skin_normal_strength;
			vec2 sy = (texture(skin_nrm, q.xz).xy * 2.0 - 1.0) * skin_normal_strength;
			vec2 sz = (texture(skin_nrm, q.xy).xy * 2.0 - 1.0) * skin_normal_strength;
			vec3 n = normalize(obj_normal + vec3(0.0, sx.y, sx.x) * w.x + vec3(sy.x, 0.0, -sy.y) * w.y + vec3(sz.x, sz.y, 0.0) * w.z);
			NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(n, 0.0)).xyz) * (FRONT_FACING ? 1.0 : -1.0);
		}
	}
	// Painted form: lighter on the back, darker underneath.
	float up = normalize(obj_normal).y;
	col *= 1.0 + back_light * smoothstep(0.2, 1.0, up) - belly_dark * smoothstep(0.0, -0.9, up);
	if (marking_amount > 0.0) {
		// Wavy stripes across the body, strongest along the back, fading down the flanks.
		float wave = sin(obj_pos.x * 2.3 + sin(obj_pos.z * 1.1) * 1.5) * 0.35;
		float stripe = smoothstep(0.82, 0.97, sin((obj_pos.z + wave) * marking_scale * 6.2832) * 0.5 + 0.5);
		float on_back = smoothstep(1.0 - marking_reach * 1.6, 1.0, up * 0.5 + 0.5);
		float pulse = 0.75 + 0.25 * sin(TIME * 1.6);
		float m = stripe * on_back * marking_amount;
		col = mix(col, col * 0.6, m * 0.5);  // Markings read as dark grooves when not lit.
		emission += glow_color * m * (marking_idle * pulse + spine_glow * 3.0);
	}
	if (rim_strength > 0.0) {
		float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
		emission += rim_color * fres * rim_strength;
	}
	ALBEDO = col;
	ROUGHNESS = 0.8;
	EMISSION = emission + vec3(hit_flash * 1.5);
}
