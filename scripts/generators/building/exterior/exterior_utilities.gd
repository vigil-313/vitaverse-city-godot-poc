extends Node
class_name ExteriorUtilities

## Exterior Utilities Coordinator
## Adds gutters, downspouts, satellite dishes, and antennas to buildings

const GutterGenerator = preload("res://scripts/generators/building/exterior/gutter_generator.gd")
const DownspoutGenerator = preload("res://scripts/generators/building/exterior/downspout_generator.gd")
const SatelliteDishGenerator = preload("res://scripts/generators/building/exterior/satellite_dish_generator.gd")
const AntennaGenerator = preload("res://scripts/generators/building/exterior/antenna_generator.gd")

## Placement chances
const GUTTER_CHANCE = 0.7        # 70% of buildings get gutters
const SATELLITE_CHANCE = 0.25   # 25% get satellite dishes
const ANTENNA_CHANCE = 0.15     # 15% get antennas (older buildings)

## Main entry point - add exterior utilities to a building
static func add_utilities(
	context,
	surfaces: Dictionary,
	wall_segments: Array
) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(context.building_id) + "_utilities")

	var wall_surface = surfaces["wall"]
	var frame_surface = surfaces["frame"]

	# Gutters and downspouts
	if rng.randf() < GUTTER_CHANCE:
		_add_gutters_and_downspouts(context, wall_segments, frame_surface, rng)

	# Satellite dish (residential mostly)
	var building_type = context.building_type.to_lower()
	var is_residential = building_type.contains("residential") or building_type.contains("apartment") or building_type.contains("house")

	if is_residential and rng.randf() < SATELLITE_CHANCE:
		_add_satellite_dish(context, wall_segments, frame_surface, rng)

	# Antenna (older style, less common)
	if is_residential and rng.randf() < ANTENNA_CHANCE:
		_add_antenna(context, frame_surface, rng)

## Add gutters along roof edges and downspouts at corners
static func _add_gutters_and_downspouts(
	context,
	wall_segments: Array,
	surface,
	rng: RandomNumberGenerator
) -> void:
	# Add gutter to each wall segment at roof level
	for wall in wall_segments:
		GutterGenerator.generate(
			wall.p1,
			wall.p2,
			context.height,
			wall.normal,
			surface
		)

	# Add downspouts at 2-3 corners
	var num_downspouts = rng.randi_range(2, min(3, wall_segments.size()))
	var used_corners = []

	for i in range(num_downspouts):
		var corner_idx = rng.randi() % wall_segments.size()
		if corner_idx in used_corners:
			continue
		used_corners.append(corner_idx)

		var wall = wall_segments[corner_idx]
		DownspoutGenerator.generate(
			wall.p1,
			context.height,
			wall.normal,
			surface
		)

## Add satellite dish to wall or roof
static func _add_satellite_dish(
	context,
	wall_segments: Array,
	surface,
	rng: RandomNumberGenerator
) -> void:
	# Pick a random wall (preferably south-facing for realism, but we'll randomize)
	var wall_idx = rng.randi() % wall_segments.size()
	var wall = wall_segments[wall_idx]

	# Position on upper part of wall
	var dish_height = context.height * rng.randf_range(0.6, 0.85)
	var wall_t = rng.randf_range(0.2, 0.8)
	var dish_pos_2d = wall.p1.lerp(wall.p2, wall_t)

	SatelliteDishGenerator.generate(
		dish_pos_2d,
		dish_height,
		wall.normal,
		surface
	)

## Add TV antenna on roof
static func _add_antenna(
	context,
	surface,
	rng: RandomNumberGenerator
) -> void:
	# Position near center of roof
	var center = context.center
	var offset = Vector2(
		rng.randf_range(-2.0, 2.0),
		rng.randf_range(-2.0, 2.0)
	)

	# Antenna position (relative to building, so offset from 0,0)
	var antenna_pos = Vector3(offset.x, context.height, -offset.y)

	AntennaGenerator.generate(antenna_pos, surface, rng)
