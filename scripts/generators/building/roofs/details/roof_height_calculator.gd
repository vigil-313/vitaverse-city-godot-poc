extends Node
class_name RoofHeightCalculator

## Calculates roof height from OSM data
## Supports explicit height, angle calculation, roof levels, or defaults

## Calculate roof height from OSM data
static func calculate_roof_height(building_height: float, osm_data: Dictionary) -> float:
	# Priority 1: Explicit roof:height from OSM (in meters)
	var roof_height_osm = osm_data.get("roof:height", 0.0)
	if roof_height_osm > 0:
		return roof_height_osm

	# Priority 2: Calculate from roof:angle and building dimensions
	var roof_angle = osm_data.get("roof:angle", 0.0)
	if roof_angle > 0:
		# Get building dimensions to calculate rise from angle
		var footprint = osm_data.get("footprint", [])
		if footprint.size() >= 3:
			var min_x = INF
			var max_x = -INF
			var min_y = INF
			var max_y = -INF

			for point in footprint:
				min_x = min(min_x, point.x)
				max_x = max(max_x, point.x)
				min_y = min(min_y, point.y)
				max_y = max(max_y, point.y)

			var width = max_x - min_x
			var depth = max_y - min_y
			var half_span = min(width, depth) / 2.0

			# Calculate height from angle: tan(angle) = height / half_span
			# roof:angle is typically in degrees
			var angle_rad = deg_to_rad(roof_angle)
			return tan(angle_rad) * half_span

	# Priority 3: Use roof:levels if available (3m per roof level)
	var roof_levels = osm_data.get("roof:levels", 0)
	if roof_levels > 0:
		return roof_levels * 3.0

	# Fallback: 15% of building height (default)
	return building_height * 0.15
