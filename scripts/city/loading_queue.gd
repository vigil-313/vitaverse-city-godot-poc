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
# SIGNALS
# ========================================================================

signal work_completed(type: String, chunk_key: Vector2i, node: Node3D)
signal chunk_fully_loaded(chunk_key: Vector2i)
signal queue_empty()
signal queue_progress(items_remaining: int, items_total: int)

# ========================================================================
# CONFIGURATION
# ========================================================================

@export var frame_budget_ms: float = 5.0  ## Max time to spend on loading per frame
@export var enable_logging: bool = false  ## Enable detailed logging (DISABLED to reduce spam)

# ========================================================================
# STATE
# ========================================================================

var work_queue: Array[Dictionary] = []  # Queue of work items
var work_in_progress: Dictionary = {}   # Work being processed this frame

# Chunk tracking
var chunks_loading: Dictionary = {}     # chunk_key → {total: int, completed: int}

# Statistics
var total_items_queued: int = 0
var total_items_completed: int = 0
var total_time_spent_ms: float = 0.0
var items_this_frame: int = 0

# ========================================================================
# PUBLIC API
# ========================================================================

## Add a work item to the queue
func queue_work(work_item: Dictionary) -> void:
	# Validate work item
	if not work_item.has("type"):
		push_warning("[LoadingQueue] Work item missing 'type' field")
		return

	if not work_item.has("chunk_key"):
		push_warning("[LoadingQueue] Work item missing 'chunk_key' field")
		return

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
	total_items_queued = 0
	total_items_completed = 0
	total_time_spent_ms = 0.0
	print("[LoadingQueue] Queue cleared")

## Get queue statistics for display
func get_stats() -> Dictionary:
	return {
		"queue_size": work_queue.size(),
		"total_queued": total_items_queued,
		"total_completed": total_items_completed,
		"total_time_ms": total_time_spent_ms,
		"chunks_loading": chunks_loading.size(),
		"items_this_frame": items_this_frame
	}

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

## Execute a single work item
func _execute_work_item(work_item: Dictionary) -> bool:
	var type = work_item.type
	var success = false

	match type:
		"building":
			success = _execute_building(work_item)
		"road":
			success = _execute_road(work_item)
		"park":
			success = _execute_park(work_item)
		"water":
			success = _execute_water(work_item)
		"distant_water":
			success = _execute_distant_water(work_item)
		_:
			push_warning("[LoadingQueue] Unknown work item type: " + type)
			return false

	return success

## Execute building creation
func _execute_building(work_item: Dictionary) -> bool:
	var building_data = work_item.get("data")
	var chunk_node = work_item.get("chunk_node")
	var tracking_array = work_item.get("tracking_array")

	if not building_data or not chunk_node:
		push_warning("[LoadingQueue] Invalid building work item")
		return false

	# Import generator
	const BuildingGeneratorMesh = preload("res://scripts/generators/building_generator_mesh.gd")

	# Generate building
	var center = building_data.get("center", Vector2.ZERO)
	var building_node = BuildingGeneratorMesh.create_building(building_data, chunk_node, true)

	if building_node:
		building_node.position = Vector3(center.x, 0, -center.y)

		# Track for cleanup during chunk unload
		tracking_array.append({
			"node": building_node,
			"position": building_node.position
		})

	# Store created node for signal
	work_item["created_node"] = building_node

	return building_node != null

## Execute road creation
func _execute_road(work_item: Dictionary) -> bool:
	var road_data = work_item.get("data")
	var chunk_node = work_item.get("chunk_node")
	var tracking_array = work_item.get("tracking_array")

	if not road_data or not chunk_node:
		push_warning("[LoadingQueue] Invalid road work item")
		return false

	# Import generator
	const RoadGenerator = preload("res://scripts/generators/road_generator.gd")

	# Generate road
	var path = road_data.get("path", [])
	var road_node = RoadGenerator.create_road(path, road_data, chunk_node, tracking_array)

	work_item["created_node"] = road_node

	return road_node != null

## Execute park creation
func _execute_park(work_item: Dictionary) -> bool:
	var park_data = work_item.get("data")
	var chunk_node = work_item.get("chunk_node")

	if not park_data or not chunk_node:
		push_warning("[LoadingQueue] Invalid park work item")
		return false

	# Import generator
	const ParkGenerator = preload("res://scripts/generators/park_generator.gd")

	# Generate park
	var footprint = park_data.get("footprint", [])
	var park_node = ParkGenerator.create_park(footprint, park_data, chunk_node)

	work_item["created_node"] = park_node

	return park_node != null

## Execute water creation
func _execute_water(work_item: Dictionary) -> bool:
	var water_data = work_item.get("data")
	var chunk_node = work_item.get("chunk_node")

	if not water_data or not chunk_node:
		push_warning("[LoadingQueue] Invalid water work item")
		return false

	# Import generator
	const WaterGenerator = preload("res://scripts/generators/water_generator.gd")

	# Generate water
	var water_node = WaterGenerator.create_water(
		water_data.get("footprint", []),
		water_data,
		chunk_node
	)

	work_item["created_node"] = water_node

	return water_node != null

## Execute distant water creation
func _execute_distant_water(work_item: Dictionary) -> bool:
	var water_data = work_item.get("data")
	var scene_root = work_item.get("scene_root")
	var water_id = work_item.get("id", "")

	if not water_data or not scene_root:
		push_warning("[LoadingQueue] Invalid distant water work item")
		return false

	# Check if already exists (prevent duplicates)
	if scene_root.has_node(NodePath(water_id)):
		return true  # Already loaded, skip

	# Import generator
	const WaterGenerator = preload("res://scripts/generators/water_generator.gd")

	# Generate water
	var water_node = WaterGenerator.create_water(
		water_data.get("footprint", []),
		water_data,
		scene_root
	)

	# Set the correct name for duplicate detection
	if water_node and water_id:
		water_node.name = water_id

	work_item["created_node"] = water_node

	return water_node != null

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
