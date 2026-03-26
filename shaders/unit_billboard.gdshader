shader_type spatial;
render_mode unshaded, cull_disabled, billboard, blend_mix, depth_draw_alpha_prepass;

uniform sampler2D sprite_texture : source_color, hint_default_white;
uniform bool use_texture = false;
uniform vec4 albedo_color : source_color = vec4(0.15, 0.40, 0.85, 1.0);
uniform float outline_size : hint_range(0.01, 0.20) = 0.08;
uniform vec3 fake_light_dir = vec3(0.35, 0.85, 0.40);
uniform vec3 fake_light_color : source_color = vec3(1.0, 0.95, 0.9);
uniform vec3 ambient_tint : source_color = vec3(0.72, 0.72, 0.78);
uniform float light_strength : hint_range(0.0, 2.0) = 0.8;
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.30;
uniform vec3 rim_color : source_color = vec3(0.75, 0.85, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.0;
uniform float emission_strength : hint_range(0.0, 2.0) = 0.0;

vec3 apply_fake_lighting(vec3 color) {
	vec3 light_dir = normalize(fake_light_dir);
	float ndotl = clamp(light_dir.y * 0.5 + 0.5, 0.0, 1.0);
	float lit = mix(1.0 - shadow_strength, 1.0 + light_strength * 0.35, ndotl);
	vec3 base = color * ambient_tint;
	vec3 direct = color * fake_light_color * lit;
	float rim = pow(1.0 - abs(UV.x - 0.5) * 2.0, 2.0) * pow(1.0 - UV.y, 1.4);
	return mix(base, direct, 0.72) + rim_color * rim * rim_strength;
}

void fragment() {
	if (use_texture) {
		vec4 base = texture(sprite_texture, UV) * albedo_color;

		float ow = outline_size * 0.25;
		float a_r = texture(sprite_texture, UV + vec2(ow, 0.0)).a;
		float a_l = texture(sprite_texture, UV + vec2(-ow, 0.0)).a;
		float a_u = texture(sprite_texture, UV + vec2(0.0, ow)).a;
		float a_d = texture(sprite_texture, UV + vec2(0.0, -ow)).a;
		float edge = max(max(a_r, a_l), max(a_u, a_d));

		if (base.a < 0.05 && edge > 0.50) {
			ALBEDO = vec3(0.0);
			EMISSION = vec3(0.0);
			ALPHA = 1.0;
		} else {
			vec3 lit = apply_fake_lighting(base.rgb);
			ALBEDO = lit;
			EMISSION = lit * emission_strength;
			ALPHA = base.a;
		}
	} else {
		float b = outline_size;
		bool on_edge = UV.x < b || UV.x > 1.0 - b || UV.y < b || UV.y > 1.0 - b;
		vec3 lit = apply_fake_lighting(albedo_color.rgb);
		ALBEDO = on_edge ? vec3(0.0) : lit;
		EMISSION = lit * emission_strength;
		ALPHA = 1.0;
	}
}
