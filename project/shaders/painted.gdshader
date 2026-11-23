// Vertex-coloured or flat-coloured props (scattered boulders, tree bark, wooden route pieces)
// with triplanar CC0 texture detail (see include/textured_triplanar.gdshaderinc). Colour comes
// from base_color x vertex colour (white when a mesh has none, e.g. CSG boxes).
shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/include/textured_triplanar.gdshaderinc"

uniform vec3 base_color : source_color = vec3(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.9;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 w = pow(abs(world_normal), vec3(4.0));
	w /= (w.x + w.y + w.z);
	ALBEDO = base_color * COLOR.rgb * tt_detail(world_pos, w);
	ROUGHNESS = roughness;
	if (detail_normals) {
		vec3 n = tt_normal(world_pos, world_normal, w);
		// Two-sided: flip for back faces so the bumps light from the visible side.
		NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz) * (FRONT_FACING ? 1.0 : -1.0);
	}
}
