extends Node
class_name WallGenerator

## Wall generation coordinator
## Generates exterior walls for buildings with window cutouts

const WallSegmentBuilder = preload("res://scripts/generators/building/walls/segments/wall_segment_builder.gd")
const WindowParameters = preload("res://scripts/generators/building/utilities/window_parameters.gd")

## Main entry point - generates all walls for a building
static func generate_walls(context, surfaces: Dictionary) -> void:
	if context.footprint.size() < 3:
		return

	var wall_surface = surfaces["wall"]
	var glass_surface = surfaces["glass"]
	var frame_surface = surfaces["frame"]

	var window_params = WindowParameters.get_parameters(context.building_type)

	for i in range(context.footprint.size()):
		var p1 = context.footprint[i] - context.center
		var p2 = context.footprint[(i + 1) % context.footprint.size()] - context.center

		WallSegmentBuilder.create_wall_segment(
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
