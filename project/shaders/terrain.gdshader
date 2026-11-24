// Jungle floor: ground cover, trodden path and rock on slopes. Blend weights come from the
// vertex colour baked by BiomeTerrain (r rock, g path, b tint noise, a wetness).
//
// Painterly texturing: CC0 photo textures (assets/textures/cc0, see ASSET_LEDGER.md) supply
// DETAIL (pebbles, twigs, cracks) while each jungle's palette colours supply the COLOUR, so all
// four jungles share one small texture set and keep their own look. `photo_colour` lets some of
// the texture's real colour through. Each texture's 1x1 mip is its average colour, used to
// normalise brightness so the palette colours stay in charge.
// Quality: global uniforms `detail_normals` (normal maps) and `anti_tile` (a second, larger
// ground sample hiding repetition), set from QualityPreset by QualityProfile.apply_to_scene().
shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D detail_noise : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform sampler2D macro_noise : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform sampler2D ground_tex : source_color, hint_default_white, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D ground_nrm : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D path_tex : source_color, hint_default_white, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D path_nrm : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D rock_tex : source_color, hint_default_white, repeat_enable, filter_linear_mipmap;
uniform sampler2D rock_nrm : hint_normal, repeat_enable, filter_linear_mipmap;
uniform vec3 moss_dark : source_color = vec3(0.07, 0.12, 0.065);
uniform vec3 moss_light : source_color = vec3(0.16, 0.24, 0.1);
uniform vec3 mud : source_color = vec3(0.17, 0.13, 0.09);
uniform vec3 rock : source_color = vec3(0.26, 0.27, 0.28);
uniform vec3 rock_dark : source_color = vec3(0.1, 0.105, 0.11);
uniform float detail_scale = 0.35;
uniform float macro_scale = 0.03;
// Metres per texture repeat.
uniform float ground_tile = 4.0;
uniform float path_tile = 3.0;
uniform float rock_tile = 6.0;
// How strongly the textures' light/dark detail shows (0 = flat palette colour).
uniform float detail_strength : hint_range(0.0, 1.5) = 0.9;
// How much of the photo's own colour shows through the palette (0 = pure palette).
uniform float photo_colour : hint_range(0.0, 1.0) = 0.3;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
global uniform bool detail_normals;
global uniform bool anti_tile;
// Weather (ConditionsDirector, set once per expedition): 0 dry .. 1 soaked.
global uniform float wetness;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

const vec3 LUMA = vec3(0.299, 0.587, 0.114);

// Tint a texture sample with a palette colour, keeping the texture's detail.
vec3 paint(vec3 tex, vec3 avg, vec3 palette) {
	float l = dot(tex, LUMA) / max(dot(avg, LUMA), 0.001);
	vec3 painted = palette * mix(1.0, l, detail_strength);
	// The photo's colour shifts relative to its own average (green moss patches, red leaves),
	// carried on the palette colour.
	vec3 photo = tex / max(avg, vec3(0.001)) * palette;
	return mix(painted, photo, photo_colour);
}

// Unpack a tangent-space normal map sample to xy slope offsets.
vec2 slope(sampler2D nrm, vec2 uv) {
	return (texture(nrm, uv).xy * 2.0 - 1.0) * normal_strength;
}

void fragment() {
	float d = texture(detail_noise, world_pos.xz * detail_scale).r;
	float m = texture(macro_noise, world_pos.xz * macro_scale).r;

	// Ground cover; a second, larger and rotated sample breaks up the repeat.
	vec2 guv = world_pos.xz / ground_tile;
	vec3 g = texture(ground_tex, guv).rgb;
	if (anti_tile) {
		vec2 guv2 = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * guv * 0.37;
		g = mix(g, texture(ground_tex, guv2).rgb, smoothstep(0.35, 0.65, m));
	}
	vec3 g_avg = textureLod(ground_tex, vec2(0.5), 12.0).rgb;
	vec3 moss_col = mix(moss_dark, moss_light, clamp(COLOR.b * 0.7 + m * 0.6 - 0.2, 0.0, 1.0));
	vec3 moss = paint(g, g_avg, moss_col);

	vec2 puv = world_pos.xz / path_tile;
	vec3 p = texture(path_tex, puv).rgb;
	vec3 trail = paint(p, textureLod(path_tex, vec2(0.5), 12.0).rgb, mud);

	// Rock: triplanar so cliffs never stretch.
	vec3 w = pow(abs(world_normal), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 rp = world_pos / rock_tile;
	vec3 r = texture(rock_tex, rp.zy).rgb * w.x + texture(rock_tex, rp.xz).rgb * w.y + texture(rock_tex, rp.xy).rgb * w.z;
	vec3 r_avg = textureLod(rock_tex, vec2(0.5), 12.0).rgb;
	float rock_l = dot(r, LUMA) / max(dot(r_avg, LUMA), 0.001);
	vec3 stone = paint(r, r_avg, mix(rock_dark, rock, clamp(rock_l * 0.5, 0.0, 1.0)));
	// Moss creeps over rock on its upward-facing parts.
	stone = mix(stone, moss * 0.8, smoothstep(0.55, 0.9, world_normal.y) * 0.6);

	float path_w = smoothstep(0.2, 0.8, COLOR.g + (d - 0.5) * 0.5);
	float rock_w = smoothstep(0.3, 0.7, COLOR.r + (rock_l - 1.0) * 0.25 + (d - 0.5) * 0.2);
	vec3 col = mix(moss, trail, path_w);
	col = mix(col, stone, rock_w);
	float wet = max(COLOR.a, wetness * 0.85);
	ALBEDO = col * (1.0 - wet * 0.35);
	ROUGHNESS = mix(0.92, 0.35, wet * (0.5 + path_w * 0.5));
	SPECULAR = 0.3 + wet * 0.3;

	if (detail_normals) {
		// Ground and path are projected from above: their slopes tilt the world normal in x/z.
		vec2 gs = mix(slope(ground_nrm, guv), slope(path_nrm, puv), path_w);
		vec3 n = normalize(world_normal + vec3(gs.x, 0.0, -gs.y) * (1.0 - rock_w));
		// Triplanar rock normals (cheap "add the slope in each plane" blend).
		vec2 sx = slope(rock_nrm, rp.zy);
		vec2 sy = slope(rock_nrm, rp.xz);
		vec2 sz = slope(rock_nrm, rp.xy);
		vec3 rn = normalize(world_normal + vec3(0.0, sx.y, sx.x) * w.x + vec3(sy.x, 0.0, -sy.y) * w.y + vec3(sz.x, sz.y, 0.0) * w.z);
		n = normalize(mix(n, rn, rock_w));
		NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	}
}
