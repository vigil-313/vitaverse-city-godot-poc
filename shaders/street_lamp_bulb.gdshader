shader_type spatial;
render_mode unshaded;

// Time of day from lighting controller
global uniform float time_of_day;

void fragment() {
	// Calculate time fade (on at night, off during day)
	float time_fade = 0.0;

	if (time_of_day >= 19.0 || time_of_day <= 5.0) {
		// Night (7pm - 5am): full glow
		time_fade = 1.0;
	} else if (time_of_day > 17.0 && time_of_day < 19.0) {
		// Evening transition (5pm - 7pm): fade in
		time_fade = (time_of_day - 17.0) / 2.0;
	} else if (time_of_day > 5.0 && time_of_day < 6.0) {
		// Morning transition (5am - 6am): fade out
		time_fade = 1.0 - (time_of_day - 5.0);
	} else {
		// Day (6am - 5pm): off
		time_fade = 0.0;
	}

	// Warm street light color
	vec3 warm_light = vec3(1.0, 0.95, 0.85);
	ALBEDO = warm_light * 0.5;  // Slight base color
	EMISSION = warm_light * 8.0 * time_fade;  // Very bright glow when on (was 4.0)
}
