shader_type canvas_item;

// Cel shading for the hex map canvas item.
// COLOR in a canvas_item fragment receives the vertex color from draw_* calls,
// so quantising it into discrete bands produces the cartoon shading effect.

void fragment() {
	float lum = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));

	// Three discrete brightness bands: shadow / mid / lit
	float band;
	if (lum < 0.28) {
		band = 0.18;
	} else if (lum < 0.60) {
		band = 0.60;
	} else {
		band = 1.00;
	}

	float scale = (lum > 0.001) ? (band / lum) : 1.0;
	COLOR.rgb   = clamp(COLOR.rgb * scale, vec3(0.0), vec3(1.0));
	// Alpha is preserved — transparent overlays (highlights, etc.) stay correct
}
