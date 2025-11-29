extends RefCounted
class_name LoadingQueue

## Frame-Budget Work Queue for Chunk Loading
##
## Manages a queue of work items (building, road, park, water creation)
## and processes them gradually with a frame time budget to prevent stuttering.
##
## Usage:
##   var queue = LoadingQueue.new()
##   queue.frame_budget_ms = 5.0
##   queue.queue_work({type: "building", data: building_data, ...})
##   # In _process():
##   queue.process(delta)

# ========================================================================
# GENERATOR PRELOADS (loaded once, shared by all executors)
# ========================================================================

const TerrainMesh = preload("res://scripts/terrain/terrain_mesh.gd")
const BuildingOrchestrator = preload("res://scripts/generators/building/building_orchestrator.gd")
const RoadGenerator = preload("res://scripts/generators/road_generator.gd")
const RoadMeshBatcher = preload("res://scripts/generators/road_mesh_batcher.gd")
const ParkGenerator = preload("res://scripts/generators/park_generator.gd")
const WaterGenerator = preload("res://scripts/generators/water_generator.gd")
const GroundDetailsSystem = preload("res://scripts/generators/ground_details/ground_details_system.gd")
const StreetFurnitureSystem = preload("res://scripts/generators/street_furniture/street_furniture_system.gd")
const VegetationSystem = preload("res://scripts/generators/vegetation/vegetation_system.gd")
const StreetLampPlacer = preload("res://scripts/generators/street_furniture/street_lamp_placer.gd")
const StreetSignGenerator = preload("res://scripts/generators/street_furniture/street_sign_generator.gd")
const TrafficSignGenerator = preload("res://scripts/generators/street_furniture/traffic_sign_generator.gd")
const HighwaySignGenerator = preload("res://scripts/generators/street_furniture/highway_sign_generator.gd")
const TrafficLightGenerator = preload("res://scripts/generators/street_furniture/traffic_light_generator.gd")
const UtilityPoleGenerator = preload("res://scripts/generators/street_furniture/utility_pole_generator.gd")

# ========================================================================
# SIGNALS
# ========================================================================

signal work_completed(type: String, chunk_key: Vector2i, node: Node3D)
signal work_failed(type: String, chunk_key: Vector2i, error: String)
signal chunk_fully_loaded(chunk_key: Vector2i)
signal queue_empty()
signal queue_progress(items_remaining: int, items_total: int)
signal queue_overflow(rejected_count: int)

# ========================================================================
# CONFIGURATION
# ========================================================================

## Max time to spend on loading per frame (initialized from Config)
var frame_budget_ms: float = 5.0
## Enable detailed logging (DISABLED to reduce spam)
var enable_logging: bool = false

# ========================================================================
# STATE
# ========================================================================

var work_queue: Array[Dictionary] = []  # Queue of work items
var work_in_progress: Dictionary = {}   # Work being processed this frame

# Chunk tracking
var chunks_loading: Dictionary = {}     # chunk_key → {total: int, completed: int}

# Failed items tracking
var failed_items: Array[Dictionary] = []  # Recent failed work items for debugging
var total_items_failed: int = 0

# Statistics
var total_items_queued: int = 0
var total_items_completed: int = 0
var total_items_rejected: int = 0  # Rejected due to queue overflow
var total_time_spent_ms: float = 0.0
var items_this_frame: int = 0

# ========================================================================
# PUBLIC API
# ========================================================================

## Add a work item to the queue
## Returns true if queued successfully, false if rejected
func queue_work(work_item: Dictionary) -> bool:
	# Validate work item
	if not work_item.has("type"):
		push_warning("[LoadingQueue] Work item missing 'type' field")
		_track_failed_item(work_item, "missing_type")
		return false

	if not work_item.has("chunk_key"):
		push_warning("[LoadingQueue] Work item missing 'chunk_key' field")
		_track_failed_item(work_item, "missing_chunk_key")
		return false

	# Enforce queue size limit
	if work_queue.size() >= GameConfig.LOADING_MAX_QUEUE_SIZE:
		total_items_rejected += 1
		if total_items_rejected % 100 == 1:  # Log every 100 rejections
			push_warning("[LoadingQueue] Queue full (%d items), rejecting %s for chunk %s" % [
				work_queue.size(), work_item.type, str(work_item.chunk_key)
			])
			queue_overflow.emit(total_items_rejected)
		return false

	# Add to queue
	work_queue.append(work_item)
	total_items_queued += 1

	# Track chunk loading
	var chunk_key = work_item.chunk_key
	if not chunks_loading.has(chunk_key):
		chunks_loading[chunk_key] = {"total": 0, "completed": 0}
	chunks_loading[chunk_key].total += 1

	# Only log if queue is growing dangerously large (potential infinite loop)
	if work_queue.size() > 1000 and work_queue.size() % 100 == 0:
		print("[LoadingQueue] ⚠️  QUEUE GROWING! ", work_queue.size(), " items (", work_item.type, " for chunk ", chunk_key, ")")

	if enable_logging:
		print("[LoadingQueue] Queued ", work_item.type, " for chunk ", chunk_key, " (queue size: ", work_queue.size(), ")")

	return true

## Process work items within frame budget (call every frame)
func process(delta: float) -> void:
	if work_queue.is_empty():
		# Check if any chunks finished loading
		if not chunks_loading.is_empty():
			_finalize_loaded_chunks()
		return

	var frame_start_time = Time.get_ticks_usec()
	var budget_microsec = frame_budget_ms * 1000.0
	var time_spent_microsec = 0.0
	items_this_frame = 0

	# Sort queue by priority (closest first)
	_sort_queue()

	# Process work items until budget exhausted
	while not work_queue.is_empty() and time_spent_microsec < budget_microsec:
		var work_item = work_queue.pop_front()

		# Execute work item
		var item_start_time = Time.get_ticks_usec()
		var success = _execute_work_item(work_item)
		var item_elapsed = Time.get_ticks_usec() - item_start_time

		# Track time
		time_spent_microsec += item_elapsed
		total_time_spent_ms += item_elapsed / 1000.0
		items_this_frame += 1

		if success:
			total_items_completed += 1

			# Update chunk loading progress
			_update_chunk_progress(work_item.chunk_key)

			# Emit work completed signal
			var node = work_item.get("created_node", null)
			work_completed.emit(work_item.type, work_item.chunk_key, node)
		else:
			# Track the failure
			_track_failed_item(work_item, "execution_failed")
			work_failed.emit(work_item.type, work_item.chunk_key, "execution_failed")

			# Still update chunk progress (mark as completed even if failed)
			_update_chunk_progress(work_item.chunk_key)

		# Emit progress signal
		queue_progress.emit(work_queue.size(), total_items_queued)

	# Disabled - too spammy, use QUEUE GROWING warnings instead
	# if items_this_frame > 0 and work_queue.size() > 1000:
	#	var frame_time_ms = time_spent_microsec / 1000.0
	#	print("[LoadingQueue] Processed ", items_this_frame, " items in ", "%.1f" % frame_time_ms, "ms / ", frame_budget_ms, "ms budget (", work_queue.size(), " remaining)")

## Clear all pending work
func clear_queue() -> void:
	work_queue.clear()
	chunks_loading.clear()
	failed_items.clear()
	total_items_queued = 0
	total_items_completed = 0
	total_items_failed = 0
	total_items_rejected = 0
	total_time_spent_ms = 0.0
	print("[LoadingQueue] Queue cleared")

## Get queue statistics for display
func get_stats() -> Dictionary:
	return {
		"queue_size": work_queue.size(),
		"total_queued": total_items_queued,
		"total_completed": total_items_completed,
		"total_failed": total_items_failed,
		"total_rejected": total_items_rejected,
		"total_time_ms": total_time_spent_ms,
		"chunks_loading": chunks_loading.size(),
		"items_this_frame": items_this_frame,
		"queue_utilization": float(work_queue.size()) / float(GameConfig.LOADING_MAX_QUEUE_SIZE) if GameConfig.LOADING_MAX_QUEUE_SIZE > 0 else 0.0
	}

## Get recent failed items for debugging
func get_recent_failures(count: int = 5) -> Array:
	var start_idx = max(0, failed_items.size() - count)
	return failed_items.slice(start_idx)

## Check if a chunk is currently being loaded
func is_chunk_loading(chunk_key: Vector2i) -> bool:
	return chunks_loading.has(chunk_key)

## Count pending work items for a specific chunk
func get_pending_items_for_chunk(chunk_key: Vector2i) -> int:
	var count = 0
	for item in work_queue:
		if item.chunk_key == chunk_key:
			count += 1
	return count

## Cancel all work for a specific chunk
func cancel_chunk(chunk_key: Vector2i) -> void:
	# Remove from queue
	var items_to_remove = []
	for i in range(work_queue.size()):
		if work_queue[i].chunk_key == chunk_key:
			items_to_remove.append(i)

	# Remove in reverse order to preserve indices
	items_to_remove.reverse()
	for i in items_to_remove:
		work_queue.remove_at(i)

	# Remove from tracking
	chunks_loading.erase(chunk_key)

	if enable_logging:
		print("[LoadingQueue] Cancelled ", items_to_remove.size(), " items for chunk ", chunk_key)

# ========================================================================
# PRIVATE METHODS
# ========================================================================

## Sort queue by priority (lower priority = execute first)
func _sort_queue() -> void:
	work_queue.sort_custom(func(a, b):
		var priority_a = a.get("priority", 999999.0)
		var priority_b = b.get("priority", 999999.0)
		return priority_a < priority_b
	)

## Debug counter for building placement
var _debug_building_count: int = 0

## Execute a single work item using type-specific handlers
func _execute_work_item(work_item: Dictionary) -> bool:
	var work_type = work_item.type

	match work_type:
		"terrain":
			return _exec_terrain(work_item)
		"building":
			return _exec_building(work_item)
		"road":
			return _exec_road(work_item)
		"road_batch":
			return _exec_road_batch(work_item)
		"park":
			return _exec_park(work_item)
		"water":
			return _exec_water(work_item)
		"distant_water":
			return _exec_distant_water(work_item)
		"street_furniture":
			return _exec_street_furniture(work_item)
		"ground_details":
			return _exec_ground_details(work_item)
		"vegetation":
			return _exec_vegetation(work_item)
		"lamp_batch":
			return _exec_lamp_batch(work_item)
		"street_signs":
			return _exec_road_furniture(work_item, StreetSignGenerator, "create_chunk_signs")
		"traffic_signs":
			return _exec_road_furniture(work_item, TrafficSignGenerator, "create_chunk_signs")
		"highway_signs":
			return _exec_road_furniture(work_item, HighwaySignGenerator, "create_chunk_signs")
		"traffic_lights":
			return _exec_road_furniture(work_item, TrafficLightGenerator, "create_chunk_lights")
		"utility_poles":
			return _exec_road_furniture(work_item, UtilityPoleGenerator, "create_chunk_poles")
		_:
			push_warning("[LoadingQueue] Unknown work item type: " + work_type)
			return false

# ========================================================================
# WORK ITEM EXECUTORS (consolidated patterns)
# ========================================================================

## Validate common required fields
func _validate_chunk_node(work_item: Dictionary, work_type: String) -> bool:
	if not work_item.get("chunk_node"):
		push_warning("[LoadingQueue] Invalid %s work item - no chunk_node" % work_type)
		return false
	return true

func _validate_road_network(work_item: Dictionary, work_type: String) -> bool:
	if not work_item.get("road_network") or not work_item.get("chunk_node"):
		push_warning("[LoadingQueue] Invalid %s work item" % work_type)
		return false
	return true

## Execute terrain mesh creation
func _exec_terrain(work_item: Dictionary) -> bool:
	if not _validate_chunk_node(work_item, "terrain"):
		return false

	var terrain_node = TerrainMesh.create_terrain_chunk(
		work_item.chunk_key,
		GameConfig.CHUNK_SIZE,
		work_item.get("heightmap")
	)

	if terrain_node:
		work_item.chunk_node.add_child(terrain_node)
	work_item["created_node"] = terrain_node
	return terrain_node != null

## Execute building creation
func _exec_building(work_item: Dictionary) -> bool:
	var building_data = work_item.get("data")
	if not building_data or not work_item.get("chunk_node"):
		push_warning("[LoadingQueue] Invalid building work item")
		return false

	var center = building_data.get("center", Vector2.ZERO)
	var building_node = BuildingOrchestrator.create_building(building_data, work_item.chunk_node, true)

	if building_node:
		var ground_elevation = 0.0
		var heightmap = work_item.get("heightmap")
		if heightmap:
			ground_elevation = heightmap.get_elevation(center.x, -center.y)

		_debug_building_count += 1
		if _debug_building_count <= 5:
			print("[LoadingQueue] Building #", _debug_building_count, " at (", "%.1f" % center.x, ", ", "%.1f" % center.y, ") Y=", "%.2f" % ground_elevation)

		building_node.position = Vector3(center.x, ground_elevation, -center.y)

		var tracking_array = work_item.get("tracking_array")
		if tracking_array:
			tracking_array.append({"node": building_node, "position": building_node.position})

	work_item["created_node"] = building_node
	return building_node != null

## Execute road creation
func _exec_road(work_item: Dictionary) -> bool:
	var road_data = work_item.get("data")
	if not road_data or not work_item.get("chunk_node"):
		push_warning("[LoadingQueue] Invalid road work item")
		return false

	var road_node = RoadGenerator.create_road(
		road_data.get("path", []),
		road_data,
		work_item.chunk_node,
		work_item.get("tracking_array"),
		work_item.get("heightmap")
	)

	work_item["created_node"] = road_node
	return road_node != null

## Execute batched road creation
func _exec_road_batch(work_item: Dictionary) -> bool:
	if not _validate_road_network(work_item, "road_batch"):
		return false

	var batch_node = RoadMeshBatcher.create_chunk_roads(
		work_item.road_network,
		work_item.chunk_key,
		work_item.get("chunk_size", GameConfig.CHUNK_SIZE),
		work_item.get("heightmap"),
		work_item.get("material_library")
	)

	if batch_node:
		work_item.chunk_node.add_child(batch_node)
		var tracking_array = work_item.get("tracking_array")
		if tracking_array:
			tracking_array.append({"node": batch_node, "position": batch_node.position})

	work_item["created_node"] = batch_node
	return batch_node != null

## Execute park creation
func _exec_park(work_item: Dictionary) -> bool:
	var park_data = work_item.get("data")
	if not park_data or not work_item.get("chunk_node"):
		push_warning("[LoadingQueue] Invalid park work item")
		return false

	var park_node = ParkGenerator.create_park(
		park_data.get("footprint", []),
		park_data,
		work_item.chunk_node,
		work_item.get("heightmap")
	)

	work_item["created_node"] = park_node
	return park_node != null

## Execute water creation
func _exec_water(work_item: Dictionary) -> bool:
	var water_data = work_item.get("data")
	if not water_data or not work_item.get("chunk_node"):
		push_warning("[LoadingQueue] Invalid water work item")
		return false

	var water_node = WaterGenerator.create_water(
		water_data.get("footprint", []),
		water_data,
		work_item.chunk_node,
		work_item.get("heightmap")
	)

	work_item["created_node"] = water_node
	return water_node != null

## Execute distant water creation
func _exec_distant_water(work_item: Dictionary) -> bool:
	var water_data = work_item.get("data")
	var scene_root = work_item.get("scene_root")
	var water_id = work_item.get("id", "")

	if not water_data or not scene_root:
		push_warning("[LoadingQueue] Invalid distant water work item")
		return false

	if scene_root.has_node(NodePath(water_id)):
		return true  # Already loaded

	var water_node = WaterGenerator.create_water(
		water_data.get("footprint", []),
		water_data,
		scene_root
	)

	if water_node and water_id:
		water_node.name = water_id

	work_item["created_node"] = water_node
	return water_node != null

## Execute ground details creation
func _exec_ground_details(work_item: Dictionary) -> bool:
	if not _validate_chunk_node(work_item, "ground_details"):
		return false

	GroundDetailsSystem.generate_ground_details_for_chunk(
		work_item.get("buildings_data", []),
		work_item.get("roads_data", []),
		work_item.chunk_node,
		work_item.chunk_key,
		work_item.get("heightmap")
	)
	return true

## Execute street furniture creation
func _exec_street_furniture(work_item: Dictionary) -> bool:
	if not _validate_chunk_node(work_item, "street_furniture"):
		return false

	StreetFurnitureSystem.generate_furniture_for_chunk(
		work_item.get("buildings_data", []),
		work_item.get("roads_data", []),
		work_item.chunk_node,
		work_item.chunk_key,
		work_item.get("heightmap")
	)
	return true

## Execute vegetation creation
func _exec_vegetation(work_item: Dictionary) -> bool:
	if not _validate_chunk_node(work_item, "vegetation"):
		return false

	VegetationSystem.generate_vegetation_for_chunk(
		work_item.get("parks_data", []),
		work_item.get("roads_data", []),
		work_item.chunk_node,
		work_item.chunk_key,
		work_item.get("heightmap")
	)
	return true

## Execute batched lamp creation
func _exec_lamp_batch(work_item: Dictionary) -> bool:
	if not _validate_road_network(work_item, "lamp_batch"):
		return false

	var lamp_node = StreetLampPlacer.create_chunk_lamps(
		work_item.road_network,
		work_item.chunk_key,
		work_item.get("chunk_size", GameConfig.CHUNK_SIZE),
		work_item.get("heightmap"),
		work_item.chunk_node
	)

	work_item["created_node"] = lamp_node
	return lamp_node != null

## Generic road furniture executor (signs, lights, poles)
func _exec_road_furniture(work_item: Dictionary, generator_class, method_name: String) -> bool:
	if not _validate_road_network(work_item, work_item.type):
		return false

	var result_node = generator_class.call(method_name,
		work_item.road_network,
		work_item.chunk_key,
		work_item.get("chunk_size", GameConfig.CHUNK_SIZE),
		work_item.get("heightmap"),
		work_item.chunk_node
	)

	work_item["created_node"] = result_node
	return result_node != null

## Update chunk loading progress
func _update_chunk_progress(chunk_key: Vector2i) -> void:
	if not chunks_loading.has(chunk_key):
		return

	var chunk_info = chunks_loading[chunk_key]
	chunk_info.completed += 1

	# Check if chunk fully loaded
	if chunk_info.completed >= chunk_info.total:
		chunk_fully_loaded.emit(chunk_key)
		chunks_loading.erase(chunk_key)
		# Always log chunk completion (important milestone)
		print("[LoadingQueue] ✅ Chunk ", chunk_key, " fully loaded! (", chunk_info.total, " items)")

## Finalize any chunks that finished loading
func _finalize_loaded_chunks() -> void:
	var chunks_to_finalize = []

	for chunk_key in chunks_loading.keys():
		var chunk_info = chunks_loading[chunk_key]
		if chunk_info.completed >= chunk_info.total:
			chunks_to_finalize.append(chunk_key)

	for chunk_key in chunks_to_finalize:
		chunk_fully_loaded.emit(chunk_key)
		chunks_loading.erase(chunk_key)

		if enable_logging:
			print("[LoadingQueue] ✅ Chunk ", chunk_key, " finalized")

	# Emit queue empty if truly empty
	if work_queue.is_empty() and chunks_loading.is_empty():
		queue_empty.emit()

## Track a failed work item for debugging
func _track_failed_item(work_item: Dictionary, error: String) -> void:
	total_items_failed += 1

	var failed_info = {
		"type": work_item.get("type", "unknown"),
		"chunk_key": work_item.get("chunk_key", Vector2i.ZERO),
		"error": error,
		"timestamp": Time.get_ticks_msec()
	}

	failed_items.append(failed_info)

	# Trim old failures to prevent memory growth
	while failed_items.size() > GameConfig.LOADING_MAX_FAILED_ITEMS:
		failed_items.pop_front()

	if enable_logging:
		push_warning("[LoadingQueue] Failed: %s for chunk %s - %s" % [
			failed_info.type, str(failed_info.chunk_key), error
		])
