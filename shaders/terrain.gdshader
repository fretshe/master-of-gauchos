shader_type spatial;
render_mode cull_back, specular_disabled;

uniform vec4 albedo_color    : source_color = vec4(0.44, 0.76, 0.33, 1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable;
uniform bool use_albedo_texture = false;
uniform float texture_tint_strength : hint_range(0.0, 1.0) = 0.55;
uniform float texture_brightness : hint_range(0.5, 2.0) = 1.0;
uniform float deco_strength : hint_range(0.0, 1.0) = 0.22;
uniform float pixel_density : hint_range(8.0, 64.0) = 22.0;
uniform float patch_pixel_size : hint_range(2.0, 12.0) = 6.0;
uniform vec4 emission_color  : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_strength : hint_range(0.0, 2.0) = 0.0;
uniform float dim_factor : hint_range(0.2, 1.2) = 1.0;
uniform vec4 night_glow_color : source_color = vec4(0.20, 0.32, 0.55, 1.0);
uniform float night_glow_strength : hint_range(0.0, 1.5) = 0.0;
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.28;
uniform float highlight_threshold : hint_range(0.0, 1.0) = 0.72;
uniform float band_smoothness : hint_range(0.001, 0.20) = 0.04;
uniform float light_bands : hint_range(2.0, 5.0) = 3.0;
uniform vec3 shadow_tint : source_color = vec3(0.52, 0.52, 0.60);
uniform vec3 mid_tint : source_color = vec3(0.82, 0.82, 0.88);
uniform vec3 highlight_tint : source_color = vec3(1.08, 1.08, 1.00);

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec3 base_albedo = albedo_color.rgb;
	if (use_albedo_texture) {
		vec2 uv = UV * 2.0;
		vec3 tex = texture(albedo_texture, uv).rgb * texture_brightness;
		base_albedo = mix(base_albedo, tex * albedo_color.rgb, texture_tint_strength);

		vec2 pixel_uv = floor(uv * pixel_density);
		vec2 patch_id = floor(pixel_uv / patch_pixel_size);
		vec2 local_px = mod(pixel_uv, patch_pixel_size);
		float patch_noise = hash12(patch_id);

		float stone_mask = 0.0;
		if (patch_noise > 0.82) {
			float pebble_a = step(1.0, local_px.x) * step(local_px.x, 2.0) * step(5.0, local_px.y) * step(local_px.y, 5.0);
			float pebble_b = step(4.0, local_px.x) * step(local_px.x, 5.0) * step(2.0, local_px.y) * step(local_px.y, 2.0);
			float pebble_c = step(5.0, local_px.x) * step(local_px.x, 5.0) * step(3.0, local_px.y) * step(local_px.y, 4.0);
			stone_mask = max(pebble_a, max(pebble_b, pebble_c));
		}

		vec3 stone_tint = vec3(0.76, 0.74, 0.70);
		base_albedo = mix(base_albedo, stone_tint, stone_mask * (deco_strength + 0.08));
	}
	ALBEDO   = base_albedo * dim_factor;
	EMISSION = emission_color.rgb * emission_strength + night_glow_color.rgb * night_glow_strength;
	ROUGHNESS = 1.0;
	METALLIC  = 0.0;
}

void light() {
	float ndotl = max(dot(NORMAL, LIGHT), 0.0);
	float stepped_ndotl = floor(ndotl * light_bands) / max(light_bands - 1.0, 1.0);
	float shadow_band = smoothstep(shadow_threshold - band_smoothness, shadow_threshold + band_smoothness, stepped_ndotl);
	float highlight_band = smoothstep(highlight_threshold - band_smoothness, highlight_threshold + band_smoothness, stepped_ndotl);

	vec3 band_color = ALBEDO * shadow_tint;
	band_color = mix(band_color, ALBEDO * mid_tint, shadow_band);
	band_color = mix(band_color, ALBEDO * highlight_tint, highlight_band);

	DIFFUSE_LIGHT += band_color * LIGHT_COLOR * ATTENUATION;
}
