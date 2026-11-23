shader_type spatial;
render_mode specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.48, 0.53, 0.48, 1.0);
uniform float tile_size = 2.0;
uniform float seam_width = 0.014;
uniform float checker_amount = 0.08;
uniform float roughness_value = 0.85;
varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 cell = world_xz / tile_size;
	vec2 tile_uv = fract(cell);
	vec2 edge = min(tile_uv, 1.0 - tile_uv);
	float nearest_edge = min(edge.x, edge.y);
	float seam = smoothstep(seam_width, seam_width + fwidth(nearest_edge), nearest_edge);
	float stagger = mod(floor(cell.x) + floor(cell.y), 2.0);
	ALBEDO = base_color.rgb * (1.0 - stagger * checker_amount) * mix(0.65, 1.0, seam);
	ROUGHNESS = roughness_value;
}
