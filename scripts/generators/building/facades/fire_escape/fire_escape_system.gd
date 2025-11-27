extends Node
class_name FireEscapeSystem

## Fire Escape System
## Generates metal fire escapes on residential building walls
## Consists of landings, stairs, railings, and a drop ladder

const LandingGenerator = preload("res://scripts/generators/building/facades/fire_escape/landing_generator.gd")
const StairGenerator = preload("res://scripts/generators/building/facades/fire_escape/stair_generator.gd")
const EscapeRailing = preload("res://scripts/generators/building/facades/fire_escape/escape_railing.gd")
const LadderGenerator = preload("res://scripts/generators/building/facades/fire_escape/ladder_generator.gd")

## Fire escape dimensions
const LANDING_WIDTH = 1.2       # 1.2m wide platform
const LANDING_DEPTH = 1.0       # 1.0m deep (from wall)
const STAIR_WIDTH = 0.8         # 80cm wide stairs
const WALL_OFFSET = 0.05        # 5cm from wall surface

## Placement parameters
const MIN_FLOORS_FOR_ESCAPE = 3  # Only buildings 3+ floors get fire escapes
const ESCAPE_CHANCE = 0.4        # 40% of eligible buildings get fire escapes

## Main entry point - maybe add fire escape to a building wall
static func maybe_add_fire_escape(
	wall_segment: Dictionary,
	context,
	surfaces: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	# Only residential buildings
	var building_type = context.building_type.to_lower()
	if building_type.contains("commercial") or building_type.contains("office") or building_type.contains("retail"):
		return

	# Need enough floors
	if context.levels < MIN_FLOORS_FOR_ESCAPE:
		return

	# Random chance
	if rng.randf() > ESCAPE_CHANCE:
		return

	# Wall must be long enough
	var wall_length = wall_segment.length
	if wall_length < LANDING_WIDTH + 1.0:
		return

	# Generate fire escape on this wall
	_generate_fire_escape(wall_segment, context, surfaces)

## Generate complete fire escape structure
static func _generate_fire_escape(
	wall_segment: Dictionary,
	context,
	surfaces: Dictionary
) -> void:
	var p1 = wall_segment.p1
	var p2 = wall_segment.p2
	var wall_normal = wall_segment.normal
	var wall_length = wall_segment.length

	var wall_surface = surfaces["wall"]
	var frame_surface = surfaces["frame"]

	# Position fire escape at center of wall
	var escape_center_t = 0.5
	var escape_center_2d = p1.lerp(p2, escape_center_t)

	# Wall direction for width calculations
	var wall_dir = (p2 - p1).normalized()

	# Generate landings and stairs for each floor (starting from floor 1, not ground)
	for floor_num in range(1, context.levels):
		var floor_y = floor_num * context.floor_height

		# Landing at this floor
		LandingGenerator.generate(
			escape_center_2d,
			floor_y,
			wall_normal,
			wall_dir,
			frame_surface
		)

		# Stairs going down to previous landing (except first floor)
		if floor_num > 1:
			var prev_floor_y = (floor_num - 1) * context.floor_height
			StairGenerator.generate(
				escape_center_2d,
				prev_floor_y,
				floor_y,
				wall_normal,
				wall_dir,
				frame_surface
			)

		# Railings around landing
		EscapeRailing.generate_for_landing(
			escape_center_2d,
			floor_y,
			wall_normal,
			wall_dir,
			frame_surface
		)

	# Stairs from first landing to near ground
	var first_landing_y = context.floor_height
	StairGenerator.generate(
		escape_center_2d,
		0.5,  # Stop 50cm above ground (ladder extends down)
		first_landing_y,
		wall_normal,
		wall_dir,
		frame_surface
	)

	# Drop ladder at the bottom
	LadderGenerator.generate(
		escape_center_2d,
		0.5,  # From 50cm
		wall_normal,
		wall_dir,
		frame_surface
	)
