extends RefCounted
class_name ChunkManager

## Chunk-Based Streaming Manager
##
## Handles dynamic loading and unloading of city features based on camera position.
## Organizes world data into spatial chunks and manages their lifecycle.
##
## Responsibilities:
##   - Organize OSM data into spatial chunks
##   - Load/unload chunks based on camera position
##   - Track active chunks and their contents
##   - Manage chunk visualization for debugging

# ========================================================================
# SIGNALS
# ========================================================================

signal chunk_loaded(chunk_key: Vector2i, feature_counts: Dictionary)
signal chunk_unloaded(chunk_key: Vector2i)
signal chunks_updated(active_count: int, building_count: int, road_count: int)

# ========================================================================
# CONFIGURATION
# ========================================================================

@export_group("Chunk Streaming")
@export_range(100.0, 2000.0, 50.0) var chunk_size: float = 500.0  ## Size of each chunk (meters × meters)
@export_range(500.0, 5000.0, 100.0) var chunk_load_radius: float = 1000.0  ## Load chunks within this distance
@export_range(500.0, 6000.0, 100.0) var chunk_unload_radius: float = 1500.0  ## Unload chunks beyond this distance
@export_range(0.1, 2.0, 0.1) var chunk_update_interval: float = 1.0  ## How often to check for chunk updates (seconds)
@export var max_chunks_per_frame: int = 2  ## Maximum chunks to load/unload per update cycle

# ========================================================================
# STATE
# ========================================================================

# Chunk data storage (organized at startup)
var building_data_by_chunk: Dictionary = {}  # Vector2i → Array[BuildingData]
var road_data_by_chunk: Dictionary = {}      # Vector2i → Array[RoadData]
var park_data_by_chunk: Dictionary = {}      # Vector2i → Array[ParkData]
var water_data_by_chunk: Dictionary = {}     # Vector2i → Array[WaterData]

# Active chunks (currently loaded)
var active_chunks: Dictionary = {}  # Vector2i → Node3D (chunk container)

# Chunk loading states (for queue-based loading)
var chunk_states: Dictionary = {}  # Vector2i → "unloaded" | "loading" | "loaded"

# Feature tracking (for cleanup during unload)
var buildings: Array = []  # Array of {node, position}
var roads: Array = []      # Array of {node, path, position}

# Streaming update timer
var update_timer: float = 0.0

# References to dependencies (injected)
var feature_factory = null  # FeatureFactory instance
var scene_root: Node = null  # Parent node for chunks (CityRenderer or SubViewport)
var loading_queue = null  # LoadingQueue instance

# Camera position tracking (for priority calculation)
var last_camera_pos: Vector2 = Vector2.ZERO

# ========================================================================
# INITIALIZATION
# ========================================================================

func _init(p_feature_factory, p_scene_root: Node):
	"""
	Initialize ChunkManager with dependencies.
	p_scene_root can be CityRenderer (Node3D) or SubViewport (Viewport).
	"""
	feature_factory = p_feature_factory
	scene_root = p_scene_root

	# Create loading queue
	const LoadingQueue = preload("res://scripts/city/loading_queue.gd")
	loading_queue = LoadingQueue.new()
	loading_queue.frame_budget_ms = 5.0
	loading_queue.enable_logging = true

	# Connect signals
	loading_queue.chunk_fully_loaded.connect(_on_chunk_fully_loaded)
	loading_queue.work_completed.connect(_on_work_completed)

## Organize all data into chunks (called at startup)
func organize_data(osm_data: OSMDataComplete):
	print("🏗️  Organizing world into chunks...")
	print("")

	_organize_buildings_into_chunks(osm_data.buildings)
	_organize_roads_into_chunks(osm_data.roads)
	_organize_parks_into_chunks(osm_data.parks)
	_organize_water_into_chunks(osm_data.water)

## Load initial chunks around a position
func load_initial_chunks(center_pos: Vector2) -> int:
	print("")
	print("📦 Loading initial chunks around camera...")

	var initial_chunks = get_chunks_in_radius(center_pos, chunk_load_radius)

	for chunk_key in initial_chunks:
		load_chunk(chunk_key)

	print("")
	print("   ✅ Loaded ", active_chunks.size(), " initial chunks")
	print("      Buildings: ", buildings.size())
	print("      Roads: ", roads.size())

	return active_chunks.size()

# ========================================================================
# UPDATE LOOP
# ========================================================================

## Call this every frame to update streaming
func update(delta: float, camera_pos: Vector3):
	# Process loading queue every frame
	var camera_pos_2d = Vector2(camera_pos.x, -camera_pos.z)
	last_camera_pos = camera_pos_2d
	loading_queue.process(delta)

	# Check for streaming updates less frequently
	update_timer += delta
	if update_timer >= chunk_update_interval:
		_update_streaming(camera_pos_2d)
		_queue_distant_water(camera_pos_2d, chunk_load_radius * 2.0)
		update_timer = 0.0

# ========================================================================
# CHUNK OPERATIONS
# ========================================================================

## Load a chunk (queue work items for gradual loading)
func load_chunk(chunk_key: Vector2i):
	# Check if already loaded or loading
	var state = chunk_states.get(chunk_key, "unloaded")
	if state == "loaded" or state == "loading":
		return

	# Create chunk container immediately (lightweight)
	var chunk_node = Node3D.new()
	chunk_node.name = "Chunk_%d_%d" % [chunk_key.x, chunk_key.y]
	scene_root.add_child(chunk_node)

	# Store chunk reference
	active_chunks[chunk_key] = chunk_node

	# Mark as loading
	chunk_states[chunk_key] = "loading"

	# Get feature data
	var buildings_in_chunk = building_data_by_chunk.get(chunk_key, [])
	var roads_in_chunk = road_data_by_chunk.get(chunk_key, [])
	var parks_in_chunk = park_data_by_chunk.get(chunk_key, [])
	var water_in_chunk = water_data_by_chunk.get(chunk_key, [])

	# Create work items and queue them
	var work_items = feature_factory.create_work_items_for_chunk(
		chunk_key,
		chunk_node,
		buildings_in_chunk,
		roads_in_chunk,
		parks_in_chunk,
		water_in_chunk,
		buildings,
		roads,
		last_camera_pos
	)

	# Queue all work items
	for item in work_items:
		loading_queue.queue_work(item)

	# Log chunk queuing
	var total_features = buildings_in_chunk.size() + roads_in_chunk.size() + parks_in_chunk.size() + water_in_chunk.size()
	if total_features > 0:
		print("   📦 Queued chunk (", chunk_key.x, ",", chunk_key.y, "): ",
			  buildings_in_chunk.size(), " buildings, ",
			  roads_in_chunk.size(), " roads, ",
			  parks_in_chunk.size(), " parks, ",
			  water_in_chunk.size(), " water (", work_items.size(), " work items)")

## Unload a chunk (free all nodes in this chunk)
func unload_chunk(chunk_key: Vector2i):
	if not active_chunks.has(chunk_key):
		return  # Not loaded

	# Cancel any pending work for this chunk
	if loading_queue.is_chunk_loading(chunk_key):
		loading_queue.cancel_chunk(chunk_key)

	var chunk_node = active_chunks[chunk_key]

	# Safety check: ensure chunk_node is valid
	if not is_instance_valid(chunk_node):
		push_warning("Chunk node invalid during unload: (" + str(chunk_key.x) + "," + str(chunk_key.y) + ")")
		active_chunks.erase(chunk_key)
		return

	# Remove buildings from tracking array
	var buildings_to_remove = []
	for i in range(buildings.size()):
		var building_entry = buildings[i]
		var building_node = building_entry.get("node")

		# Null safety: check if node exists and is valid
		if not building_node or not is_instance_valid(building_node):
			buildings_to_remove.append(i)
			continue

		# Check if this building belongs to this chunk
		var building_parent = building_node.get_parent()
		if building_parent == chunk_node:
			buildings_to_remove.append(i)

	# Remove in reverse order to preserve indices
	buildings_to_remove.reverse()
	for i in buildings_to_remove:
		buildings.remove_at(i)

	# Remove roads from tracking array
	var roads_to_remove = []
	for i in range(roads.size()):
		var road_entry = roads[i]
		var road_node = road_entry.get("node")

		# Null safety: check if node exists and is valid
		if not road_node or not is_instance_valid(road_node):
			roads_to_remove.append(i)
			continue

		# Check if this road belongs to this chunk
		var road_parent = road_node.get_parent()
		if road_parent == chunk_node:
			roads_to_remove.append(i)

	# Remove in reverse order to preserve indices
	roads_to_remove.reverse()
	for i in roads_to_remove:
		roads.remove_at(i)

	# Free the chunk and all its children
	chunk_node.queue_free()
	active_chunks.erase(chunk_key)

	# Update state
	chunk_states.erase(chunk_key)

	# Emit signal
	chunk_unloaded.emit(chunk_key)

# ========================================================================
# STREAMING LOGIC
# ========================================================================

## Update chunk streaming based on camera position
func _update_streaming(camera_pos_2d: Vector2):
	# Get chunks that should be loaded
	var chunks_to_load = get_chunks_in_radius(camera_pos_2d, chunk_load_radius)

	# Filter to only new chunks
	var new_chunks = []
	for chunk_key in chunks_to_load:
		if not active_chunks.has(chunk_key):
			new_chunks.append(chunk_key)

	# Sort by distance (load closest first)
	new_chunks.sort_custom(func(a, b):
		var a_center = Vector2(a.x * chunk_size + chunk_size/2, a.y * chunk_size + chunk_size/2)
		var b_center = Vector2(b.x * chunk_size + chunk_size/2, b.y * chunk_size + chunk_size/2)
		return camera_pos_2d.distance_to(a_center) < camera_pos_2d.distance_to(b_center)
	)

	# Load chunks gradually (max_chunks_per_frame at a time)
	var chunks_loaded = 0
	for chunk_key in new_chunks:
		if chunks_loaded >= max_chunks_per_frame:
			break
		load_chunk(chunk_key)
		chunks_loaded += 1

	# Unload distant chunks
	var chunks_to_unload = []
	for chunk_key in active_chunks.keys():
		var chunk_center = Vector2(chunk_key.x * chunk_size + chunk_size/2, chunk_key.y * chunk_size + chunk_size/2)
		var distance = camera_pos_2d.distance_to(chunk_center)

		if distance > chunk_unload_radius:
			chunks_to_unload.append(chunk_key)

	# Unload gradually (max_chunks_per_frame at a time)
	var chunks_unloaded = 0
	for chunk_key in chunks_to_unload:
		if chunks_unloaded >= max_chunks_per_frame:
			break
		unload_chunk(chunk_key)
		chunks_unloaded += 1

	# Emit stats update
	chunks_updated.emit(active_chunks.size(), buildings.size(), roads.size())

# ========================================================================
# UTILITY FUNCTIONS
# ========================================================================

## Convert world position to chunk key
func _get_chunk_key(world_pos: Vector2) -> Vector2i:
	var chunk_x = int(floor(world_pos.x / chunk_size))
	var chunk_y = int(floor(world_pos.y / chunk_size))
	return Vector2i(chunk_x, chunk_y)

## Get all chunk keys within radius of a position
func get_chunks_in_radius(center_pos: Vector2, radius: float) -> Array:
	var chunks = []
	var center_chunk = _get_chunk_key(center_pos)
	var chunk_radius = int(ceil(radius / chunk_size))

	for x in range(center_chunk.x - chunk_radius, center_chunk.x + chunk_radius + 1):
		for y in range(center_chunk.y - chunk_radius, center_chunk.y + chunk_radius + 1):
			var chunk_key = Vector2i(x, y)
			var chunk_center = Vector2(x * chunk_size + chunk_size/2, y * chunk_size + chunk_size/2)

			# Check if chunk center is within radius
			if center_pos.distance_to(chunk_center) <= radius + chunk_size * 0.707:  # Add diagonal
				chunks.append(chunk_key)

	return chunks

## Organize buildings into chunks
func _organize_buildings_into_chunks(buildings_data: Array):
	print("📦 Organizing ", buildings_data.size(), " buildings into chunks...")

	for building_data in buildings_data:
		var center = building_data.get("center", Vector2.ZERO)
		var chunk_key = _get_chunk_key(center)

		if not building_data_by_chunk.has(chunk_key):
			building_data_by_chunk[chunk_key] = []

		building_data_by_chunk[chunk_key].append(building_data)

	print("   ✅ Organized into ", building_data_by_chunk.size(), " chunks")

## Organize roads into chunks
func _organize_roads_into_chunks(roads_data: Array):
	print("📦 Organizing ", roads_data.size(), " roads into chunks...")

	for road_data in roads_data:
		var path = road_data.get("path", [])
		if path.size() < 2:
			continue

		# Calculate road center
		var center = Vector2.ZERO
		for point in path:
			center += point
		center /= path.size()

		var chunk_key = _get_chunk_key(center)

		if not road_data_by_chunk.has(chunk_key):
			road_data_by_chunk[chunk_key] = []

		road_data_by_chunk[chunk_key].append(road_data)

	print("   ✅ Organized into ", road_data_by_chunk.size(), " chunks")

## Organize parks into chunks
func _organize_parks_into_chunks(parks_data: Array):
	print("📦 Organizing ", parks_data.size(), " parks into chunks...")

	for park_data in parks_data:
		var center = park_data.get("center", Vector2.ZERO)
		var chunk_key = _get_chunk_key(center)

		if not park_data_by_chunk.has(chunk_key):
			park_data_by_chunk[chunk_key] = []

		park_data_by_chunk[chunk_key].append(park_data)

	print("   ✅ Organized into ", park_data_by_chunk.size(), " chunks")

## Organize water into chunks
func _organize_water_into_chunks(water_data: Array):
	print("📦 Organizing ", water_data.size(), " water features into chunks...")

	for water_feature in water_data:
		var center = water_feature.get("center", Vector2.ZERO)
		var chunk_key = _get_chunk_key(center)

		if not water_data_by_chunk.has(chunk_key):
			water_data_by_chunk[chunk_key] = []

		water_data_by_chunk[chunk_key].append(water_feature)

	print("   ✅ Organized into ", water_data_by_chunk.size(), " chunks")

## Get stats for external display
func get_stats() -> Dictionary:
	var queue_stats = loading_queue.get_stats() if loading_queue else {}

	return {
		"active_chunks": active_chunks.size(),
		"buildings": buildings.size(),
		"roads": roads.size(),
		"loading_chunks": chunk_states.values().count("loading"),
		"loaded_chunks": chunk_states.values().count("loaded"),
		"queue_size": queue_stats.get("queue_size", 0),
		"items_this_frame": queue_stats.get("items_this_frame", 0)
	}

## Queue large water bodies from distant chunks (lakes should be visible from far away)
func _queue_distant_water(camera_pos: Vector2, extended_radius: float):
	# PROFILING: Start timing
	var distant_water_start = Time.get_ticks_usec()
	var water_bodies_loaded = 0

	var distant_chunks = get_chunks_in_radius(camera_pos, extended_radius)

	for chunk_key in distant_chunks:
		# Skip chunks that are already fully loaded
		if active_chunks.has(chunk_key):
			continue

		# Load ONLY large water from this distant chunk
		var water_in_chunk = water_data_by_chunk.get(chunk_key, [])
		for water_data in water_in_chunk:
			var footprint = water_data.get("footprint", [])
			if footprint.size() < 3:
				continue

			# Only load LARGE water bodies (lakes, not ponds)
			var area = _calculate_polygon_area(footprint)
			if area > 50000.0:  # Same threshold as in water creation
				var center = water_data.get("center", Vector2.ZERO)
				var water_name = water_data.get("name", "")

				# Check if this specific water body is already rendered
				var water_id = "DistantWater_" + str(chunk_key.x) + "_" + str(chunk_key.y) + "_" + water_name
				if not scene_root.has_node(NodePath(water_id)):
					# Queue distant water work item
					loading_queue.queue_work({
						"type": "distant_water",
						"chunk_key": chunk_key,
						"id": water_id,
						"data": water_data,
						"scene_root": scene_root,
						"priority": camera_pos.distance_to(center),
						"estimated_cost_ms": 2.0,  # From profiling
						"queued_time": Time.get_ticks_msec()
					})
					water_bodies_loaded += 1

	if water_bodies_loaded > 0:
		print("   💧 Queued ", water_bodies_loaded, " distant water bodies for loading")

## Calculate polygon area (for water size detection)
func _calculate_polygon_area(polygon: Array) -> float:
	var area = 0.0
	for i in range(polygon.size()):
		var j = (i + 1) % polygon.size()
		area += polygon[i].x * polygon[j].y
		area -= polygon[j].x * polygon[i].y
	return abs(area) / 2.0

# ========================================================================
# SIGNAL HANDLERS
# ========================================================================

## Called when a chunk is fully loaded (all work items completed)
func _on_chunk_fully_loaded(chunk_key: Vector2i):
	# Update state
	chunk_states[chunk_key] = "loaded"

	# Get feature counts for this chunk
	var buildings_count = building_data_by_chunk.get(chunk_key, []).size()
	var roads_count = road_data_by_chunk.get(chunk_key, []).size()
	var parks_count = park_data_by_chunk.get(chunk_key, []).size()
	var water_count = water_data_by_chunk.get(chunk_key, []).size()

	# Emit chunk_loaded signal
	chunk_loaded.emit(chunk_key, {
		"buildings": buildings_count,
		"roads": roads_count,
		"parks": parks_count,
		"water": water_count
	})

## Called when individual work items complete
func _on_work_completed(type: String, chunk_key: Vector2i, node: Node3D):
	# Optional: track individual completions
	# Currently we just rely on chunk_fully_loaded
	pass
