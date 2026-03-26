shader_type canvas_item;

// Screen-edge vignette applied to a fullscreen ColorRect on its own CanvasLayer.
// Darkens the perimeter of the screen without affecting readability at the centre.
// The ColorRect itself should have color = (0,0,0,0); the shader drives the alpha.

void fragment() {
	// Distance from UV centre, stretched so the vignette feels wide and subtle
	vec2  off  = UV - vec2(0.5);
	float dist = length(off * vec2(1.0, 1.3));  // slightly taller than wide
	float vig  = smoothstep(0.38, 0.78, dist);
	COLOR = vec4(0.0, 0.0, 0.0, vig * 0.52);
}
