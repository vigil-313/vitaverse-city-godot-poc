extends Node
class_name WallGenerator

## Wall generation coordinator
## Generates exterior walls for buildings with window cutouts

const WallSegmentBuilder = preload("res://scripts/generators/building/walls/segments/wall_segment_builder.gd")
const WindowParameters = preload("res://scripts/generators/building/utilities/window_parameters.gd")
const GeometryUtils = preload("res://scripts/generators/building/core/geometry_utils.gd")

## Commercial building types that get storefronts (skip ground floor windows)
const COMMERCIAL_TYPES = ["commercial", "retail", "office", "shop", "supermarket", "mall", "store"]

## Main entry point - generates all walls for a building
## Returns Dictionary with:
##   - "floor_emissions": Array of emission colors per floor for ceiling light coordination
##   - "wall_segments": Array of wall segment info for facade system
static func generate_walls(context, surfaces: Dictionary) -> Dictionary:
	var result = {
		"floor_emissions": [],
		"wall_segments": []
	}

	if context.footprint.size() < 3:
		return result

	var wall_surface = surfaces["wall"]
	var glass_surface = surfaces["glass"]
	var frame_surface = surfaces["frame"]

	var window_params = WindowParameters.get_parameters(context.building_type)

	# Check if this is a commercial building (storefronts will handle ground floor)
	var is_commercial = _is_commercial_building(context.building_type)

	# Aggregate floor emissions across all wall segments
	var aggregated_emissions = {}

	# Collect wall segment info for facade system
	var wall_segments = []

	for i in range(context.footprint.size()):
		var p1 = context.footprint[i] - context.center
		var p2 = context.footprint[(i + 1) % context.footprint.size()] - context.center
		var wall_length = p1.distance_to(p2)
		var wall_normal = GeometryUtils.calculate_wall_normal(p1, p2)

		# Store wall segment info for facade system
		wall_segments.append({
			"p1": p1,
			"p2": p2,
			"normal": wall_normal,
			"length": wall_length,
			"index": i
		})

		var segment_emissions = WallSegmentBuilder.create_wall_segment(
			p1, p2,
			context.height,
			context.floor_height,
			context.levels,
			window_params,
			context.detailed,
			wall_surface,
			glass_surface,
			frame_surface,
			is_commercial,  # Skip ground floor windows for commercial buildings
			context.building_type,
			context.building_id
		)

		# Merge segment emissions (keep maximum per floor)
		for floor_num in segment_emissions:
			var emission = segment_emissions[floor_num]
			if not aggregated_emissions.has(floor_num) or emission.a > aggregated_emissions[floor_num].a:
				aggregated_emissions[floor_num] = emission

	# Convert dictionary to array indexed by floor number
	var floor_emissions = []
	floor_emissions.resize(context.levels)
	for i in range(context.levels):
		floor_emissions[i] = aggregated_emissions.get(i, Color.BLACK)

	result["floor_emissions"] = floor_emissions
	result["wall_segments"] = wall_segments

	return result

## Check if building type is commercial (gets storefronts)
static func _is_commercial_building(building_type: String) -> bool:
	var type_lower = building_type.to_lower()
	for commercial in COMMERCIAL_TYPES:
		if type_lower.contains(commercial):
			return true
	return false
