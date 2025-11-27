extends RefCounted
class_name FeatureFactory

## Feature Factory
##
## Factory pattern for creating city features (buildings, roads, parks, water).
## Coordinates between ChunkManager and individual generators.
##
## Responsibilities:
##   - Create features for chunks using specialized generators
##   - Manage feature positioning and parenting
##   - Track created features for cleanup

# ========================================================================
# INITIALIZATION
# ========================================================================

var material_library = null  # MaterialLibrary (no type hint to avoid dependency issues)

func _init():
	pass  # MaterialLibrary set externally via property

# ========================================================================
# CHUNK FEATURE CREATION
# ========================================================================

## Create all buildings for a chunk
func create_buildings_for_chunk(buildings_data: Array, parent: Node, tracking_array: Array):
	for building_data in buildings_data:
		var center = building_data.get("center", Vector2.ZERO)
		var building = BuildingOrchestrator.create_building(building_data, parent, true, material_library)

		if building:
			building.position = Vector3(center.x, 0, -center.y)

			# Track for cleanup during chunk unload
			tracking_array.append({
				"node": building,
				"position": building.position
			})

## Create all roads for a chunk
func create_roads_for_chunk(roads_data: Array, parent: Node, tracking_array: Array):
	for road_data in roads_data:
		var path = road_data.get("path", [])
		if path.size() < 2:
			continue

		RoadGenerator.create_road(path, road_data, parent, tracking_array)

## Create all parks for a chunk
func create_parks_for_chunk(parks_data: Array, parent: Node):
	for park_data in parks_data:
		var footprint = park_data.get("footprint", [])
		if footprint.size() >= 3:
			ParkGenerator.create_park(footprint, park_data, parent)

## Create all water features for a chunk
func create_water_for_chunk(water_data_array: Array, parent: Node):
	for water_data in water_data_array:
		var footprint = water_data.get("footprint", [])
		if footprint.size() >= 3:
			WaterGenerator.create_water(footprint, water_data, parent)

# ========================================================================
# WORK ITEM CREATION (for LoadingQueue)
# ========================================================================

## Create work items for all buildings in a chunk
func create_building_work_items(buildings_data: Array, chunk_key: Vector2i, chunk_node: Node, tracking_array: Array, camera_pos: Vector2) -> Array:
	var work_items = []

	for building_data in buildings_data:
		var center = building_data.get("center", Vector2.ZERO)
		var priority = camera_pos.distance_to(center)

		work_items.append({
			"type": "building",
			"chunk_key": chunk_key,
			"id": "building_" + str(building_data.get("id", "")),
			"data": building_data,
			"chunk_node": chunk_node,
			"tracking_array": tracking_array,
			"priority": priority,
			"estimated_cost_ms": 0.4,  # Average from profiling
			"queued_time": Time.get_ticks_msec()
		})

	return work_items

## Create work items for all roads in a chunk
func create_road_work_items(roads_data: Array, chunk_key: Vector2i, chunk_node: Node, tracking_array: Array, camera_pos: Vector2) -> Array:
	var work_items = []

	for road_data in roads_data:
		var path = road_data.get("path", [])
		if path.size() < 2:
			continue

		# Calculate center of road for priority
		var center = Vector2.ZERO
		for point in path:
			center += point
		center /= path.size()

		var priority = camera_pos.distance_to(center)

		work_items.append({
			"type": "road",
			"chunk_key": chunk_key,
			"id": "road_" + str(road_data.get("id", "")),
			"data": road_data,
			"chunk_node": chunk_node,
			"tracking_array": tracking_array,
			"priority": priority,
			"estimated_cost_ms": 0.03,  # Average from profiling
			"queued_time": Time.get_ticks_msec()
		})

	return work_items

## Create work items for all parks in a chunk
func create_park_work_items(parks_data: Array, chunk_key: Vector2i, chunk_node: Node, camera_pos: Vector2) -> Array:
	var work_items = []

	for park_data in parks_data:
		var footprint = park_data.get("footprint", [])
		if footprint.size() < 3:
			continue

		var center = park_data.get("center", Vector2.ZERO)
		var priority = camera_pos.distance_to(center)

		work_items.append({
			"type": "park",
			"chunk_key": chunk_key,
			"id": "park_" + str(park_data.get("id", "")),
			"data": park_data,
			"chunk_node": chunk_node,
			"priority": priority,
			"estimated_cost_ms": 0.1,  # Average from profiling
			"queued_time": Time.get_ticks_msec()
		})

	return work_items

## Create work items for all water features in a chunk
func create_water_work_items(water_data_array: Array, chunk_key: Vector2i, chunk_node: Node, camera_pos: Vector2) -> Array:
	var work_items = []

	for water_data in water_data_array:
		var footprint = water_data.get("footprint", [])
		if footprint.size() < 3:
			continue

		var center = water_data.get("center", Vector2.ZERO)
		var priority = camera_pos.distance_to(center)

		work_items.append({
			"type": "water",
			"chunk_key": chunk_key,
			"id": "water_" + str(water_data.get("id", "")),
			"data": water_data,
			"chunk_node": chunk_node,
			"priority": priority,
			"estimated_cost_ms": 0.1,  # Average from profiling
			"queued_time": Time.get_ticks_msec()
		})

	return work_items

## Create work items for ground details in a chunk
func create_ground_details_work_items(buildings_data: Array, roads_data: Array, chunk_key: Vector2i, chunk_node: Node, camera_pos: Vector2) -> Array:
	var work_items = []

	# Only create one work item per chunk for all ground details
	if buildings_data.size() > 0 or roads_data.size() > 0:
		# Calculate chunk center for priority
		var chunk_center = Vector2(chunk_key.x * 500.0 + 250.0, chunk_key.y * 500.0 + 250.0)
		var priority = camera_pos.distance_to(chunk_center) + 50.0  # Higher priority than furniture

		work_items.append({
			"type": "ground_details",
			"chunk_key": chunk_key,
			"id": "ground_" + str(chunk_key.x) + "_" + str(chunk_key.y),
			"buildings_data": buildings_data,
			"roads_data": roads_data,
			"chunk_node": chunk_node,
			"priority": priority,
			"estimated_cost_ms": 2.0,
			"queued_time": Time.get_ticks_msec()
		})

	return work_items

## Create work items for street furniture in a chunk
func create_street_furniture_work_items(buildings_data: Array, roads_data: Array, chunk_key: Vector2i, chunk_node: Node, camera_pos: Vector2) -> Array:
	var work_items = []

	# Only create one work item per chunk for all street furniture
	if buildings_data.size() > 0 or roads_data.size() > 0:
		# Calculate chunk center for priority
		var chunk_center = Vector2(chunk_key.x * 500.0 + 250.0, chunk_key.y * 500.0 + 250.0)
		var priority = camera_pos.distance_to(chunk_center) + 100.0  # Lower priority than buildings

		work_items.append({
			"type": "street_furniture",
			"chunk_key": chunk_key,
			"id": "furniture_" + str(chunk_key.x) + "_" + str(chunk_key.y),
			"buildings_data": buildings_data,
			"roads_data": roads_data,
			"chunk_node": chunk_node,
			"priority": priority,
			"estimated_cost_ms": 1.0,
			"queued_time": Time.get_ticks_msec()
		})

	return work_items

## Create work items for all features in a chunk (convenience method)
func create_work_items_for_chunk(chunk_key: Vector2i, chunk_node: Node, buildings_data: Array, roads_data: Array, parks_data: Array, water_data: Array, tracking_buildings: Array, tracking_roads: Array, camera_pos: Vector2) -> Array:
	var all_items = []

	all_items.append_array(create_building_work_items(buildings_data, chunk_key, chunk_node, tracking_buildings, camera_pos))
	all_items.append_array(create_road_work_items(roads_data, chunk_key, chunk_node, tracking_roads, camera_pos))
	all_items.append_array(create_park_work_items(parks_data, chunk_key, chunk_node, camera_pos))
	all_items.append_array(create_water_work_items(water_data, chunk_key, chunk_node, camera_pos))
	all_items.append_array(create_ground_details_work_items(buildings_data, roads_data, chunk_key, chunk_node, camera_pos))
	all_items.append_array(create_street_furniture_work_items(buildings_data, roads_data, chunk_key, chunk_node, camera_pos))

	return all_items
