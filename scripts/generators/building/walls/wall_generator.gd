extends Node
class_name WallGenerator

## Wall generation coordinator
## Generates exterior walls for buildings with window cutouts

const WallSegmentBuilder = preload("res://scripts/generators/building/walls/segments/wall_segment_builder.gd")
const WindowParameters = preload("res://scripts/generators/building/utilities/window_parameters.gd")

## Main entry point - generates all walls for a building
## Returns Array of emission colors per floor for ceiling light coordination
static func generate_walls(context, surfaces: Dictionary) -> Array:
	if context.footprint.size() < 3:
		return []

	var wall_surface = surfaces["wall"]
	var glass_surface = surfaces["glass"]
	var frame_surface = surfaces["frame"]

	var window_params = WindowParameters.get_parameters(context.building_type)

	# Aggregate floor emissions across all wall segments
	var aggregated_emissions = {}

	for i in range(context.footprint.size()):
		var p1 = context.footprint[i] - context.center
		var p2 = context.footprint[(i + 1) % context.footprint.size()] - context.center

		var segment_emissions = WallSegmentBuilder.create_wall_segment(
			p1, p2,
			context.height,
			context.floor_height,
			context.levels,
			window_params,
			context.detailed,
			wall_surface,
			glass_surface,
			frame_surface
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

	return floor_emissions
