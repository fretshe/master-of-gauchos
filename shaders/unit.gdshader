shader_type canvas_item;

// Applied to AnimatedSprite2D nodes (Master unit sprites).
// Draws a 1-texel black outline around the sprite edge and
// applies soft 2-band cel shading to the sprite colors.

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// ── Outline ─────────────────────────────────────────────────────────────────
	// Transparent pixels adjacent to an opaque pixel become a black outline.
	if (tex.a < 0.5) {
		vec2 pix = TEXTURE_PIXEL_SIZE * 1.5;
		float adj = max(
			max(texture(TEXTURE, UV + vec2( pix.x,  0.0  )).a,
			    texture(TEXTURE, UV + vec2(-pix.x,  0.0  )).a),
			max(texture(TEXTURE, UV + vec2( 0.0,   pix.y )).a,
			    texture(TEXTURE, UV + vec2( 0.0,  -pix.y )).a)
		);
		COLOR = (adj > 0.5) ? vec4(0.0, 0.0, 0.0, 1.0) : vec4(0.0);
		return;
	}

	// ── Cel shading: 2 bands ─────────────────────────────────────────────────────
	float lum   = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float band  = (lum < 0.45) ? 0.68 : 1.0;
	float scale = (lum > 0.001) ? (band / lum) : 1.0;
	tex.rgb     = clamp(tex.rgb * scale, vec3(0.0), vec3(1.0));

	// Multiply by vertex modulate (carries tint + alpha from the sprite's modulate property)
	COLOR = tex * COLOR;
}
