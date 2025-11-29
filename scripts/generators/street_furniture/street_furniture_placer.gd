extends RefCounted
class_name StreetFurniturePlacer

## Street Furniture Placer Utility
## Provides consistent positioning for signs, lights, poles, etc.
## Places items on sidewalks/corners, not in roads.

const TerrainPathSmoother = preload("res://scripts/terrain/terrain_path_smoother.gd")

## Sidewalk width offset from road edge
const SIDEWALK_OFFSET: float = 2.0

## Minimum distance between placed items
const MIN_ITEM_SPACING: float = 3.0


## Get valid corner positions for an intersection
## Returns array of placement data: { position: Vector3, facing: Vector2, corner_idx: int }
static func get_corner_placements(
	intersection: RoadIntersection,
	heightmap,
	sidewalk_offset: float = SIDEWALK_OFFSET
) -> Array:
	var placements: Array = []

	if intersection.corner_positions.is_empty():
		return placements

	# Get elevation at intersection
	var elevation = 0.0
	if heightmap:
		elevation = TerrainPathSmoother.get_smoothed_elevation(
			intersection.position, heightmap, 3.0
		)

	# For each corner, calculate a sidewalk position
	for i in range(intersection.corner_positions.size()):
		var corner_2d: Vector2 = intersection.corner_positions[i]

		# Direction from intersection center to corner
		var to_corner = (corner_2d - intersection.position)
		if to_corner.length() < 0.1:
			continue

		var corner_dir = to_corner.normalized()

		# Move further out onto sidewalk
		var sidewalk_pos_2d = corner_2d + corner_dir * sidewalk_offset

		# Facing direction: towards the intersection center
		var facing = -corner_dir

		var pos_3d = Vector3(sidewalk_pos_2d.x, elevation, -sidewalk_pos_2d.y)

		placements.append({
			"position": pos_3d,
			"position_2d": sidewalk_pos_2d,
			"facing": facing,
			"corner_idx": i
		})

	return placements


## Get a single best corner for a street sign
## Prefers corners that are between different named streets
static func get_street_sign_placement(
	intersection: RoadIntersection,
	heightmap,
	road_network
) -> Dictionary:
	var placements = get_corner_placements(intersection, heightmap)

	if placements.is_empty():
		# Fallback: create position from intersection center
		return _create_fallback_placement(intersection, heightmap)

	# Use first valid corner (corners are sorted clockwise)
	# Add extra offset for sign posts - ensure well onto sidewalk
	var best = placements[0]
	best.position += Vector3(best.facing.x, 0, -best.facing.y) * 1.5

	return best


## Get placements for stop/yield signs at an intersection
## Places signs on the right side of incoming minor roads
static func get_stop_sign_placements(
	intersection: RoadIntersection,
	minor_connections: Array,
	heightmap
) -> Array:
	var placements: Array = []

	var elevation = 0.0
	if heightmap:
		elevation = TerrainPathSmoother.get_smoothed_elevation(
			intersection.position, heightmap, 3.0
		)

	for conn in minor_connections:
		var segment = conn.get("segment")
		if segment == null:
			continue

		# Get direction of road approaching intersection
		var is_start = conn.get("is_start", false)
		var incoming_dir: Vector2
		if is_start:
			incoming_dir = -segment.get_start_direction()
		else:
			incoming_dir = segment.get_end_direction()

		# Right side perpendicular (US convention: signs on right)
		var right_perp = Vector2(-incoming_dir.y, incoming_dir.x)

		# Position: at road edge + sidewalk offset
		var half_width = segment.calculated_width / 2.0
		var sign_offset = half_width + SIDEWALK_OFFSET + 1.0

		# Place sign back from intersection by road width
		var setback = intersection.get_max_road_width() + 2.0

		var sign_pos_2d = intersection.position + incoming_dir * setback + right_perp * sign_offset
		var sign_pos_3d = Vector3(sign_pos_2d.x, elevation, -sign_pos_2d.y)

		placements.append({
			"position": sign_pos_3d,
			"position_2d": sign_pos_2d,
			"facing": incoming_dir,  # Face incoming traffic
			"connection": conn
		})

	return placements


## Get lamp placement positions along a road segment
## Returns array of { position: Vector3, side: String ("left" or "right") }
static func get_lamp_placements_along_segment(
	segment,
	heightmap,
	spacing: float = 50.0,
	offset_from_road: float = 3.0
) -> Array:
	var placements: Array = []
	var path = segment.path

	if path.size() < 2:
		return placements

	var half_width = segment.calculated_width / 2.0
	var total_offset = half_width + offset_from_road

	# Walk along path and place lamps
	var accumulated_dist = spacing / 2.0  # Start offset
	var target_dist = spacing

	for i in range(path.size() - 1):
		var p1 = path[i]
		var p2 = path[i + 1]
		var seg_length = p1.distance_to(p2)
		var seg_dir = (p2 - p1).normalized()
		var seg_perp = Vector2(-seg_dir.y, seg_dir.x)

		while accumulated_dist < seg_length:
			var t = accumulated_dist / seg_length
			var pos_2d = p1.lerp(p2, t)

			# Alternate sides or pick one side based on hash
			var side_mult = 1.0 if (placements.size() % 2 == 0) else -1.0
			var lamp_pos_2d = pos_2d + seg_perp * total_offset * side_mult

			var elevation = 0.0
			if heightmap:
				elevation = heightmap.get_elevation(lamp_pos_2d.x, -lamp_pos_2d.y)

			var lamp_pos_3d = Vector3(lamp_pos_2d.x, elevation, -lamp_pos_2d.y)

			placements.append({
				"position": lamp_pos_3d,
				"position_2d": lamp_pos_2d,
				"side": "right" if side_mult > 0 else "left"
			})

			accumulated_dist += spacing

		accumulated_dist -= seg_length

	return placements


## Get positions for traffic lights at an intersection
## One light per incoming road, positioned at corner on right side
static func get_traffic_light_placements(
	intersection: RoadIntersection,
	heightmap
) -> Array:
	var placements: Array = []

	if intersection.connections.size() < 3:
		return placements

	var elevation = 0.0
	if heightmap:
		elevation = TerrainPathSmoother.get_smoothed_elevation(
			intersection.position, heightmap, 3.0
		)

	for conn in intersection.connections:
		var segment = conn.get("segment")
		if segment == null:
			continue

		# Direction approaching intersection
		var is_start = conn.get("is_start", false)
		var incoming_dir: Vector2
		if is_start:
			incoming_dir = -segment.get_start_direction()
		else:
			incoming_dir = segment.get_end_direction()

		# Right side of road
		var right_perp = Vector2(-incoming_dir.y, incoming_dir.x)

		# Position at corner
		var half_width = segment.calculated_width / 2.0
		var light_offset = half_width + SIDEWALK_OFFSET

		var light_pos_2d = intersection.position + right_perp * light_offset
		var light_pos_3d = Vector3(light_pos_2d.x, elevation, -light_pos_2d.y)

		placements.append({
			"position": light_pos_3d,
			"position_2d": light_pos_2d,
			"facing": incoming_dir,
			"connection": conn
		})

	return placements


## Get position along road edge (for utility poles, etc.)
static func get_road_edge_position(
	segment,
	t: float,  # 0-1 along segment
	side: String,  # "left" or "right"
	heightmap,
	offset: float = 2.0
) -> Dictionary:
	var path = segment.path
	if path.size() < 2:
		return {}

	# Find position along path
	var total_length = segment.length
	var target_dist = total_length * t
	var accumulated = 0.0
	var pos_2d = path[0]
	var dir = (path[1] - path[0]).normalized()

	for i in range(path.size() - 1):
		var seg_len = path[i].distance_to(path[i + 1])
		if accumulated + seg_len >= target_dist:
			var local_t = (target_dist - accumulated) / seg_len
			pos_2d = path[i].lerp(path[i + 1], local_t)
			dir = (path[i + 1] - path[i]).normalized()
			break
		accumulated += seg_len

	# Calculate perpendicular and offset
	var perp = Vector2(-dir.y, dir.x)
	var half_width = segment.calculated_width / 2.0
	var total_offset = half_width + offset

	var side_mult = 1.0 if side == "right" else -1.0
	var final_pos_2d = pos_2d + perp * total_offset * side_mult

	var elevation = 0.0
	if heightmap:
		elevation = heightmap.get_elevation(final_pos_2d.x, -final_pos_2d.y)

	return {
		"position": Vector3(final_pos_2d.x, elevation, -final_pos_2d.y),
		"position_2d": final_pos_2d,
		"direction": dir,
		"side": side
	}


## Create fallback placement when no corners available
static func _create_fallback_placement(intersection: RoadIntersection, heightmap) -> Dictionary:
	var elevation = 0.0
	if heightmap:
		elevation = TerrainPathSmoother.get_smoothed_elevation(
			intersection.position, heightmap, 3.0
		)

	# Get max width to offset properly - ensure minimum offset
	var max_width = intersection.get_max_road_width()
	if max_width < 5.0:
		max_width = 10.0  # Default for narrow/unknown roads

	# Offset must be far enough to be completely off the road
	var offset = max_width / 2.0 + SIDEWALK_OFFSET + 2.0

	# Use connected road directions to determine a proper corner location
	var offset_dir = Vector2(1, 1).normalized()  # Fallback if no connections

	if intersection.connections.size() > 0:
		# Get the first two road directions and find a corner between them
		var dir1: Vector2 = Vector2.ZERO
		var dir2: Vector2 = Vector2.ZERO

		for i in range(mini(intersection.connections.size(), 2)):
			var conn = intersection.connections[i]
			var segment = conn.get("segment")
			if segment == null:
				continue

			var is_start = conn.get("is_start", false)
			var road_dir: Vector2
			if is_start:
				road_dir = segment.get_start_direction()
			else:
				road_dir = -segment.get_end_direction()

			if i == 0:
				dir1 = road_dir
			else:
				dir2 = road_dir

		if dir1.length() > 0.1:
			if dir2.length() > 0.1:
				# Find corner between the two roads
				# We need to find the direction that is BETWEEN the two roads
				# This is the average of the perpendiculars (right sides) of each road
				var right1 = Vector2(-dir1.y, dir1.x)  # Right side of road 1
				var right2 = Vector2(-dir2.y, dir2.x)  # Right side of road 2
				# The corner is where both right sides point - average them
				offset_dir = (right1 + right2).normalized()
				# If roads are nearly opposite, use just the perpendicular of first road
				if offset_dir.length() < 0.3:
					offset_dir = right1.normalized()
			else:
				# Only one road - go perpendicular to the right
				offset_dir = Vector2(-dir1.y, dir1.x).normalized()

	var pos_2d = intersection.position + offset_dir.normalized() * offset

	return {
		"position": Vector3(pos_2d.x, elevation, -pos_2d.y),
		"position_2d": pos_2d,
		"facing": -offset_dir.normalized(),
		"corner_idx": -1
	}


## Check if a position is too close to existing placements
static func is_position_valid(
	new_pos: Vector3,
	existing_positions: Array,
	min_distance: float = MIN_ITEM_SPACING
) -> bool:
	for existing in existing_positions:
		if new_pos.distance_to(existing) < min_distance:
			return false
	return true
