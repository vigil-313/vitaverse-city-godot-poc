shader_type canvas_item;

// ============================================================================
// RETRO 3D SHADER - PSX/Saturn Style
// ============================================================================
//
// Applies palette quantization and Bayer dithering to create authentic
// retro 3D aesthetics. Applied to the upscaling TextureRect that displays
// the low-resolution SubViewport.
//
// Features:
//   - Bayer 8×8 ordered dithering for smooth gradients
//   - Color palette quantization (nearest color match in RGB space)
//   - Runtime-configurable settings
//   - Optional debug visualization

// ============================================================================
// UNIFORMS
// ============================================================================

// Palette configuration
uniform int palette_size : hint_range(2, 256) = 64;
uniform vec3 palette[256];  // RGB color palette (0.0-1.0 range)

// Dithering controls
uniform float dither_strength : hint_range(0.0, 2.0) = 1.0;
uniform bool enable_dithering = true;
uniform bool use_bayer_8x8 = true;  // false = use 4×4 instead

// Debug options
uniform bool show_palette_debug = false;

// ============================================================================
// BAYER MATRICES
// ============================================================================

// Bayer 8×8 matrix (64 unique threshold values, 0-63 normalized to 0.0-1.0)
const float bayer_8x8[64] = {
	 0.0/64.0, 32.0/64.0,  8.0/64.0, 40.0/64.0,  2.0/64.0, 34.0/64.0, 10.0/64.0, 42.0/64.0,
	48.0/64.0, 16.0/64.0, 56.0/64.0, 24.0/64.0, 50.0/64.0, 18.0/64.0, 58.0/64.0, 26.0/64.0,
	12.0/64.0, 44.0/64.0,  4.0/64.0, 36.0/64.0, 14.0/64.0, 46.0/64.0,  6.0/64.0, 38.0/64.0,
	60.0/64.0, 28.0/64.0, 52.0/64.0, 20.0/64.0, 62.0/64.0, 30.0/64.0, 54.0/64.0, 22.0/64.0,
	 3.0/64.0, 35.0/64.0, 11.0/64.0, 43.0/64.0,  1.0/64.0, 33.0/64.0,  9.0/64.0, 41.0/64.0,
	51.0/64.0, 19.0/64.0, 59.0/64.0, 27.0/64.0, 49.0/64.0, 17.0/64.0, 57.0/64.0, 25.0/64.0,
	15.0/64.0, 47.0/64.0,  7.0/64.0, 39.0/64.0, 13.0/64.0, 45.0/64.0,  5.0/64.0, 37.0/64.0,
	63.0/64.0, 31.0/64.0, 55.0/64.0, 23.0/64.0, 61.0/64.0, 29.0/64.0, 53.0/64.0, 21.0/64.0
};

// Bayer 4×4 matrix (16 unique threshold values, 0-15 normalized to 0.0-1.0)
const float bayer_4x4[16] = {
	 0.0/16.0,  8.0/16.0,  2.0/16.0, 10.0/16.0,
	12.0/16.0,  4.0/16.0, 14.0/16.0,  6.0/16.0,
	 3.0/16.0, 11.0/16.0,  1.0/16.0,  9.0/16.0,
	15.0/16.0,  7.0/16.0, 13.0/16.0,  5.0/16.0
};

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

// Get Bayer threshold value for screen coordinates
float get_bayer_threshold(vec2 screen_coord) {
	if (use_bayer_8x8) {
		int x = int(screen_coord.x) % 8;
		int y = int(screen_coord.y) % 8;
		return bayer_8x8[y * 8 + x];
	} else {
		int x = int(screen_coord.x) % 4;
		int y = int(screen_coord.y) % 4;
		return bayer_4x4[y * 4 + x];
	}
}

// Find closest color in palette (linear search)
vec3 find_closest_palette_color(vec3 color) {
	float min_dist = 999999.0;
	vec3 closest = palette[0];

	for (int i = 0; i < palette_size; i++) {
		vec3 diff = color - palette[i];
		float dist = dot(diff, diff);  // Squared Euclidean distance (faster than sqrt)

		if (dist < min_dist) {
			min_dist = dist;
			closest = palette[i];
		}
	}

	return closest;
}

// ============================================================================
// FRAGMENT SHADER
// ============================================================================

void fragment() {
	// Sample the SubViewport texture
	vec3 original_color = texture(TEXTURE, UV).rgb;
	vec3 final_color = original_color;

	// Debug: Show palette swatch
	bool is_debug_area = false;
	if (show_palette_debug) {
		// Show palette in top-left corner (16 colors per row)
		vec2 screen_size = 1.0 / TEXTURE_PIXEL_SIZE;
		vec2 pixel_pos = UV * screen_size;

		float swatch_size = 32.0;  // 32×32 pixel swatches
		int colors_per_row = 16;

		if (pixel_pos.x < swatch_size * float(colors_per_row) &&
		    pixel_pos.y < swatch_size * ceil(float(palette_size) / float(colors_per_row))) {
			int swatch_x = int(pixel_pos.x / swatch_size);
			int swatch_y = int(pixel_pos.y / swatch_size);
			int palette_idx = swatch_y * colors_per_row + swatch_x;

			if (palette_idx < palette_size) {
				final_color = palette[palette_idx];
				is_debug_area = true;
			}
		}
	}

	// Only apply dithering and quantization if not in debug area
	if (!is_debug_area) {
		// Apply dithering
		vec3 dithered_color = original_color;

		if (enable_dithering) {
			// Get Bayer threshold for this pixel's screen position
			vec2 screen_coord = FRAGCOORD.xy;
			float threshold = get_bayer_threshold(screen_coord);

			// Apply dithering: add noise based on threshold (-0.5 to +0.5 range)
			float dither_amount = (threshold - 0.5) * dither_strength * 0.08;
			dithered_color = original_color + vec3(dither_amount);

			// Clamp to valid range
			dithered_color = clamp(dithered_color, 0.0, 1.0);
		}

		// Quantize to palette
		final_color = find_closest_palette_color(dithered_color);
	}

	// Output
	COLOR = vec4(final_color, 1.0);
}
