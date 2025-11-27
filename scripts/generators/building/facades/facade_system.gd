extends Node
class_name FacadeSystem

## Facade system coordinator
## Generates building facade features: storefronts, balconies, entrances
## Called after wall generation with wall segment info

const StorefrontGenerator = preload("res://scripts/generators/building/facades/storefronts/storefront_generator.gd")
const EntranceGenerator = preload("res://scripts/generators/building/facades/access/entrance_generator.gd")
const BalconyGenerator = preload("res://scripts/generators/building/facades/balconies/balcony_generator.gd")
const FireEscapeSystem = preload("res://scripts/generators/building/facades/fire_escape/fire_escape_system.gd")

## Commercial building types that get storefronts
const COMMERCIAL_TYPES = ["commercial", "retail", "office", "shop", "supermarket", "mall", "store"]

## Residential building types that get balconies
const RESIDENTIAL_TYPES = ["residential", "apartments", "house", "detached", "terrace"]

## Main entry point - generates all facade features for a building
## wall_segments: Array of dictionaries with wall segment info from WallGenerator
static func generate_facades(context, surfaces: Dictionary, wall_segments: Array) -> void:
	if wall_segments.is_empty():
		return

	# Determine which facade features to generate based on building type
	var building_type = context.building_type.to_lower()

	# Commercial buildings get storefronts on ground floor
	if _is_commercial(building_type):
		StorefrontGenerator.generate(context, surfaces, wall_segments)

	# Residential buildings get balconies
	if _is_residential(building_type) and context.levels > 1:
		BalconyGenerator.generate(context, surfaces, wall_segments)

	# Residential buildings may get fire escapes (3+ floors)
	if _is_residential(building_type) and context.levels >= 3:
		_maybe_add_fire_escapes(context, surfaces, wall_segments)

	# All buildings get entrances (doors, steps, canopies)
	EntranceGenerator.generate(context, surfaces, wall_segments)

## Check if building type is commercial
static func _is_commercial(building_type: String) -> bool:
	for commercial in COMMERCIAL_TYPES:
		if building_type.contains(commercial):
			return true
	return false

## Check if building type is residential
static func _is_residential(building_type: String) -> bool:
	for residential in RESIDENTIAL_TYPES:
		if building_type.contains(residential):
			return true
	return false

## Maybe add fire escapes to residential buildings
static func _maybe_add_fire_escapes(context, surfaces: Dictionary, wall_segments: Array) -> void:
	# Use deterministic random based on building ID
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(context.building_id) + "_fire_escape")

	# Pick a wall for fire escape (not the front/longest wall)
	# Sort by length to avoid the front wall
	var sorted_walls = wall_segments.duplicate()
	sorted_walls.sort_custom(func(a, b): return a.length < b.length)

	# Try to add fire escape to a shorter wall (side of building)
	for wall in sorted_walls:
		if wall.length >= 2.5:  # Need at least 2.5m for fire escape
			FireEscapeSystem.maybe_add_fire_escape(wall, context, surfaces, rng)
			break  # Only one fire escape per building
