shader_type canvas_item;

uniform vec4 dim_color : source_color = vec4(0.0, 0.0, 0.0, 0.62);
uniform vec4 hole_a = vec4(-1000.0, -1000.0, 0.0, 0.0);
uniform vec4 hole_b = vec4(-1000.0, -1000.0, 0.0, 0.0);
uniform float feather = 18.0;

float hole_mask(vec2 p, vec4 rect_data, float feather_px) {
	if (rect_data.z <= 0.0 || rect_data.w <= 0.0) {
		return 1.0;
	}
	vec2 rmin = rect_data.xy;
	vec2 rmax = rect_data.xy + rect_data.zw;
	bool inside = p.x >= rmin.x && p.x <= rmax.x && p.y >= rmin.y && p.y <= rmax.y;
	if (inside) {
		return 0.0;
	}
	vec2 delta = max(max(rmin - p, vec2(0.0)), p - rmax);
	float dist = length(delta);
	return smoothstep(0.0, feather_px, dist);
}

void fragment() {
	vec2 pixel_pos = SCREEN_UV / SCREEN_PIXEL_SIZE;
	float mask_a = hole_mask(pixel_pos, hole_a, feather);
	float mask_b = hole_mask(pixel_pos, hole_b, feather);
	float alpha_mask = min(mask_a, mask_b);
	COLOR = vec4(dim_color.rgb, dim_color.a * alpha_mask);
}
