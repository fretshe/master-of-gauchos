shader_type spatial;
render_mode unshaded, cull_disabled, billboard, blend_mix, depth_draw_alpha_prepass;

uniform sampler2D sprite_texture : source_color, filter_nearest, repeat_disable;
uniform vec4 tint_color : source_color = vec4(0.80, 1.00, 0.82, 1.0);
uniform float emission_strength : hint_range(0.0, 1.5) = 0.10;
uniform float wind_strength : hint_range(0.0, 0.08) = 0.028;
uniform float wind_speed : hint_range(0.0, 4.0) = 1.6;
uniform float wind_offset : hint_range(0.0, 32.0) = 0.0;
uniform float sway_bias : hint_range(0.0, 1.0) = 0.78;

void vertex() {
	float sway_mask = smoothstep(0.32, 1.0, UV.y);
	float phase = TIME * wind_speed + wind_offset;
	float snapped = round(sin(phase) * 6.0) / 6.0;
	VERTEX.x += snapped * wind_strength * sway_mask;
	VERTEX.z += snapped * wind_strength * 0.18 * sway_mask;
}

void fragment() {
	vec4 base = texture(sprite_texture, UV);
	if (base.a < 0.05) {
		ALPHA = 0.0;
		return;
	}

	vec3 lit = base.rgb * mix(vec3(1.0), tint_color.rgb, 0.35);
	float top_light = mix(0.88, 1.14, UV.y);
	float side_shade = mix(0.94, 1.02, 1.0 - abs(UV.x - 0.5) * 2.0);
	lit *= top_light * side_shade;
	lit = mix(lit * 0.86, lit, sway_bias);

	ALBEDO = lit;
	EMISSION = lit * emission_strength;
	ALPHA = base.a * tint_color.a;
}
