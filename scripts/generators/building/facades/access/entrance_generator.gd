extends Node
class_name EntranceGenerator

## Entrance generator coordinator
## Creates building entrances with doors, steps, and canopies

const DoorGenerator = preload("res://scripts/generators/building/facades/access/door_generator.gd")
const StepsGenerator = preload("res://scripts/generators/building/facades/access/steps_generator.gd")
const CanopyGenerator = preload("res://scripts/generators/building/facades/access/canopy_generator.gd")
const GeometryUtils = preload("res://scripts/generators/building/core/geometry_utils.gd")

## Minimum wall length to receive an entrance
const MIN_WALL_LENGTH = 4.0

## Door dimensions by building type
const COMMERCIAL_DOOR_WIDTH = 1.8   # Double door
const RESIDENTIAL_DOOR_WIDTH = 1.0  # Single door
const DOOR_HEIGHT = 2.4

## Commercial building types (get double doors + canopies)
const COMMERCIAL_TYPES = ["commercial", "retail", "office", "shop", "supermarket", "mall", "store"]

## Main entry point - generates entrance for the building
static func generate(context, surfaces: Dictionary, wall_segments: Array) -> void:
	if wall_segments.is_empty() or context.levels < 1:
		return

	var wall_surface = surfaces["wall"]
	var glass_surface = surfaces["glass"]
	var frame_surface = surfaces["frame"]

	# Find the best wall for the entrance
	var entrance_wall = _find_entrance_wall(wall_segments)
	if entrance_wall == null:
		return

	var is_commercial = _is_commercial(context.building_type)

	# Calculate entrance position (center of wall)
	var p1 = entrance_wall.p1
	var p2 = entrance_wall.p2
	var wall_normal = entrance_wall.normal
	var wall_length = entrance_wall.length

	# Door width based on building type
	var door_width = COMMERCIAL_DOOR_WIDTH if is_commercial else RESIDENTIAL_DOOR_WIDTH

	# Center the door on the wall
	var door_center_t = 0.5
	var door_half_width_t = (door_width / 2.0) / wall_length
	var door_left_t = door_center_t - door_half_width_t
	var door_right_t = door_center_t + door_half_width_t

	# Clamp to valid range
	door_left_t = clamp(door_left_t, 0.05, 0.95)
	door_right_t = clamp(door_right_t, 0.05, 0.95)

	# Generate door
	DoorGenerator.generate(
		p1, p2,
		door_left_t, door_right_t,
		0.0, DOOR_HEIGHT,
		wall_normal,
		wall_surface,
		glass_surface,
		frame_surface,
		is_commercial
	)

	# Generate steps if needed (buildings typically have slight elevation)
	var step_height = 0.3  # 30cm step up to door
	if step_height > 0.1:
		StepsGenerator.generate(
			p1, p2,
			door_left_t, door_right_t,
			step_height,
			wall_normal,
			wall_surface
		)

	# Generate canopy for commercial buildings
	if is_commercial:
		CanopyGenerator.generate(
			p1, p2,
			door_left_t, door_right_t,
			DOOR_HEIGHT + 0.1,
			wall_normal,
			wall_surface
		)

## Find the best wall for building entrance
## Prefers: longest wall, south-facing walls
static func _find_entrance_wall(wall_segments: Array) -> Variant:
	var best_wall = null
	var best_score = 0.0

	for segment in wall_segments:
		if segment.length < MIN_WALL_LENGTH:
			continue

		var score = segment.length  # Base score: wall length

		# Bonus for south-facing (negative Z normal in Godot)
		if segment.normal.z < 0:
			score *= 1.3

		# Bonus for east/west facing (visible from sides)
		if abs(segment.normal.x) > 0.5:
			score *= 1.1

		if score > best_score:
			best_score = score
			best_wall = segment

	return best_wall

## Check if building type is commercial
static func _is_commercial(building_type: String) -> bool:
	var type_lower = building_type.to_lower()
	for commercial in COMMERCIAL_TYPES:
		if type_lower.contains(commercial):
			return true
	return false
