shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

uniform vec4 beam_color : source_color = vec4(1.0, 0.82, 0.60, 0.90);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float beam_seed = 0.0;
uniform float beam_strength : hint_range(0.0, 1.0) = 0.25;
uniform float cloud_shadow_scale : hint_range(0.01, 0.30) = 0.07;
uniform float cloud_shadow_speed : hint_range(0.0, 0.20) = 0.022;
uniform float cloud_pixel_size : hint_range(0.02, 1.0) = 0.24;
uniform vec2 cloud_drift = vec2(0.0, 0.0);

varying vec3 world_pos;

float cloud_wave(vec2 p) {
	return 0.5 + 0.5 * sin(p.x) * cos(p.y);
}

float cloud_mask(vec2 world_xz) {
	vec2 quantized_world = floor(world_xz / cloud_pixel_size) * cloud_pixel_size;
	vec2 flow = quantized_world * cloud_shadow_scale;
	flow += cloud_drift;
	flow += vec2(TIME * cloud_shadow_speed, TIME * cloud_shadow_speed * 0.62);

	float layer_a = cloud_wave(flow * 1.0 + vec2(0.8, 1.7));
	float layer_b = cloud_wave(flow * 1.9 + vec2(-2.4, 0.6));
	float layer_c = cloud_wave(flow * 3.1 + vec2(1.2, -1.8));
	return smoothstep(0.34, 0.78, layer_a * 0.45 + layer_b * 0.33 + layer_c * 0.22);
}

float sunbreak_mask(vec2 world_xz, float cloud_value) {
	vec2 quantized_world = floor(world_xz / cloud_pixel_size) * cloud_pixel_size;
	vec2 flow = quantized_world * (cloud_shadow_scale * 0.62);
	flow += cloud_drift * vec2(-0.38, 0.22);
	flow += vec2(-TIME * cloud_shadow_speed * 0.38, TIME * cloud_shadow_speed * 0.22);
	float layer_a = cloud_wave(flow * 1.2 + vec2(0.9, -1.7));
	float layer_b = cloud_wave(flow * 2.3 + vec2(-2.1, 0.4));
	float break_pattern = layer_a * 0.58 + layer_b * 0.42;
	float openings = smoothstep(0.46, 0.74, break_pattern);
	return openings * (1.0 - cloud_value);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float centered_x = abs(UV.x - 0.5) * 2.0;
	float width_mask = 1.0 - smoothstep(0.12, 0.82, centered_x);
	float core_mask = 1.0 - smoothstep(0.04, 0.32, centered_x);
	float top_fade = smoothstep(0.00, 0.12, UV.y);
	float bottom_fade = 1.0 - smoothstep(0.62, 1.00, UV.y);
	float length_mask = top_fade * bottom_fade;

	float streak_a = 0.5 + 0.5 * sin(UV.y * 16.0 + UV.x * 4.2 + TIME * 0.22 + beam_seed * 1.7);
	float streak_b = 0.5 + 0.5 * cos(UV.y * 28.0 - UV.x * 7.4 - TIME * 0.31 + beam_seed * 2.4);
	float streak_c = 0.5 + 0.5 * sin(UV.y * 9.0 + TIME * 0.18 + beam_seed * 0.8);
	float breakup = smoothstep(0.34, 0.86, streak_a * 0.45 + streak_b * 0.35 + streak_c * 0.20);
	float cloud_value = cloud_mask(world_pos.xz + vec2(beam_seed * 2.4, -beam_seed * 1.8));
	float sunbreak = sunbreak_mask(world_pos.xz + vec2(beam_seed * 1.7, beam_seed * 1.1), cloud_value);
	float cloud_opening = smoothstep(0.06, 0.56, sunbreak);
	float edge_fade = smoothstep(0.12, 0.64, sunbreak);
	float vertical_pulse = 0.80 + 0.20 * sin(UV.y * 7.0 + TIME * 0.55 + beam_seed * 1.3);
	float lens_fade = smoothstep(0.02, 0.18, UV.y) * (1.0 - smoothstep(0.74, 1.00, UV.y));

	float alpha = (width_mask * 0.56 + core_mask * 0.44) * length_mask * breakup * cloud_opening * edge_fade * vertical_pulse * lens_fade * intensity * beam_strength;
	ALBEDO = beam_color.rgb;
	EMISSION = beam_color.rgb * alpha * 2.2;
	ALPHA = alpha * beam_color.a;
}
