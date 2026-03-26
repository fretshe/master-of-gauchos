shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled, blend_add;

uniform float star_visibility : hint_range(0.0, 1.0) = 0.0;
uniform vec3 star_color : source_color = vec3(0.88, 0.92, 1.0);

varying vec3 local_dir;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	local_dir = normalize(VERTEX);
}

void fragment() {
	vec3 dir = normalize(local_dir);
	float horizon_fade = smoothstep(0.05, 0.35, dir.y);

	vec2 uv;
	uv.x = atan(dir.x, dir.z) / (PI * 2.0) + 0.5;
	uv.y = acos(clamp(dir.y, -1.0, 1.0)) / PI;

	vec2 coarse = floor(uv * vec2(420.0, 220.0));
	vec2 fine = floor(uv * vec2(760.0, 420.0));

	float star_a = step(0.9978, hash21(coarse));
	float star_b = step(0.9992, hash21(fine));
	float twinkle = 0.75 + 0.25 * sin(TIME * 1.4 + coarse.x * 0.31 + coarse.y * 0.17);
	float stars = max(star_a, star_b * 0.85) * twinkle;

	vec3 color = star_color * stars * horizon_fade * star_visibility;
	ALBEDO = color;
	EMISSION = color * 3.2;
	ALPHA = clamp(stars * horizon_fade * star_visibility, 0.0, 1.0);
}
