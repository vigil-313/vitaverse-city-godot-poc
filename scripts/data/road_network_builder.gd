extends RefCounted
class_name RoadNetworkBuilder

## Road Network Builder
## Transforms linear OSM road data into a proper graph structure
## with intersection nodes and segment edges.

## The built network data
var intersections: Dictionary = {}  # node_id -> RoadIntersection
var segments: Array = []  # Array of RoadSegment

## Bounds of the network
var bounds: Rect2 = Rect2()

## Statistics
var stats: Dictionary = {
	"total_ways": 0,
	"total_segments": 0,
	"total_intersections": 0,
	"dead_ends": 0,
	"t_junctions": 0,
	"crossings": 0,
	"multi_way": 0
}


## Build the road network from OSM road data
## roads_data: Array of road dictionaries from OSMDataComplete
func build_network(roads_data: Array) -> void:
	print("🛣️  Building road network graph...")
	var start_time = Time.get_ticks_msec()

	# Clear previous data
	intersections.clear()
	segments.clear()
	bounds = Rect2()

	stats["total_ways"] = roads_data.size()

	# Step 1: Find all intersection nodes (nodes used by 2+ roads)
	var intersection_node_ids = _find_intersection_nodes(roads_data)
	print("   Found %d intersection nodes" % intersection_node_ids.size())

	# Step 2: Create intersection objects
	_create_intersections(roads_data, intersection_node_ids)

	# Step 3: Split roads at intersections into segments
	_create_segments(roads_data, intersection_node_ids)

	# Step 4: Connect segments to intersections
	_connect_segments_to_intersections()

	# Step 5: Calculate intersection geometry
	_calculate_intersection_geometry()

	# Step 6: Calculate bounds
	_calculate_bounds()

	var elapsed = Time.get_ticks_msec() - start_time
	_print_stats(elapsed)


## Find all OSM node IDs that are shared by 2+ roads
func _find_intersection_nodes(roads_data: Array) -> Dictionary:
	# Count how many roads use each node
	var node_usage: Dictionary = {}  # node_id -> count

	for road in roads_data:
		var node_ids = road.get("node_ids", [])
		for node_id in node_ids:
			if node_usage.has(node_id):
				node_usage[node_id] += 1
			else:
				node_usage[node_id] = 1

	# Keep only nodes used by 2+ roads
	var intersection_nodes: Dictionary = {}
	for node_id in node_usage:
		if node_usage[node_id] >= 2:
			intersection_nodes[node_id] = true

	return intersection_nodes


## Create RoadIntersection objects for all intersection nodes
func _create_intersections(roads_data: Array, intersection_node_ids: Dictionary) -> void:
	# Build a lookup of node_id -> position from road data
	var node_positions: Dictionary = {}

	for road in roads_data:
		var node_ids = road.get("node_ids", [])
		var path = road.get("path", [])

		for i in range(min(node_ids.size(), path.size())):
			var node_id = node_ids[i]
			if intersection_node_ids.has(node_id) and not node_positions.has(node_id):
				node_positions[node_id] = path[i]

	# Create intersection objects
	for node_id in intersection_node_ids:
		if node_positions.has(node_id):
			var intersection = RoadIntersection.new()
			intersection.node_id = node_id
			intersection.position = node_positions[node_id]
			intersections[node_id] = intersection

	stats["total_intersections"] = intersections.size()


## Split roads at intersection points into segments
func _create_segments(roads_data: Array, intersection_node_ids: Dictionary) -> void:
	for road in roads_data:
		var node_ids = road.get("node_ids", [])
		var path = road.get("path", [])

		if node_ids.size() < 2 or path.size() < 2:
			continue

		# Find all indices where intersections occur
		var split_indices: Array[int] = []
		split_indices.append(0)  # Always start at beginning

		for i in range(1, node_ids.size() - 1):  # Skip first and last (handled separately)
			if intersection_node_ids.has(node_ids[i]):
				split_indices.append(i)

		split_indices.append(node_ids.size() - 1)  # Always end at end

		# Create segments between split points
		for i in range(split_indices.size() - 1):
			var start_idx = split_indices[i]
			var end_idx = split_indices[i + 1]

			# Skip if segment would have less than 2 points
			if end_idx - start_idx < 1:
				continue

			var segment = RoadSegment.new()
			segment.init_from_road_data(road, start_idx, end_idx)

			# Store node IDs for connection phase
			segment.set_meta("start_node_id", node_ids[start_idx])
			segment.set_meta("end_node_id", node_ids[end_idx])

			segments.append(segment)

	stats["total_segments"] = segments.size()


## Connect segments to their start/end intersections
func _connect_segments_to_intersections() -> void:
	for segment in segments:
		var start_node_id = segment.get_meta("start_node_id", 0)
		var end_node_id = segment.get_meta("end_node_id", 0)

		# Connect to start intersection
		if intersections.has(start_node_id):
			var intersection = intersections[start_node_id]
			segment.start_intersection = intersection
			intersection.add_connection(segment, true)  # true = this is start of segment

		# Connect to end intersection
		if intersections.has(end_node_id):
			var intersection = intersections[end_node_id]
			segment.end_intersection = intersection
			intersection.add_connection(segment, false)  # false = this is end of segment


## Calculate geometry for all intersections
func _calculate_intersection_geometry() -> void:
	for node_id in intersections:
		var intersection = intersections[node_id]
		intersection.calculate_polygon()

		# Update stats
		match intersection.intersection_type:
			RoadIntersection.IntersectionType.DEAD_END:
				stats["dead_ends"] += 1
			RoadIntersection.IntersectionType.T_JUNCTION:
				stats["t_junctions"] += 1
			RoadIntersection.IntersectionType.CROSS:
				stats["crossings"] += 1
			RoadIntersection.IntersectionType.MULTI:
				stats["multi_way"] += 1


## Calculate network bounds
func _calculate_bounds() -> void:
	if segments.is_empty():
		return

	var min_x = INF
	var min_y = INF
	var max_x = -INF
	var max_y = -INF

	for segment in segments:
		for point in segment.path:
			min_x = min(min_x, point.x)
			min_y = min(min_y, point.y)
			max_x = max(max_x, point.x)
			max_y = max(max_y, point.y)

	bounds = Rect2(min_x, min_y, max_x - min_x, max_y - min_y)


## Print network statistics
func _print_stats(elapsed_ms: int) -> void:
	print("✅ Road network built in %dms" % elapsed_ms)
	print("   📊 Statistics:")
	print("      Ways processed: %d" % stats["total_ways"])
	print("      Segments created: %d" % stats["total_segments"])
	print("      Intersections: %d" % stats["total_intersections"])
	print("         - Dead ends: %d" % stats["dead_ends"])
	print("         - T-junctions: %d" % stats["t_junctions"])
	print("         - 4-way crossings: %d" % stats["crossings"])
	print("         - Multi-way: %d" % stats["multi_way"])
	print("      Network bounds: %.0fm x %.0fm" % [bounds.size.x, bounds.size.y])


## Get all segments within a chunk
func get_segments_in_chunk(chunk_key: Vector2i, chunk_size: float) -> Array:
	var chunk_bounds = Rect2(
		chunk_key.x * chunk_size,
		chunk_key.y * chunk_size,
		chunk_size,
		chunk_size
	)

	var result: Array = []
	for segment in segments:
		# Check if any point of the segment is in the chunk
		for point in segment.path:
			if chunk_bounds.has_point(point):
				result.append(segment)
				break

	return result


## Get all intersections within a chunk
func get_intersections_in_chunk(chunk_key: Vector2i, chunk_size: float) -> Array:
	var chunk_bounds = Rect2(
		chunk_key.x * chunk_size,
		chunk_key.y * chunk_size,
		chunk_size,
		chunk_size
	)

	var result: Array = []
	for node_id in intersections:
		var intersection = intersections[node_id]
		if chunk_bounds.has_point(intersection.position):
			result.append(intersection)

	return result


## Get segments connected to an intersection
func get_segments_at_intersection(intersection) -> Array:
	var result: Array = []
	for conn in intersection.connections:
		result.append(conn["segment"])
	return result


## Find the nearest intersection to a point
func find_nearest_intersection(point: Vector2):
	var nearest = null
	var min_dist = INF

	for node_id in intersections:
		var intersection = intersections[node_id]
		var dist = point.distance_to(intersection.position)
		if dist < min_dist:
			min_dist = dist
			nearest = intersection

	return nearest


## Get all driveable segments (excluding footways, cycleways)
func get_driveable_segments() -> Array:
	var result: Array = []
	for segment in segments:
		if segment.is_driveable():
			result.append(segment)
	return result


## Get all pedestrian segments (footways, paths)
func get_pedestrian_segments() -> Array:
	var result: Array = []
	for segment in segments:
		if segment.is_pedestrian():
			result.append(segment)
	return result


## Get segments by highway type
func get_segments_by_type(highway_type: String) -> Array:
	var result: Array = []
	for segment in segments:
		if segment.highway_type == highway_type:
			result.append(segment)
	return result
