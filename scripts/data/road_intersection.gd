extends RefCounted
class_name RoadIntersection

## Road Intersection - represents a node where 2+ roads meet
## Part of the road network graph structure

## OSM node ID
var node_id: int = 0

## World position (Vector2 in game coordinates)
var position: Vector2 = Vector2.ZERO

## Elevation at this intersection (set during terrain integration)
var elevation: float = 0.0

## Connected road segments with their entry angles
## Each entry: { "segment": RoadSegment, "angle": float, "is_start": bool }
## angle is in radians, measured clockwise from north (0 = north, PI/2 = east)
var connections: Array = []

## Intersection type (determined from connection count and angles)
enum IntersectionType {
	DEAD_END,      # 1 connection - road terminates
	CORNER,        # 2 connections at sharp angle (not straight through)
	STRAIGHT,      # 2 connections roughly 180° apart (road continues)
	T_JUNCTION,    # 3 connections
	CROSS,         # 4 connections at roughly 90° angles
	MULTI,         # 5+ connections or irregular 4-way
}
var intersection_type: IntersectionType = IntersectionType.DEAD_END

## Calculated geometry for rendering
var polygon: PackedVector2Array = PackedVector2Array()  # Intersection area polygon
var corner_positions: Array[Vector2] = []  # Corner positions for curb/sidewalk


## Add a road segment connection
func add_connection(segment: RoadSegment, is_start_of_segment: bool) -> void:
	# Calculate entry angle (direction road enters intersection)
	var direction: Vector2
	if is_start_of_segment:
		# Segment starts here, so road leaves this intersection
		direction = segment.get_start_direction()
	else:
		# Segment ends here, so road enters this intersection
		direction = -segment.get_end_direction()

	# Convert to angle from north (clockwise)
	# North = (0, -1) in our coordinate system (y increases south in game coords)
	var angle = atan2(direction.x, -direction.y)
	if angle < 0:
		angle += TAU

	connections.append({
		"segment": segment,
		"angle": angle,
		"is_start": is_start_of_segment
	})


## Sort connections by angle (clockwise from north)
func sort_connections() -> void:
	connections.sort_custom(func(a, b): return a["angle"] < b["angle"])


## Determine intersection type based on connections
func determine_type() -> void:
	var count = connections.size()

	match count:
		0, 1:
			intersection_type = IntersectionType.DEAD_END
		2:
			# Check if roads are roughly opposite (straight through) or at angle (corner)
			var angle_diff = abs(connections[0]["angle"] - connections[1]["angle"])
			if angle_diff > PI:
				angle_diff = TAU - angle_diff
			# If roads are within 30° of being opposite (150-210°), it's straight through
			if angle_diff > deg_to_rad(150) and angle_diff < deg_to_rad(210):
				intersection_type = IntersectionType.STRAIGHT
			else:
				intersection_type = IntersectionType.CORNER
		3:
			intersection_type = IntersectionType.T_JUNCTION
		4:
			# Check if it's a regular cross (roughly 90° between each)
			var is_regular = true
			for i in range(4):
				var next_i = (i + 1) % 4
				var angle_diff = connections[next_i]["angle"] - connections[i]["angle"]
				if angle_diff < 0:
					angle_diff += TAU
				# Allow 30° tolerance from 90°
				if angle_diff < deg_to_rad(60) or angle_diff > deg_to_rad(120):
					is_regular = false
					break
			intersection_type = IntersectionType.CROSS if is_regular else IntersectionType.MULTI
		_:
			intersection_type = IntersectionType.MULTI


## Get the maximum road width among all connections
func get_max_road_width() -> float:
	var max_width = 0.0
	for conn in connections:
		var segment: RoadSegment = conn["segment"]
		max_width = max(max_width, segment.calculated_width)
	return max_width


## Get the minimum road width among all connections
func get_min_road_width() -> float:
	if connections.is_empty():
		return 0.0
	var min_width = INF
	for conn in connections:
		var segment: RoadSegment = conn["segment"]
		min_width = min(min_width, segment.calculated_width)
	return min_width


## Calculate the intersection polygon
## This creates a closed polygon that fills the space where roads meet
func calculate_polygon() -> void:
	sort_connections()
	determine_type()

	polygon.clear()
	corner_positions.clear()

	if connections.size() < 2:
		# Dead end - create a rounded cap or simple end
		if connections.size() == 1:
			_create_dead_end_polygon()
		return

	# For each pair of adjacent roads, calculate the corner point
	for i in range(connections.size()):
		var conn_a = connections[i]
		var conn_b = connections[(i + 1) % connections.size()]

		var segment_a: RoadSegment = conn_a["segment"]
		var segment_b: RoadSegment = conn_b["segment"]

		# Get edge lines for each road
		# Road A: we want its RIGHT edge (as you leave the intersection)
		# Road B: we want its LEFT edge (as you approach the intersection)
		var dir_a = _get_outgoing_direction(conn_a)
		var dir_b = _get_outgoing_direction(conn_b)

		var perp_a = Vector2(-dir_a.y, dir_a.x)  # Perpendicular (to the right)
		var perp_b = Vector2(-dir_b.y, dir_b.x)

		var half_width_a = segment_a.calculated_width / 2.0
		var half_width_b = segment_b.calculated_width / 2.0

		# Right edge of road A (offset by half width to the right)
		var edge_a_point = position + perp_a * half_width_a
		var edge_a_dir = dir_a

		# Left edge of road B (offset by half width to the left, which is negative perp)
		var edge_b_point = position - perp_b * half_width_b
		var edge_b_dir = dir_b

		# Find intersection of these two edge lines
		var corner = _line_intersection(edge_a_point, edge_a_dir, edge_b_point, edge_b_dir)
		if corner != null:
			polygon.append(corner)
			corner_positions.append(corner)


## Create polygon for dead end (single road termination)
func _create_dead_end_polygon() -> void:
	if connections.is_empty():
		return

	var conn = connections[0]
	var segment: RoadSegment = conn["segment"]
	var dir = _get_outgoing_direction(conn)
	var perp = Vector2(-dir.y, dir.x)
	var half_width = segment.calculated_width / 2.0

	# Create a rounded or squared end cap
	# Simple square cap for now
	var cap_depth = half_width * 0.5  # Cap extends half the road width

	var right = position + perp * half_width
	var left = position - perp * half_width
	var right_cap = right + dir * cap_depth
	var left_cap = left + dir * cap_depth

	polygon.append(right)
	polygon.append(right_cap)
	polygon.append(left_cap)
	polygon.append(left)

	corner_positions.append(right)
	corner_positions.append(left)


## Get outgoing direction from intersection for a connection
func _get_outgoing_direction(conn: Dictionary) -> Vector2:
	var segment: RoadSegment = conn["segment"]
	if conn["is_start"]:
		return segment.get_start_direction()
	else:
		return -segment.get_end_direction()


## Find intersection point of two lines
## Returns null if lines are parallel
func _line_intersection(p1: Vector2, d1: Vector2, p2: Vector2, d2: Vector2) -> Variant:
	var cross = d1.x * d2.y - d1.y * d2.x

	# Check for parallel lines
	if abs(cross) < 0.0001:
		return null

	var diff = p2 - p1
	var t = (diff.x * d2.y - diff.y * d2.x) / cross

	return p1 + d1 * t


## Check if this intersection should have traffic lights (heuristic)
func should_have_traffic_lights() -> bool:
	if connections.size() < 3:
		return false

	# Check if any connected road is a significant road
	# Include tertiary roads which are common in urban areas
	for conn in connections:
		var segment: RoadSegment = conn["segment"]
		if segment.highway_type in ["primary", "secondary", "tertiary", "trunk"]:
			return true

	# Also add lights at busy residential intersections (4+ way)
	if connections.size() >= 4:
		var driveable_count = 0
		for conn in connections:
			var segment: RoadSegment = conn["segment"]
			if segment.is_driveable():
				driveable_count += 1
		if driveable_count >= 4:
			return true

	return false


## Check if this intersection should have a crosswalk
func should_have_crosswalk() -> bool:
	# Crosswalks at any intersection with driveable roads
	for conn in connections:
		var segment: RoadSegment = conn["segment"]
		if segment.is_driveable():
			return true
	return false


## Get description string for debugging
func get_description() -> String:
	var type_names = ["DEAD_END", "CORNER", "STRAIGHT", "T_JUNCTION", "CROSS", "MULTI"]
	return "Intersection %d: %s with %d connections at (%.1f, %.1f)" % [
		node_id,
		type_names[intersection_type],
		connections.size(),
		position.x,
		position.y
	]
