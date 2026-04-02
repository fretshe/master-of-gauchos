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
uniform float light_bands : hint_range(2.0, 5.0) = 3.0;
uniform vec3 shadow_tint : source_color = vec3(0.46, 0.46, 0.54);
uniform vec3 mid_tint : source_color = vec3(0.82, 0.82, 0.88);
uniform vec3 highlight_tint : source_color = vec3(1.12, 1.12, 1.16);
uniform float cloud_shadow_strength : hint_range(0.0, 0.6) = 0.22;
uniform float cloud_shadow_scale : hint_range(0.01, 0.30) = 0.07;
uniform float cloud_shadow_speed : hint_range(0.0, 0.20) = 0.022;
uniform float cloud_shadow_softness : hint_range(0.01, 0.30) = 0.11;
uniform float cloud_sunbreak_strength : hint_range(0.0, 0.8) = 0.07;
uniform vec3 cloud_sunbreak_tint : source_color = vec3(1.12, 1.06, 0.88);
uniform float cloud_pixel_size : hint_range(0.02, 1.0) = 0.24;

varying vec3 world_pos;

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
	float cloud_value = cloud_mask(world_pos.xz);
	float cloud_shadow = 1.0 - cloud_value * cloud_shadow_strength;
	float sunbreak = sunbreak_mask(world_pos.xz, cloud_value);
	ALBEDO    = albedo_color.rgb * cloud_shadow * (1.0 + sunbreak * cloud_sunbreak_strength * 0.64);
	EMISSION  = emission_color.rgb * emission_strength + night_glow_color.rgb * night_glow_strength;
	EMISSION += cloud_sunbreak_tint * sunbreak * cloud_sunbreak_strength * 0.06;
	ALPHA     = opacity;
	ROUGHNESS = 0.70;
	METALLIC  = 0.10;
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
