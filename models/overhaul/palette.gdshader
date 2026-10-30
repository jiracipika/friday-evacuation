shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 skin : source_color = vec4(0.77, 0.53, 0.36, 1.0);
uniform vec4 hair : source_color = vec4(0.14, 0.1, 0.08, 1.0);
uniform vec4 cloth : source_color = vec4(0.15, 0.35, 0.38, 1.0);
uniform vec4 accent : source_color = vec4(0.95, 0.45, 0.12, 1.0);
void fragment() {
	int region = int(round(COLOR.r * 10.0));
	vec3 color = skin.rgb;
	if (region == 1) color = hair.rgb;
	if (region == 2) color = cloth.rgb;
	if (region == 3) color = accent.rgb;
	if (region == 4) color = vec3(0.035, 0.05, 0.07);
	if (region == 5) color = vec3(0.95, 0.93, 0.87);
	if (region == 6) color = vec3(0.12, 0.15, 0.17);
	ALBEDO = color * max(0.75, COLOR.g);
	ROUGHNESS = region == 0 ? 0.65 : 0.85;
}
