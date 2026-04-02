shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform float cloud_opacity : hint_range(0.0, 0.6) = 0.18;

void fragment() {
	ALBEDO = vec3(0.0);
	ALPHA = cloud_opacity;
}
