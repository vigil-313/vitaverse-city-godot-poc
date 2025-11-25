extends Node
class_name EmissionController

## Controls window emission (lighting) with color variation and occupancy simulation

## Generate emission color for a window (40% chance of being lit)
static func generate_window_emission() -> Color:
	var window_emission_color = Color.BLACK  # Default: no emission

	if randf() < 0.4:
		# Window is lit - emission stored in vertex color RGB
		# Alpha channel stores emission multiplier with WIDE variation
		var emission_multiplier = randf_range(0.2, 1.0)

		# Add COLOR VARIATION to simulate different light sources and occupancy
		var color_roll = randf()
		var emission_base: Color

		if color_roll < 0.60:
			# Warm yellow/orange (most common - incandescent/warm LED)
			emission_base = Color(1.0, randf_range(0.85, 0.95), randf_range(0.6, 0.8))
		elif color_roll < 0.85:
			# Neutral white (cool LED, office lighting)
			emission_base = Color(randf_range(0.95, 1.0), randf_range(0.95, 1.0), randf_range(0.9, 1.0))
		elif color_roll < 0.95:
			# Dim warm (candles, dim lamps, cozy)
			emission_base = Color(1.0, randf_range(0.7, 0.85), randf_range(0.4, 0.6)) * 0.6
		else:
			# Blue glow (TV/monitor light)
			emission_base = Color(randf_range(0.6, 0.8), randf_range(0.7, 0.9), 1.0) * 0.8

		# Apply occupancy variation (curtains, blinds, furniture blocking)
		# Reduce alpha for "partially blocked" windows
		if randf() < 0.3:
			emission_multiplier *= randf_range(0.3, 0.6)  # Curtains/blinds partially closed

		window_emission_color = Color(emission_base.r, emission_base.g, emission_base.b, emission_multiplier)

	return window_emission_color
