shader_type spatial;
render_mode cull_back, specular_disabled, depth_prepass_alpha;

uniform vec4 albedo_color      : source_color = vec4(0.70, 0.70, 0.70, 1.0);
uniform vec4 emission_color    : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_strength : hint_range(0.0, 2.0) = 0.4;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform vec4 night_glow_color  : source_color = vec4(0.24, 0.36, 0.62, 1.0);
uniform float night_glow_strength : hint_range(0.0, 1.5) = 0.0;
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.24;
uniform float highlight_threshold : hint_range(0.0, 1.0) = 0.68;
uniform float band_smoothness : hint_range(0.001, 0.20) = 0.04;
uniform vec3 shadow_tint : source_color = vec3(0.46, 0.46, 0.54);
uniform vec3 mid_tint : source_color = vec3(0.82, 0.82, 0.88);
uniform vec3 highlight_tint : source_color = vec3(1.12, 1.12, 1.16);

void fragment() {
	ALBEDO    = albedo_color.rgb;
	EMISSION  = emission_color.rgb * emission_strength + night_glow_color.rgb * night_glow_strength;
	ALPHA     = opacity;
	ROUGHNESS = 0.70;
	METALLIC  = 0.10;
}

void light() {
	float ndotl = max(dot(NORMAL, LIGHT), 0.0);
	float shadow_band = smoothstep(shadow_threshold - band_smoothness, shadow_threshold + band_smoothness, ndotl);
	float highlight_band = smoothstep(highlight_threshold - band_smoothness, highlight_threshold + band_smoothness, ndotl);

	vec3 band_color = ALBEDO * shadow_tint;
	band_color = mix(band_color, ALBEDO * mid_tint, shadow_band);
	band_color = mix(band_color, ALBEDO * highlight_tint, highlight_band);

	DIFFUSE_LIGHT += band_color * LIGHT_COLOR * ATTENUATION;
}
