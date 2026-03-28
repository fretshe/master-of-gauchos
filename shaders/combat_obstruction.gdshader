shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, specular_disabled;

uniform vec4 base_color : source_color = vec4(0.72, 0.78, 0.86, 1.0);
uniform vec4 edge_color : source_color = vec4(0.94, 0.98, 1.0, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.2;
uniform float rim_strength : hint_range(0.0, 4.0) = 1.4;
uniform float emission_strength : hint_range(0.0, 3.0) = 0.4;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.82;

void fragment() {
	float view_fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.2);
	vec3 tint = mix(base_color.rgb, edge_color.rgb, view_fresnel * 0.7);
	ALBEDO = tint;
	EMISSION = edge_color.rgb * view_fresnel * rim_strength * emission_strength;
	ALPHA = opacity;
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
}
