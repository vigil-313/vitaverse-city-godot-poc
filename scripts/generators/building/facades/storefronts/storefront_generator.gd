extends Node
class_name StorefrontGenerator

## Storefront generator coordinator
## Creates commercial ground floor facades with display windows, awnings, and signage

const DisplayWindow = preload("res://scripts/generators/building/facades/storefronts/display_window.gd")
const AwningGenerator = preload("res://scripts/generators/building/facades/storefronts/awning_generator.gd")
const SignagePanel = preload("res://scripts/generators/building/facades/storefronts/signage_panel.gd")
const GeometryUtils = preload("res://scripts/generators/building/core/geometry_utils.gd")

## Minimum wall length to receive a storefront (meters)
const MIN_WALL_LENGTH = 3.0

## Storefront dimensions
const DISPLAY_WINDOW_BOTTOM = 0.3  # 30cm sill height
const DISPLAY_WINDOW_TOP = 2.8    # 2.8m window top
const STOREFRONT_HEIGHT = 3.5     # Total ground floor height
const SIDE_MARGIN = 0.4           # 40cm margin from wall edges

## Main entry point - generates storefronts for commercial ground floor
static func generate(context, surfaces: Dictionary, wall_segments: Array) -> void:
	if context.levels < 1:
		return

	var wall_surface = surfaces["wall"]
	var glass_surface = surfaces["glass"]
	var frame_surface = surfaces["frame"]

	# Process each wall segment for ground floor storefront
	for segment in wall_segments:
		var wall_length = segment.length

		# Skip walls too short for storefronts
		if wall_length < MIN_WALL_LENGTH:
			continue

		# Generate storefront components for this wall
		_generate_storefront_for_wall(
			segment,
			context,
			wall_surface,
			glass_surface,
			frame_surface
		)

## Generate complete storefront for a single wall segment
static func _generate_storefront_for_wall(
	segment: Dictionary,
	context,
	wall_surface,
	glass_surface,
	frame_surface
) -> void:
	var p1 = segment.p1
	var p2 = segment.p2
	var wall_normal = segment.normal
	var wall_length = segment.length
	var floor_height = context.floor_height

	# Calculate storefront bounds (leave margins on sides)
	var margin_t = SIDE_MARGIN / wall_length
	var storefront_left_t = margin_t
	var storefront_right_t = 1.0 - margin_t

	# Ensure valid bounds
	if storefront_left_t >= storefront_right_t:
		return

	# Calculate display window positions (80% of storefront width)
	var storefront_width = (storefront_right_t - storefront_left_t) * wall_length
	var display_width = storefront_width * 0.8
	var display_margin = (storefront_width - display_width) / 2.0

	var display_left_t = storefront_left_t + (display_margin / wall_length)
	var display_right_t = storefront_right_t - (display_margin / wall_length)

	# Generate display window
	var window_top = min(DISPLAY_WINDOW_TOP, floor_height - 0.3)
	DisplayWindow.generate(
		p1, p2,
		display_left_t, display_right_t,
		DISPLAY_WINDOW_BOTTOM, window_top,
		wall_normal,
		wall_surface,
		glass_surface,
		frame_surface
	)

	# Generate awning above display window
	var awning_bottom = window_top + 0.1
	AwningGenerator.generate(
		p1, p2,
		display_left_t, display_right_t,
		awning_bottom,
		wall_normal,
		wall_surface
	)

	# Generate signage panel above awning
	var signage_bottom = awning_bottom + AwningGenerator.AWNING_HEIGHT + 0.1
	var signage_top = min(signage_bottom + SignagePanel.SIGNAGE_HEIGHT, floor_height - 0.1)

	if signage_top > signage_bottom + 0.2:  # Only if enough space
		SignagePanel.generate(
			p1, p2,
			storefront_left_t, storefront_right_t,
			signage_bottom, signage_top,
			wall_normal,
			wall_surface
		)
