shader_type spatial;

// Window glass shader with per-vertex emission control
// Uses vertex colors to enable/disable emission on individual windows
// Fades emission based on time of day (bright at night, off during day)

// Material parameters
uniform vec4 albedo_color : source_color = vec4(0.64, 0.71, 0.96, 0.8);  // Light blue glass
uniform float roughness : hint_range(0.0, 1.0) = 0.1;
uniform float metallic : hint_range(0.0, 1.0) = 0.2;
uniform vec3 base_emission_color : source_color = vec3(1.0, 0.9, 0.75);  // Warm white
uniform float emission_energy : hint_range(0.0, 5.0) = 0.6;

// Time of day control (0-24 hours) - updated automatically by lighting controller
global uniform float time_of_day;

varying vec4 vertex_color;

void vertex() {
	vertex_color = COLOR;  // Pass vertex color to fragment shader
}

// Calculate emission fade based on time of day
float get_time_fade(float hour) {
	// Full emission at night (18:00-6:00)
	// Fade out during day (6:00-18:00)

	if (hour >= 19.0 || hour <= 5.0) {
		// Night time: full emission
		return 1.0;
	} else if (hour >= 6.0 && hour <= 17.0) {
		// Day time: no emission (daylight drowns it out)
		return 0.0;
	} else if (hour > 17.0 && hour < 19.0) {
		// Evening transition (17:00-19:00): fade in
		return (hour - 17.0) / 2.0;
	} else {
		// Morning transition (5:00-6:00): fade out
		return 1.0 - (hour - 5.0);
	}
}

// Simple hash function for randomness from UV
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Simple 2D smoothed noise for organic shapes
float smooth_noise(vec2 p, vec2 seed) {
	vec2 i = floor(p);
	vec2 f = fract(p);

	// Smoothstep interpolation for blur
	f = f * f * (3.0 - 2.0 * f);

	// Sample corners
	float a = hash(i + seed);
	float b = hash(i + vec2(1.0, 0.0) + seed);
	float c = hash(i + vec2(0.0, 1.0) + seed);
	float d = hash(i + vec2(1.0, 1.0) + seed);

	// Bilinear interpolation
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Generate random patterns to simulate curtains, blinds, furniture
float get_window_pattern(vec2 uv, vec2 window_id) {
	// Use window position as seed for consistent per-window patterns
	float pattern_type = hash(window_id);
	float pattern = 1.0;

	if (pattern_type < 0.25) {
		// Vertical blinds (25%) - reduced frequency, softer
		float blinds = fract(uv.x * 4.0);  // Reduced from 8.0
		pattern = smoothstep(0.35, 0.65, blinds) * 0.5 + 0.5;  // Softer transition
	} else if (pattern_type < 0.45) {
		// Horizontal blinds (20%) - reduced frequency
		float blinds = fract(uv.y * 3.0);  // Reduced from 6.0
		pattern = smoothstep(0.25, 0.55, blinds) * 0.5 + 0.5;
	} else if (pattern_type < 0.65) {
		// Curtains at edges (20%) - wider, softer
		float curtain = min(smoothstep(0.0, 0.3, uv.x), smoothstep(1.0, 0.7, uv.x));  // Wider curtains
		pattern = curtain * 0.4 + 0.6;  // Less occlusion
	} else {
		// Large furniture/objects (35%) - smooth organic shapes
		float noise1 = smooth_noise(uv * 2.0, window_id);  // Large shapes
		float noise2 = smooth_noise(uv * 4.0, window_id + vec2(5.3, 7.1));  // Medium detail

		// Combine noises for organic shapes
		float combined = noise1 * 0.7 + noise2 * 0.3;

		// Create darker regions for furniture silhouettes
		pattern = smoothstep(0.3, 0.7, combined) * 0.5 + 0.5;
	}

	return pattern;
}

void fragment() {
	// Base glass material
	ALBEDO = albedo_color.rgb;
	ALPHA = albedo_color.a;
	ROUGHNESS = roughness;
	METALLIC = metallic;

	// Emission controlled by vertex color AND time of day
	// If vertex color RGB is black (0,0,0), no emission
	// Otherwise, use vertex color RGB as emission base, alpha as multiplier
	float emission_strength = vertex_color.r + vertex_color.g + vertex_color.b;
	if (emission_strength > 0.01) {
		// Window is lit - apply time fade
		float time_fade = get_time_fade(time_of_day);

		// Apply window pattern (curtains, blinds, furniture)
		vec2 window_id = floor(UV * 100.0);  // Unique per window
		float pattern = get_window_pattern(UV, window_id);

		EMISSION = vertex_color.rgb * emission_energy * vertex_color.a * time_fade * pattern;
	} else {
		// Window is dark
		EMISSION = vec3(0.0);
	}
}
