extends Node
class_name VegetationSystem

## Vegetation System
## Coordinates placement of trees and plants throughout the city
## Places vegetation in parks, along streets, and in open areas

const TreeGenerator = preload("res://scripts/generators/vegetation/tree_generator.gd")

# ========================================================================
# VEGETATION DENSITY SETTINGS
# ========================================================================

## Trees per 100 square meters in different areas (reduced 90% for performance)
const PARK_TREE_DENSITY = 0.08       # Parks get sparse tree coverage (was 0.8)
const FOREST_TREE_DENSITY = 0.2      # Sparse forest areas (was 2.0)
const STREET_TREE_SPACING = 200.0    # 200m between street trees (was 20m)
const STREET_TREE_OFFSET = 5.0       # 5m from road center to tree

## Tree type probabilities for different areas
const PARK_TREE_TYPES = {
	"deciduous": 0.7,
	"conifer": 0.2,
	"small_bush": 0.1,
}

const STREET_TREE_TYPES = {
	"deciduous": 0.9,
	"conifer": 0.1,
}

# ========================================================================
# MAIN ENTRY POINTS
# ========================================================================

## Generate vegetation for a chunk
static func generate_vegetation_for_chunk(
	parks_data: Array,
	roads_data: Array,
	parent: Node,
	chunk_key: Vector2i,
	heightmap = null
) -> void:
	# Seed random based on chunk for determinism
	var base_seed = hash(str(chunk_key.x) + "_" + str(chunk_key.y) + "_vegetation")

	# Generate trees in parks
	for i in range(parks_data.size()):
		var park = parks_data[i]
		var park_seed = base_seed + i * 1000
		_generate_park_vegetation(park, parent, heightmap, park_seed)

	# Generate street trees along roads (only certain road types)
	for i in range(roads_data.size()):
		var road = roads_data[i]
		var road_seed = base_seed + 50000 + i * 100
		_generate_street_trees(road, parent, heightmap, road_seed)

## Generate vegetation within a park
static func _generate_park_vegetation(
	park_data: Dictionary,
	parent: Node,
	heightmap,
	seed_value: int
) -> void:
	var footprint = park_data.get("footprint", [])
	if footprint.size() < 3:
		return

	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value

	# Calculate park area for density calculation
	var area = _calculate_polygon_area(footprint)

	# Small parks get fewer trees
	var density = PARK_TREE_DENSITY
	if area < 1000:  # Less than 1000 sqm
		density *= 0.5

	# Choose tree type based on probabilities
	var tree_type = _pick_tree_type(PARK_TREE_TYPES, rng)

	# Generate trees throughout the park
	TreeGenerator.generate_trees_in_region(
		footprint,
		density,
		tree_type,
		parent,
		heightmap,
		seed_value
	)

	# Add some bushes around the perimeter
	_add_perimeter_bushes(footprint, parent, heightmap, seed_value + 10000)

## Generate street trees along a road
static func _generate_street_trees(
	road_data: Dictionary,
	parent: Node,
	heightmap,
	seed_value: int
) -> void:
	var path = road_data.get("path", [])
	if path.size() < 2:
		return

	var road_type = road_data.get("road_type", "residential")

	# Only place street trees on certain road types
	if road_type in ["motorway", "trunk", "footway", "path", "service", "steps"]:
		return

	# Calculate road width for proper offset
	var road_width = _get_road_width(road_type)
	var tree_offset = road_width / 2.0 + STREET_TREE_OFFSET

	# Wider spacing for larger roads
	var spacing = STREET_TREE_SPACING
	if road_type in ["primary", "secondary"]:
		spacing = 30.0  # Larger roads get more spaced trees

	# Generate trees along the road
	TreeGenerator.generate_street_trees(
		path,
		spacing,
		tree_offset,
		parent,
		heightmap,
		seed_value
	)

## Add bushes around park perimeter
static func _add_perimeter_bushes(
	footprint: Array,
	parent: Node,
	heightmap,
	seed_value: int
) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value

	# Add bushes at corners and along edges
	for i in range(footprint.size()):
		# Only 30% chance to add bush at each corner
		if rng.randf() > 0.3:
			continue

		var corner = footprint[i]

		# Get adjacent points for outward direction
		var prev_idx = (i - 1 + footprint.size()) % footprint.size()
		var next_idx = (i + 1) % footprint.size()

		var to_prev = (footprint[prev_idx] - corner).normalized()
		var to_next = (footprint[next_idx] - corner).normalized()

		# Outward direction (bisector pointing into park)
		var inward = (to_prev + to_next).normalized()
		if inward.length() < 0.1:
			inward = Vector2(1, 0)

		# Place bush slightly inside corner
		var bush_pos_2d = corner + inward * 1.5

		# Get terrain elevation
		var elevation = 0.0
		if heightmap:
			elevation = heightmap.get_elevation(bush_pos_2d.x, -bush_pos_2d.y)

		var bush_pos = Vector3(bush_pos_2d.x, elevation, -bush_pos_2d.y)

		TreeGenerator.generate(bush_pos, "small_bush", rng.randi(), parent)

# ========================================================================
# UTILITY FUNCTIONS
# ========================================================================

## Pick a tree type based on weighted probabilities
static func _pick_tree_type(type_weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total_weight = 0.0
	for weight in type_weights.values():
		total_weight += weight

	var roll = rng.randf() * total_weight
	var cumulative = 0.0

	for type in type_weights:
		cumulative += type_weights[type]
		if roll <= cumulative:
			return type

	return type_weights.keys()[0]

## Calculate polygon area using shoelace formula
static func _calculate_polygon_area(polygon: Array) -> float:
	var area = 0.0
	for i in range(polygon.size()):
		var j = (i + 1) % polygon.size()
		area += polygon[i].x * polygon[j].y
		area -= polygon[j].x * polygon[i].y
	return abs(area) / 2.0

## Get road width based on type
static func _get_road_width(road_type: String) -> float:
	match road_type:
		"motorway", "trunk":
			return 20.0
		"primary":
			return 14.0
		"secondary":
			return 12.0
		"tertiary":
			return 10.0
		"residential", "unclassified":
			return 8.0
		"service":
			return 6.0
		_:
			return 8.0
