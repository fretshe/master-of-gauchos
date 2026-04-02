shader_type canvas_item;

uniform vec4 accent_color : source_color = vec4(0.30, 0.82, 0.96, 1.0);
uniform float fx_time = 0.0;
uniform float hover_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec2 mouse_uv = vec2(0.5, 0.5);
uniform float spent_amount : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	float hover = hover_amount * (1.0 - spent_amount);
	vec2 centered = UV - vec2(0.5);
	float bend_x = centered.x * abs(centered.y) * (mouse_uv.x - 0.5) * 18.0 * hover;
	float bend_y = centered.y * abs(centered.x) * (mouse_uv.y - 0.5) * 14.0 * hover;
	VERTEX.x += bend_x;
	VERTEX.y += bend_y - hover * 4.0;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a <= 0.001) {
		COLOR = tex;
	} else {
		float hover = hover_amount * (1.0 - spent_amount);
		vec2 centered = UV - vec2(0.5);
		vec2 light_dir = normalize(vec2(0.85, -0.55));
		float glossy_band = smoothstep(0.18, 0.52, dot(centered, light_dir) + hover * 0.40 + sin(fx_time * 2.2) * 0.08);
		float glossy_core = smoothstep(0.52, 0.76, glossy_band) * hover;
		float fresnel = pow(1.0 - clamp(length(centered) * 1.45, 0.0, 1.0), 2.0);
		float mouse_glint = 1.0 - clamp(distance(UV, mouse_uv) * 2.4, 0.0, 1.0);
		float top_sheen = smoothstep(0.75, 0.02, UV.y) * 0.18;
		float rim = smoothstep(0.80, 0.08, abs(centered.x)) * smoothstep(0.84, 0.10, abs(centered.y));

		vec3 color = tex.rgb;
		color *= 0.96 + hover * 0.08;
		color += accent_color.rgb * glossy_core * 0.16;
		color += vec3(1.0) * (top_sheen + fresnel * 0.06 + mouse_glint * 0.10 * hover);
		color += accent_color.rgb * rim * hover * 0.10;

		float desat = spent_amount * 0.65;
		float gray = dot(color, vec3(0.299, 0.587, 0.114));
		color = mix(color, vec3(gray), desat);

		COLOR = vec4(color, tex.a);
	}
}
