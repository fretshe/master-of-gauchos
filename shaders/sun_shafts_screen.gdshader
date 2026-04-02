shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec2 sun_screen_pos = vec2(0.50, -0.12);
uniform vec2 ray_direction = vec2(0.0, 1.0);
uniform vec4 ray_color : source_color = vec4(1.0, 0.73, 0.46, 1.0);
uniform float intensity : hint_range(0.0, 2.5) = 0.0;
uniform float spread : hint_range(0.01, 1.0) = 0.24;
uniform float edge_softness : hint_range(0.1, 8.0) = 4.8;
uniform float streak_scale : hint_range(1.0, 40.0) = 8.0;
uniform float streak_speed : hint_range(0.0, 4.0) = 0.16;
uniform float banding : hint_range(0.0, 1.0) = 0.34;
uniform float time = 0.0;

float cloud_wave(vec2 p) {
	return 0.5 + 0.5 * sin(p.x) * cos(p.y);
}

void fragment() {
	vec2 dir = normalize(ray_direction);
	vec2 rel = UV - sun_screen_pos;
	float along = dot(rel, dir);
	float across = dot(rel, vec2(-dir.y, dir.x));

	float forward_mask = smoothstep(-0.02, 0.18, along);
	float width = mix(spread * 0.48, spread * 1.08, clamp(along * 0.85 + 0.15, 0.0, 1.0));
	float cross_mask = 1.0 - smoothstep(width, width * edge_softness, abs(across));
	float length_mask = exp(-max(along, 0.0) * 1.7);

	float streak_a = 0.5 + 0.5 * sin(along * streak_scale - time * streak_speed + across * 8.0);
	float streak_b = 0.5 + 0.5 * cos(along * (streak_scale * 1.7) + time * (streak_speed * 1.4) - across * 12.0);
	float streaks = mix(1.0, streak_a * 0.65 + streak_b * 0.35, banding);
	vec2 cloud_uv = vec2(along * 2.4, across * 4.2 + along * 0.8);
	float cloud_a = cloud_wave(cloud_uv * 1.0 + vec2(time * 0.06, -time * 0.03));
	float cloud_b = cloud_wave(cloud_uv * 1.9 + vec2(-1.8 + time * 0.04, 0.6));
	float cloud_c = cloud_wave(cloud_uv * 3.2 + vec2(0.9 - time * 0.02, -1.5));
	float cloud_mix = cloud_a * 0.46 + cloud_b * 0.32 + cloud_c * 0.22;
	float cloud_gaps = smoothstep(0.44, 0.72, cloud_mix);
	float hole_mask = smoothstep(0.20, 0.0, abs(across) / max(width * 1.15, 0.001));
	float center_beam = 1.0 - smoothstep(width * 0.35, width * 0.92, abs(across));
	float side_beam_a = 1.0 - smoothstep(width * 0.30, width * 0.82, abs(across - width * 0.62));
	float side_beam_b = 1.0 - smoothstep(width * 0.30, width * 0.82, abs(across + width * 0.70));
	float beam_cluster = max(center_beam, max(side_beam_a * 0.68, side_beam_b * 0.58));
	float wide_beams = beam_cluster * forward_mask * exp(-max(along, 0.0) * 1.10);
	float canopy_glow = smoothstep(0.18, 0.0, distance(UV, sun_screen_pos + vec2(0.0, 0.06)));

	float glow = smoothstep(0.12, 0.0, length(rel));
	float rays = forward_mask * cross_mask * length_mask * streaks * cloud_gaps;
	float core = forward_mask * hole_mask * exp(-max(along, 0.0) * 1.2) * cloud_gaps;
	float top_falloff = 1.0 - smoothstep(0.42, 0.92, UV.y);
	float alpha = (wide_beams * 0.92 + rays * 0.44 + core * 0.18 + glow * 0.10 + canopy_glow * 0.26) * intensity * top_falloff;

	COLOR = vec4(ray_color.rgb, alpha);
}
