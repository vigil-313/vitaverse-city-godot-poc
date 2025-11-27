extends Node
class_name GroundDetailsSystem

## Ground Details System
## Coordinates placement of sidewalks, foundations, planters, and curbs
## Adds visual detail at street level around buildings and roads

const SidewalkGenerator = preload("res://scripts/generators/ground_details/sidewalk_generator.gd")
const BuildingFoundation = preload("res://scripts/generators/ground_details/foundation_generator.gd")
const PlanterGenerator = preload("res://scripts/generators/ground_details/planter_generator.gd")
const CurbGenerator = preload("res://scripts/generators/ground_details/curb_generator.gd")

## Main entry point - generate ground details for a chunk
static func generate_ground_details_for_chunk(
	buildings_data: Array,
	roads_data: Array,
	parent: Node,
	chunk_key: Vector2i
) -> void:
	# Seed random based on chunk for determinism
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(chunk_key.x) + "_" + str(chunk_key.y) + "_ground")

	# Generate sidewalks around buildings
	for building_data in buildings_data:
		_generate_building_ground_details(building_data, parent, rng)

	# Generate curbs along roads
	for road_data in roads_data:
		CurbGenerator.generate_for_road(road_data, parent)

## Generate ground details around a single building
static func _generate_building_ground_details(
	building_data: Dictionary,
	parent: Node,
	rng: RandomNumberGenerator
) -> void:
	var footprint = building_data.get("footprint", [])
	if footprint.size() < 3:
		return

	var center = building_data.get("center", Vector2.ZERO)
	var building_type = building_data.get("building_type", "residential").to_lower()
	var building_id = building_data.get("id", 0)

	# Generate sidewalk around building perimeter
	SidewalkGenerator.generate_around_building(footprint, center, parent)

	# Generate foundation/base detail
	BuildingFoundation.generate_for_building(footprint, center, parent)

	# Maybe add planters (more common for commercial)
	var is_commercial = building_type.contains("commercial") or building_type.contains("retail") or building_type.contains("office")
	var planter_chance = 0.3 if is_commercial else 0.15

	if rng.randf() < planter_chance:
		_add_planters_near_building(footprint, center, parent, rng, building_id)

## Add decorative planters near a building
static func _add_planters_near_building(
	footprint: Array,
	center: Vector2,
	parent: Node,
	rng: RandomNumberGenerator,
	building_id: int
) -> void:
	# Find corners of the building for planter placement
	var num_planters = rng.randi_range(1, 3)

	for i in range(num_planters):
		# Pick a random corner
		var corner_idx = rng.randi() % footprint.size()
		var corner = footprint[corner_idx]

		# Get adjacent points to determine outward direction
		var prev_idx = (corner_idx - 1 + footprint.size()) % footprint.size()
		var next_idx = (corner_idx + 1) % footprint.size()

		var to_prev = (footprint[prev_idx] - corner).normalized()
		var to_next = (footprint[next_idx] - corner).normalized()

		# Outward direction (bisector pointing away from building)
		var outward = -(to_prev + to_next).normalized()
		if outward.length() < 0.1:
			outward = Vector2(1, 0)

		# Place planter slightly outside corner
		var planter_pos_2d = corner + outward * 1.5
		var planter_pos = Vector3(planter_pos_2d.x, 0, -planter_pos_2d.y)

		PlanterGenerator.generate(planter_pos, rng.randi(), parent)
