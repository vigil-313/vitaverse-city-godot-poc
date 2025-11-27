extends Node
class_name StreetFurnitureSystem

## Street Furniture System
## Coordinates placement of benches, trash cans, bike racks, and lamps
## Places furniture near buildings and along sidewalks

const BenchGenerator = preload("res://scripts/generators/street_furniture/bench_generator.gd")
const TrashCanGenerator = preload("res://scripts/generators/street_furniture/trash_can_generator.gd")
const BikeRackGenerator = preload("res://scripts/generators/street_furniture/bike_rack_generator.gd")
const StreetLampFurniture = preload("res://scripts/generators/street_furniture/street_lamp_generator.gd")
const BollardGenerator = preload("res://scripts/generators/street_furniture/bollard_generator.gd")

## Placement parameters
const SIDEWALK_OFFSET = 3.0        # Distance from building to sidewalk centerline
const FURNITURE_SPACING = 15.0    # Minimum spacing between furniture items
const LAMP_SPACING = 25.0         # Spacing between street lamps

## Furniture placement chances (per valid location)
const BENCH_CHANCE = 0.15
const TRASH_CAN_CHANCE = 0.12
const BIKE_RACK_CHANCE = 0.08
const LAMP_CHANCE = 0.25
const BOLLARD_CHANCE = 0.10

## Main entry point - generate street furniture for a chunk
## buildings_data: Array of building data in this chunk
## roads_data: Array of road data in this chunk
## parent: Node to parent furniture to
static func generate_furniture_for_chunk(
	buildings_data: Array,
	roads_data: Array,
	parent: Node,
	chunk_key: Vector2i
) -> void:
	# Seed random based on chunk for determinism
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(chunk_key.x) + "_" + str(chunk_key.y) + "_furniture")

	# Track placed furniture positions to avoid overlap
	var placed_positions: Array[Vector3] = []

	# Place furniture near buildings
	for building_data in buildings_data:
		_place_furniture_near_building(building_data, parent, rng, placed_positions)

	# Place lamps along roads
	for road_data in roads_data:
		_place_lamps_along_road(road_data, parent, rng, placed_positions)

## Place furniture items near a building's entrance area
static func _place_furniture_near_building(
	building_data: Dictionary,
	parent: Node,
	rng: RandomNumberGenerator,
	placed_positions: Array[Vector3]
) -> void:
	var footprint = building_data.get("footprint", [])
	if footprint.size() < 3:
		return

	var center = building_data.get("center", Vector2.ZERO)
	var building_type = building_data.get("building_type", "residential").to_lower()
	var building_id = building_data.get("id", 0)

	# Find the longest wall segment (likely the front/entrance side)
	var longest_wall_idx = 0
	var longest_wall_length = 0.0

	for i in range(footprint.size()):
		var p1 = footprint[i]
		var p2 = footprint[(i + 1) % footprint.size()]
		var length = p1.distance_to(p2)
		if length > longest_wall_length:
			longest_wall_length = length
			longest_wall_idx = i

	# Get the front wall segment
	var wall_p1 = footprint[longest_wall_idx]
	var wall_p2 = footprint[(longest_wall_idx + 1) % footprint.size()]
	var wall_dir = (wall_p2 - wall_p1).normalized()
	var wall_normal = Vector2(-wall_dir.y, wall_dir.x)  # Perpendicular outward

	# Ensure normal points away from building center
	var wall_center = (wall_p1 + wall_p2) / 2.0
	if wall_normal.dot(wall_center - center) < 0:
		wall_normal = -wall_normal

	# Calculate sidewalk position (offset from building)
	var sidewalk_center = wall_center + wall_normal * SIDEWALK_OFFSET
	var sidewalk_pos_3d = Vector3(sidewalk_center.x, 0, -sidewalk_center.y)

	# Check if position is too close to existing furniture
	if _is_too_close(sidewalk_pos_3d, placed_positions, FURNITURE_SPACING * 0.5):
		return

	# Determine furniture facing direction (away from building)
	var facing_angle = atan2(wall_normal.x, -wall_normal.y)

	# Commercial buildings get more furniture
	var is_commercial = building_type.contains("commercial") or building_type.contains("retail") or building_type.contains("shop")

	# Roll for each furniture type
	var placed_something = false

	# Benches - more likely near commercial
	var bench_roll = rng.randf()
	var bench_threshold = BENCH_CHANCE * (1.5 if is_commercial else 1.0)
	if bench_roll < bench_threshold and not placed_something:
		var bench_offset = wall_dir * rng.randf_range(-2.0, 2.0)
		var bench_pos = sidewalk_pos_3d + Vector3(bench_offset.x, 0, -bench_offset.y)

		if not _is_too_close(bench_pos, placed_positions, FURNITURE_SPACING):
			BenchGenerator.generate(bench_pos, facing_angle, parent)
			placed_positions.append(bench_pos)
			placed_something = true

	# Trash cans - near commercial entrances
	var trash_roll = rng.randf()
	if trash_roll < TRASH_CAN_CHANCE:
		var trash_offset = wall_dir * rng.randf_range(3.0, 5.0)
		var trash_pos = sidewalk_pos_3d + Vector3(trash_offset.x, 0, -trash_offset.y)

		if not _is_too_close(trash_pos, placed_positions, FURNITURE_SPACING * 0.7):
			TrashCanGenerator.generate(trash_pos, parent)
			placed_positions.append(trash_pos)

	# Bike racks - near commercial/office buildings
	var bike_roll = rng.randf()
	var bike_threshold = BIKE_RACK_CHANCE * (2.0 if is_commercial else 0.5)
	if bike_roll < bike_threshold:
		var bike_offset = wall_dir * rng.randf_range(-4.0, 4.0)
		var bike_pos = sidewalk_pos_3d + Vector3(bike_offset.x, 0, -bike_offset.y)
		bike_pos += Vector3(wall_normal.x * 1.5, 0, -wall_normal.y * 1.5)  # Further from building

		if not _is_too_close(bike_pos, placed_positions, FURNITURE_SPACING):
			BikeRackGenerator.generate(bike_pos, facing_angle, parent)
			placed_positions.append(bike_pos)

	# Bollards - at building corners
	var bollard_roll = rng.randf()
	if bollard_roll < BOLLARD_CHANCE and is_commercial:
		var corner_pos_2d = wall_p1 + wall_normal * SIDEWALK_OFFSET
		var corner_pos = Vector3(corner_pos_2d.x, 0, -corner_pos_2d.y)

		if not _is_too_close(corner_pos, placed_positions, 2.0):
			BollardGenerator.generate(corner_pos, parent)
			placed_positions.append(corner_pos)

## Place street lamps along a road
static func _place_lamps_along_road(
	road_data: Dictionary,
	parent: Node,
	rng: RandomNumberGenerator,
	placed_positions: Array[Vector3]
) -> void:
	var path = road_data.get("path", [])
	if path.size() < 2:
		return

	var road_type = road_data.get("road_type", "residential")

	# Only place lamps on larger roads
	if road_type == "footway" or road_type == "path" or road_type == "service":
		return

	# Calculate total road length
	var total_length = 0.0
	for i in range(path.size() - 1):
		total_length += path[i].distance_to(path[i + 1])

	# Place lamps at regular intervals
	var num_lamps = int(total_length / LAMP_SPACING)
	if num_lamps < 1:
		return

	var accumulated_length = 0.0
	var segment_idx = 0

	for lamp_idx in range(num_lamps):
		var target_dist = (lamp_idx + 0.5) * LAMP_SPACING

		# Find the segment containing this distance
		while segment_idx < path.size() - 1:
			var seg_length = path[segment_idx].distance_to(path[segment_idx + 1])
			if accumulated_length + seg_length >= target_dist:
				break
			accumulated_length += seg_length
			segment_idx += 1

		if segment_idx >= path.size() - 1:
			break

		# Interpolate position along segment
		var seg_start = path[segment_idx]
		var seg_end = path[segment_idx + 1]
		var seg_length = seg_start.distance_to(seg_end)
		var t = (target_dist - accumulated_length) / seg_length if seg_length > 0 else 0
		t = clamp(t, 0.0, 1.0)

		var lamp_pos_2d = seg_start.lerp(seg_end, t)

		# Offset to side of road
		var road_dir = (seg_end - seg_start).normalized()
		var road_normal = Vector2(-road_dir.y, road_dir.x)

		# Alternate sides
		var side = 1.0 if lamp_idx % 2 == 0 else -1.0
		lamp_pos_2d += road_normal * (4.0 * side)  # 4m from road center

		var lamp_pos = Vector3(lamp_pos_2d.x, 0, -lamp_pos_2d.y)

		# Random chance to skip
		if rng.randf() > LAMP_CHANCE:
			continue

		if not _is_too_close(lamp_pos, placed_positions, LAMP_SPACING * 0.7):
			StreetLampFurniture.generate(lamp_pos, parent)
			placed_positions.append(lamp_pos)

## Check if position is too close to any existing position
static func _is_too_close(pos: Vector3, existing: Array[Vector3], min_dist: float) -> bool:
	for existing_pos in existing:
		if pos.distance_to(existing_pos) < min_dist:
			return true
	return false
