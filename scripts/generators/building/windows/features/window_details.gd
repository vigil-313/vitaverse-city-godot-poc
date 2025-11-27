extends Node
class_name WindowDetails

## Window details coordinator
## Adds decorative elements to residential windows: shutters, flower boxes, AC units

const ShutterGenerator = preload("res://scripts/generators/building/windows/features/shutter_generator.gd")
const FlowerBoxGenerator = preload("res://scripts/generators/building/windows/features/flower_box_generator.gd")
const WindowACGenerator = preload("res://scripts/generators/building/windows/features/window_ac_generator.gd")

## Probability settings
const SHUTTER_CHANCE = 0.4       # 40% of residential windows get shutters
const FLOWER_BOX_CHANCE = 0.25   # 25% chance for flower boxes
const WINDOW_AC_CHANCE = 0.15    # 15% chance for window AC units

## Residential building types
const RESIDENTIAL_TYPES = ["residential", "apartments", "house", "detached", "terrace"]

## Main entry point - adds details to a window based on building type
## Returns true if any details were added
static func add_window_details(
	p1: Vector2, p2: Vector2,
	window_left_t: float, window_right_t: float,
	window_bottom: float, window_top: float,
	wall_normal: Vector3,
	wall_surface,
	building_type: String,
	building_id: int,
	floor_num: int,
	window_idx: int
) -> bool:
	# Only residential buildings get window details
	if not _is_residential(building_type):
		return false

	# Create deterministic random based on position
	var seed_val = building_id * 10000 + floor_num * 100 + window_idx
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val

	var added_any = false

	# Shutters (most common)
	if rng.randf() < SHUTTER_CHANCE:
		ShutterGenerator.generate(
			p1, p2,
			window_left_t, window_right_t,
			window_bottom, window_top,
			wall_normal,
			wall_surface
		)
		added_any = true

	# Flower boxes (not on ground floor, not with AC)
	if floor_num > 0 and rng.randf() < FLOWER_BOX_CHANCE:
		FlowerBoxGenerator.generate(
			p1, p2,
			window_left_t, window_right_t,
			window_bottom,
			wall_normal,
			wall_surface
		)
		added_any = true
	# Window AC units (alternative to flower boxes, upper floors only)
	elif floor_num > 0 and rng.randf() < WINDOW_AC_CHANCE:
		WindowACGenerator.generate(
			p1, p2,
			window_left_t, window_right_t,
			window_bottom, window_top,
			wall_normal,
			wall_surface
		)
		added_any = true

	return added_any

## Check if building type is residential
static func _is_residential(building_type: String) -> bool:
	var type_lower = building_type.to_lower()
	for residential in RESIDENTIAL_TYPES:
		if type_lower.contains(residential):
			return true
	return false
