// Screen-space vignette: transparent centre, dark border.
// Applied via ColorRect on a CanvasLayer above the 3D world.
shader_type canvas_item;

uniform float strength  : hint_range(0.0, 1.5) = 0.65;
uniform float radius    : hint_range(0.1, 1.0)  = 0.75;
uniform float softness  : hint_range(0.0, 1.0)  = 0.50;
void fragment() {
	vec2  d         = UV - vec2(0.5);
	float dist      = length(d) / radius;
	float vignette  = smoothstep(1.0 - softness, 1.0, dist);
	COLOR = vec4(0.0, 0.0, 0.0, vignette * strength);
}
