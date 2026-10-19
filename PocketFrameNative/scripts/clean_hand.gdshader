shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D skin_color : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D skin_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform vec4 clean_skin : source_color = vec4(0.79, 0.59, 0.48, 1.0);
uniform vec4 clean_nail : source_color = vec4(0.85, 0.68, 0.63, 1.0);
void fragment() {
	float nail = step(0.5, COLOR.r);
	vec3 original = texture(skin_color, UV).rgb;
	// Retain anatomical tone variation without the baked-in crusty highlights.
	vec3 skin = mix(clean_skin.rgb, original, 0.28);
	vec3 nail_color = clean_nail.rgb * (1.0 + 0.035 * COLOR.g);
	ALBEDO = mix(skin, nail_color, nail);
	ROUGHNESS = mix(0.68, 0.42, nail);
	SPECULAR = mix(0.25, 0.32, nail);
	NORMAL_MAP = mix(texture(skin_normal, UV).rgb, vec3(0.5, 0.5, 1.0), nail);
	NORMAL_MAP_DEPTH = mix(0.055, 0.0, nail);
}
