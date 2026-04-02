shader_type spatial;
render_mode cull_back, specular_disabled;

uniform vec4 albedo_color    : source_color = vec4(0.44, 0.76, 0.33, 1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable;
uniform bool use_albedo_texture = false;
uniform float texture_tint_strength : hint_range(0.0, 1.0) = 0.55;
uniform float texture_brightness : hint_range(0.5, 2.0) = 1.0;
uniform float deco_strength : hint_range(0.0, 1.0) = 0.22;
uniform int deco_profile = 0;
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
uniform float cloud_shadow_strength : hint_range(0.0, 0.6) = 0.32;
uniform float cloud_shadow_scale : hint_range(0.01, 0.30) = 0.07;
uniform float cloud_shadow_speed : hint_range(0.0, 0.20) = 0.022;
uniform float cloud_shadow_softness : hint_range(0.01, 0.30) = 0.11;
uniform float cloud_sunbreak_strength : hint_range(0.0, 0.8) = 0.08;
uniform vec3 cloud_sunbreak_tint : source_color = vec3(1.12, 1.06, 0.88);
uniform float cloud_pixel_size : hint_range(0.02, 1.0) = 0.24;
uniform float terrain_shadow_response : hint_range(0.2, 1.8) = 1.0;
uniform float terrain_sunbreak_response : hint_range(0.2, 1.8) = 1.0;
uniform float terrain_ambient_lift : hint_range(0.7, 1.3) = 1.0;
uniform float water_shimmer_strength : hint_range(0.0, 0.5) = 0.0;
uniform float water_shimmer_speed : hint_range(0.0, 0.3) = 0.0;
uniform vec3 water_shimmer_tint : source_color = vec3(0.88, 0.96, 1.10);

varying vec3 world_pos;

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float cloud_wave(vec2 p) {
	return 0.5 + 0.5 * sin(p.x) * cos(p.y);
}

float cloud_mask(vec2 world_xz) {
	vec2 quantized_world = floor(world_xz / cloud_pixel_size) * cloud_pixel_size;
	vec2 flow = quantized_world * cloud_shadow_scale;
	flow += vec2(TIME * cloud_shadow_speed, TIME * cloud_shadow_speed * 0.62);

	float layer_a = cloud_wave(flow * 1.0 + vec2(0.8, 1.7));
	float layer_b = cloud_wave(flow * 1.9 + vec2(-2.4, 0.6));
	float layer_c = cloud_wave(flow * 3.1 + vec2(1.2, -1.5));
	float combined = layer_a * 0.48 + layer_b * 0.32 + layer_c * 0.20;
	return smoothstep(0.48 - cloud_shadow_softness, 0.48 + cloud_shadow_softness, combined);
}

float sunbreak_mask(vec2 world_xz, float cloud_value) {
	vec2 quantized_world = floor(world_xz / cloud_pixel_size) * cloud_pixel_size;
	vec2 flow = quantized_world * (cloud_shadow_scale * 0.62);
	flow += vec2(-TIME * cloud_shadow_speed * 0.38, TIME * cloud_shadow_speed * 0.22);
	float layer_a = cloud_wave(flow * 1.2 + vec2(0.9, -1.7));
	float layer_b = cloud_wave(flow * 2.3 + vec2(-2.1, 0.4));
	float break_pattern = layer_a * 0.58 + layer_b * 0.42;
	float clear_sky = smoothstep(0.34, 0.02, cloud_value);
	return smoothstep(0.56, 0.78, break_pattern) * clear_sky;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
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
		float patch_variant = hash12(patch_id + vec2(23.0, 41.0));

		float deco_mask = 0.0;
		vec3 deco_tint = base_albedo;
		if (deco_profile == 1) {
			if (patch_noise > 0.60) {
				float fern_a = step(2.0, local_px.x) * step(local_px.x, 3.0) * step(1.0, local_px.y) * step(local_px.y, 4.0);
				float fern_b = step(1.0, local_px.x) * step(local_px.x, 1.0) * step(2.0, local_px.y) * step(local_px.y, 3.0);
				float fern_c = step(4.0, local_px.x) * step(local_px.x, 4.0) * step(2.0, local_px.y) * step(local_px.y, 3.0);
				float moss_a = step(0.0, local_px.x) * step(local_px.x, 2.0) * step(5.0, local_px.y) * step(local_px.y, 5.0);
				float moss_b = step(4.0, local_px.x) * step(local_px.x, 5.0) * step(0.0, local_px.y) * step(local_px.y, 1.0);
				float fern_d = step(2.0, local_px.x) * step(local_px.x, 3.0) * step(0.0, local_px.y) * step(local_px.y, 2.0);
				float fern_e = step(0.0, local_px.x) * step(local_px.x, 1.0) * step(3.0, local_px.y) * step(local_px.y, 5.0);
				float moss_c = step(3.0, local_px.x) * step(local_px.x, 5.0) * step(4.0, local_px.y) * step(local_px.y, 5.0);
				float moss_d = step(0.0, local_px.x) * step(local_px.x, 1.0) * step(0.0, local_px.y) * step(local_px.y, 1.0);
				float variant_a = max(fern_a, max(fern_b, max(fern_c, max(moss_a, moss_b))));
				float variant_b = max(fern_d, max(fern_e, max(moss_c, moss_d)));
				deco_mask = mix(variant_b, variant_a, step(patch_variant, 0.5));
			}
			float forest_variant = hash12(patch_id + vec2(17.0, 9.0));
			deco_tint = mix(base_albedo * vec3(0.84, 1.08, 0.86), base_albedo * vec3(1.00, 1.16, 0.94), forest_variant);
		} else {
			if (patch_noise > 0.72) {
				float tuft_a = step(1.0, local_px.x) * step(local_px.x, 2.0) * step(4.0, local_px.y) * step(local_px.y, 5.0);
				float tuft_b = step(3.0, local_px.x) * step(local_px.x, 4.0) * step(2.0, local_px.y) * step(local_px.y, 4.0);
				float tuft_c = step(5.0, local_px.x) * step(local_px.x, 5.0) * step(1.0, local_px.y) * step(local_px.y, 2.0);
				float tuft_d = step(0.0, local_px.x) * step(local_px.x, 1.0) * step(3.0, local_px.y) * step(local_px.y, 5.0);
				float tuft_e = step(2.0, local_px.x) * step(local_px.x, 3.0) * step(0.0, local_px.y) * step(local_px.y, 1.0);
				float tuft_f = step(4.0, local_px.x) * step(local_px.x, 5.0) * step(4.0, local_px.y) * step(local_px.y, 5.0);
				float variant_a = max(tuft_a, max(tuft_b, tuft_c));
				float variant_b = max(tuft_d, max(tuft_e, tuft_f));
				deco_mask = mix(variant_b, variant_a, step(patch_variant, 0.5));
			}
			float grass_variant = hash12(patch_id + vec2(5.0, 13.0));
			deco_tint = mix(base_albedo * vec3(0.88, 1.10, 0.82), base_albedo * vec3(1.02, 1.18, 0.88), grass_variant);
		}
		base_albedo = mix(base_albedo, deco_tint, deco_mask * (deco_strength + 0.06));
	}
	if (water_shimmer_strength > 0.001) {
		vec2 ripple_uv = floor(world_pos.xz / max(cloud_pixel_size * 0.85, 0.02)) * max(cloud_pixel_size * 0.85, 0.02);
		float ripple_a = 0.5 + 0.5 * sin(ripple_uv.x * 4.8 + TIME * water_shimmer_speed * 5.2);
		float ripple_b = 0.5 + 0.5 * cos(ripple_uv.y * 5.6 - TIME * water_shimmer_speed * 4.4);
		float ripple = smoothstep(0.62, 0.92, ripple_a * 0.58 + ripple_b * 0.42);
		base_albedo = mix(base_albedo, base_albedo * water_shimmer_tint, ripple * water_shimmer_strength);
	}
	float cloud_value = cloud_mask(world_pos.xz);
	float cloud_shadow = 1.0 - cloud_value * cloud_shadow_strength * terrain_shadow_response;
	float sunbreak = sunbreak_mask(world_pos.xz, cloud_value) * terrain_sunbreak_response;
	ALBEDO   = base_albedo * dim_factor * terrain_ambient_lift * cloud_shadow * (1.0 + sunbreak * cloud_sunbreak_strength * 0.68);
	EMISSION = emission_color.rgb * emission_strength + night_glow_color.rgb * night_glow_strength;
	EMISSION += cloud_sunbreak_tint * sunbreak * cloud_sunbreak_strength * 0.08;
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
