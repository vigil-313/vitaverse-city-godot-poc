extends RefCounted
class_name RoadMeshBatcher

## Road Mesh Batcher
## Batches road geometry into per-chunk combined meshes for performance.
## Reduces draw calls from ~5,361 to ~50-100.
##
## Material creation delegated to RoadMaterialBuilder.

const IntersectionGenerator = preload("res://scripts/generators/intersection_generator.gd")
const TerrainPathSmoother = preload("res://scripts/terrain/terrain_path_smoother.gd")
const RoadMaterialBuilder = preload("res://scripts/generators/road_material_builder.gd")

## Re-export MaterialType for backward compatibility
const MaterialType = RoadMaterialBuilder.MaterialType


## Generate batched road meshes for a chunk
## Returns a Node3D containing all batched road geometry
static func create_chunk_roads(
	road_network,
	chunk_key: Vector2i,
	chunk_size: float,
	heightmap,
	material_library = null
) -> Node3D:
	var batch_node = Node3D.new()
	batch_node.name = "RoadBatch_%d_%d" % [chunk_key.x, chunk_key.y]

	# Get segments and intersections in this chunk
	var segments = road_network.get_segments_in_chunk(chunk_key, chunk_size)
	var intersections = road_network.get_intersections_in_chunk(chunk_key, chunk_size)

	if segments.is_empty() and intersections.is_empty():
		return batch_node

	# Initialize SurfaceTools for each material type
	var batches: Dictionary = {}
	for type in MaterialType.values():
		batches[type] = SurfaceTool.new()
		batches[type].begin(Mesh.PRIMITIVE_TRIANGLES)

	# Calculate chunk center for local coordinates
	var chunk_center = Vector3(
		chunk_key.x * chunk_size + chunk_size / 2.0,
		0.0,
		-(chunk_key.y * chunk_size + chunk_size / 2.0)
	)

	# Process all segments
	for segment in segments:
		_add_segment_to_batch(segment, batches, heightmap, chunk_center)

	# Process all intersections
	for intersection in intersections:
		_add_intersection_to_batch(intersection, batches, heightmap, chunk_center)

	# Create MeshInstance3D for each material type with geometry
	for type in MaterialType.values():
		var st: SurfaceTool = batches[type]

		# Commit mesh (skip tangent generation - not needed for road surfaces)
		var mesh = st.commit()

		if mesh and mesh.get_surface_count() > 0:
			var mesh_instance = MeshInstance3D.new()
			mesh_instance.name = RoadMaterialBuilder.get_type_name(type)
			mesh_instance.mesh = mesh
			mesh_instance.material_override = RoadMaterialBuilder.get_material(type, material_library)
			batch_node.add_child(mesh_instance)

	# Position batch at chunk center
	batch_node.position = chunk_center

	return batch_node


## Sidewalk properties
const SIDEWALK_WIDTH: float = 2.0  # 2 meter sidewalks
const CURB_WIDTH: float = 0.25
const CURB_HEIGHT: float = 0.15


## Add segment geometry to batches
static func _add_segment_to_batch(segment, batches: Dictionary, heightmap, chunk_center: Vector3) -> void:
	if segment.path.size() < 2:
		return

	# Get smoothed 3D path
	var path_3d = TerrainPathSmoother.smooth_path(segment.path, heightmap, segment.calculated_width)
	if path_3d.size() < 2:
		return

	var half_width = segment.calculated_width / 2.0

	# Determine which SurfaceTool to use based on road type
	var surface_st: SurfaceTool
	if segment.is_pedestrian():
		surface_st = batches[MaterialType.CONCRETE]  # Footways are concrete
	else:
		surface_st = batches[MaterialType.ASPHALT]  # Roads are asphalt

	for i in range(path_3d.size() - 1):
		var pos = path_3d[i] - chunk_center
		var next_pos = path_3d[i + 1] - chunk_center

		var direction = (path_3d[i + 1] - path_3d[i]).normalized()
		var perpendicular = Vector3(-direction.z, 0, direction.x).normalized()

		# Raise slightly above terrain
		pos.y += 0.05
		next_pos.y += 0.05

		var left = pos + perpendicular * half_width
		var right = pos - perpendicular * half_width
		var left_next = next_pos + perpendicular * half_width
		var right_next = next_pos - perpendicular * half_width

		# Add quad (2 triangles)
		surface_st.set_normal(Vector3.UP)
		surface_st.set_uv(Vector2(0, float(i)))
		surface_st.add_vertex(left)

		surface_st.set_normal(Vector3.UP)
		surface_st.set_uv(Vector2(1, float(i)))
		surface_st.add_vertex(right)

		surface_st.set_normal(Vector3.UP)
		surface_st.set_uv(Vector2(1, float(i + 1)))
		surface_st.add_vertex(right_next)

		surface_st.set_normal(Vector3.UP)
		surface_st.set_uv(Vector2(0, float(i)))
		surface_st.add_vertex(left)

		surface_st.set_normal(Vector3.UP)
		surface_st.set_uv(Vector2(1, float(i + 1)))
		surface_st.add_vertex(right_next)

		surface_st.set_normal(Vector3.UP)
		surface_st.set_uv(Vector2(0, float(i + 1)))
		surface_st.add_vertex(left_next)

	# Add curbs and sidewalks for driveable roads
	# Skip sidewalks/curbs near intersections to avoid crossing other roads
	if segment.is_driveable():
		_add_curbs_to_batch(segment, path_3d, batches[MaterialType.CURB], chunk_center, half_width, heightmap)
		_add_sidewalks_to_batch(segment, path_3d, batches[MaterialType.CONCRETE], chunk_center, half_width, heightmap)
		_add_lane_markings_to_batch(segment, path_3d, batches, chunk_center, half_width)


## Add curb geometry to batch
static func _add_curbs_to_batch(segment, path_3d: Array, st: SurfaceTool, chunk_center: Vector3, half_width: float, heightmap) -> void:
	var curb_width = 0.25
	var curb_height = 0.15

	# Skip first and last segments if connected to intersections (avoid crossing roads)
	var start_idx = 0
	var end_idx = path_3d.size() - 1

	if segment.start_intersection != null:
		start_idx = mini(2, path_3d.size() - 2)  # Skip first 2 segments (~10m)
	if segment.end_intersection != null:
		end_idx = maxi(path_3d.size() - 3, start_idx + 1)  # Skip last 2 segments

	for i in range(start_idx, end_idx):
		var pos = path_3d[i] - chunk_center
		var next_pos = path_3d[i + 1] - chunk_center

		var direction = (path_3d[i + 1] - path_3d[i]).normalized()
		var perpendicular = Vector3(-direction.z, 0, direction.x).normalized()

		pos.y += 0.05
		next_pos.y += 0.05

		# Left curb
		var left_inner = pos + perpendicular * half_width
		var left_outer = pos + perpendicular * (half_width + curb_width)
		var left_inner_next = next_pos + perpendicular * half_width
		var left_outer_next = next_pos + perpendicular * (half_width + curb_width)

		# Top of left curb
		var left_inner_top = left_inner + Vector3(0, curb_height, 0)
		var left_outer_top = left_outer + Vector3(0, curb_height, 0)
		var left_inner_top_next = left_inner_next + Vector3(0, curb_height, 0)
		var left_outer_top_next = left_outer_next + Vector3(0, curb_height, 0)

		# Left curb top face
		_add_quad_to_st(st, left_inner_top, left_outer_top, left_outer_top_next, left_inner_top_next, Vector3.UP)

		# Left curb inner face
		_add_quad_to_st(st, left_inner, left_inner_top, left_inner_top_next, left_inner_next, -perpendicular)

		# Right curb (mirror)
		var right_inner = pos - perpendicular * half_width
		var right_outer = pos - perpendicular * (half_width + curb_width)
		var right_inner_next = next_pos - perpendicular * half_width
		var right_outer_next = next_pos - perpendicular * (half_width + curb_width)

		var right_inner_top = right_inner + Vector3(0, curb_height, 0)
		var right_outer_top = right_outer + Vector3(0, curb_height, 0)
		var right_inner_top_next = right_inner_next + Vector3(0, curb_height, 0)
		var right_outer_top_next = right_outer_next + Vector3(0, curb_height, 0)

		# Right curb top face
		_add_quad_to_st(st, right_outer_top, right_inner_top, right_inner_top_next, right_outer_top_next, Vector3.UP)

		# Right curb inner face
		_add_quad_to_st(st, right_inner_top, right_inner, right_inner_next, right_inner_top_next, perpendicular)


## Add sidewalk geometry to batch (alongside roads)
static func _add_sidewalks_to_batch(segment, path_3d: Array, st: SurfaceTool, chunk_center: Vector3, half_width: float, heightmap) -> void:
	# Sidewalk sits outside the curb
	var sidewalk_inner = half_width + CURB_WIDTH
	var sidewalk_outer = sidewalk_inner + SIDEWALK_WIDTH

	# Skip first and last segments if connected to intersections (avoid crossing roads)
	var start_idx = 0
	var end_idx = path_3d.size() - 1

	if segment.start_intersection != null:
		start_idx = mini(2, path_3d.size() - 2)  # Skip first 2 segments (~10m)
	if segment.end_intersection != null:
		end_idx = maxi(path_3d.size() - 3, start_idx + 1)  # Skip last 2 segments

	for i in range(start_idx, end_idx):
		var pos = path_3d[i] - chunk_center
		var next_pos = path_3d[i + 1] - chunk_center

		var direction = (path_3d[i + 1] - path_3d[i]).normalized()
		var perpendicular = Vector3(-direction.z, 0, direction.x).normalized()

		# Sample terrain at actual sidewalk positions for proper elevation
		var world_pos = path_3d[i]
		var world_next = path_3d[i + 1]

		# Left sidewalk - sample terrain at sidewalk position
		var left_pos_2d = Vector2(world_pos.x, -world_pos.z) + Vector2(perpendicular.x, perpendicular.z) * (sidewalk_inner + SIDEWALK_WIDTH / 2.0)
		var left_next_2d = Vector2(world_next.x, -world_next.z) + Vector2(perpendicular.x, perpendicular.z) * (sidewalk_inner + SIDEWALK_WIDTH / 2.0)

		var left_elevation = pos.y + 0.05 + CURB_HEIGHT
		var left_elevation_next = next_pos.y + 0.05 + CURB_HEIGHT

		if heightmap:
			var terrain_left = heightmap.get_elevation(left_pos_2d.x, -left_pos_2d.y)
			var terrain_left_next = heightmap.get_elevation(left_next_2d.x, -left_next_2d.y)
			# Use higher of road-based or terrain-based elevation
			left_elevation = maxf(left_elevation, terrain_left + 0.1)
			left_elevation_next = maxf(left_elevation_next, terrain_left_next + 0.1)

		var left_inner = Vector3(pos.x + perpendicular.x * sidewalk_inner, left_elevation, pos.z + perpendicular.z * sidewalk_inner)
		var left_outer = Vector3(pos.x + perpendicular.x * sidewalk_outer, left_elevation, pos.z + perpendicular.z * sidewalk_outer)
		var left_inner_next = Vector3(next_pos.x + perpendicular.x * sidewalk_inner, left_elevation_next, next_pos.z + perpendicular.z * sidewalk_inner)
		var left_outer_next = Vector3(next_pos.x + perpendicular.x * sidewalk_outer, left_elevation_next, next_pos.z + perpendicular.z * sidewalk_outer)

		_add_quad_to_st(st, left_inner, left_outer, left_outer_next, left_inner_next, Vector3.UP)

		# Right sidewalk - sample terrain at sidewalk position
		var right_pos_2d = Vector2(world_pos.x, -world_pos.z) - Vector2(perpendicular.x, perpendicular.z) * (sidewalk_inner + SIDEWALK_WIDTH / 2.0)
		var right_next_2d = Vector2(world_next.x, -world_next.z) - Vector2(perpendicular.x, perpendicular.z) * (sidewalk_inner + SIDEWALK_WIDTH / 2.0)

		var right_elevation = pos.y + 0.05 + CURB_HEIGHT
		var right_elevation_next = next_pos.y + 0.05 + CURB_HEIGHT

		if heightmap:
			var terrain_right = heightmap.get_elevation(right_pos_2d.x, -right_pos_2d.y)
			var terrain_right_next = heightmap.get_elevation(right_next_2d.x, -right_next_2d.y)
			right_elevation = maxf(right_elevation, terrain_right + 0.1)
			right_elevation_next = maxf(right_elevation_next, terrain_right_next + 0.1)

		var right_inner = Vector3(pos.x - perpendicular.x * sidewalk_inner, right_elevation, pos.z - perpendicular.z * sidewalk_inner)
		var right_outer = Vector3(pos.x - perpendicular.x * sidewalk_outer, right_elevation, pos.z - perpendicular.z * sidewalk_outer)
		var right_inner_next = Vector3(next_pos.x - perpendicular.x * sidewalk_inner, right_elevation_next, next_pos.z - perpendicular.z * sidewalk_inner)
		var right_outer_next = Vector3(next_pos.x - perpendicular.x * sidewalk_outer, right_elevation_next, next_pos.z - perpendicular.z * sidewalk_outer)

		_add_quad_to_st(st, right_outer, right_inner, right_inner_next, right_outer_next, Vector3.UP)


## Lane marking constants
const MARKING_WIDTH: float = 0.15       # 15cm wide lines
const DASH_LENGTH: float = 3.0          # 3m dashes
const DASH_GAP: float = 3.0             # 3m gaps
const MARKING_HEIGHT: float = 0.06      # Slightly above road surface


## Add lane markings to batch (center line + edge lines)
static func _add_lane_markings_to_batch(segment, path_3d: Array, batches: Dictionary, chunk_center: Vector3, half_width: float) -> void:
	if path_3d.size() < 4:
		return

	# Skip very narrow roads (service roads, alleys)
	if segment.calculated_width < 5.0:
		return

	# Trim path to stop before intersections (don't draw markings through intersections)
	var start_idx = 0
	var end_idx = path_3d.size() - 1

	# Skip first segments if connected to intersection
	if segment.start_intersection != null:
		start_idx = mini(3, path_3d.size() - 2)  # Skip ~15m at start
	# Skip last segments if connected to intersection
	if segment.end_intersection != null:
		end_idx = maxi(path_3d.size() - 4, start_idx + 1)  # Skip ~15m at end

	# Need at least 2 points after trimming
	if end_idx <= start_idx:
		return

	# Extract trimmed path
	var trimmed_path: Array = []
	for i in range(start_idx, end_idx + 1):
		trimmed_path.append(path_3d[i])

	if trimmed_path.size() < 2:
		return

	# Determine marking type based on road
	var is_oneway = segment.is_oneway
	var lanes = segment.lanes if segment.lanes > 0 else 2

	# Yellow center line for two-way roads
	if not is_oneway and segment.calculated_width >= 6.0:
		_add_center_line_to_batch(trimmed_path, batches[MaterialType.MARKING_YELLOW], chunk_center, is_oneway)

	# White edge lines
	_add_edge_lines_to_batch(trimmed_path, batches[MaterialType.MARKING_WHITE], chunk_center, half_width)

	# White lane dividers for multi-lane roads
	if lanes > 2:
		_add_lane_dividers_to_batch(trimmed_path, batches[MaterialType.MARKING_WHITE], chunk_center, half_width, lanes, is_oneway)


## Add yellow center line (dashed for passing zones, solid near intersections)
static func _add_center_line_to_batch(path_3d: Array, st: SurfaceTool, chunk_center: Vector3, is_oneway: bool) -> void:
	var accumulated_length = 0.0
	var in_dash = true  # Start with a dash

	for i in range(path_3d.size() - 1):
		var pos = path_3d[i] - chunk_center
		var next_pos = path_3d[i + 1] - chunk_center
		var seg_length = path_3d[i].distance_to(path_3d[i + 1])

		var direction = (path_3d[i + 1] - path_3d[i]).normalized()
		var perpendicular = Vector3(-direction.z, 0, direction.x).normalized()

		# Raise above road
		pos.y += MARKING_HEIGHT
		next_pos.y += MARKING_HEIGHT

		# Center line position
		var left = pos + perpendicular * MARKING_WIDTH / 2.0
		var right = pos - perpendicular * MARKING_WIDTH / 2.0
		var left_next = next_pos + perpendicular * MARKING_WIDTH / 2.0
		var right_next = next_pos - perpendicular * MARKING_WIDTH / 2.0

		# Determine if we're in a dash or gap
		var dash_cycle = DASH_LENGTH + DASH_GAP
		var pos_in_cycle = fmod(accumulated_length, dash_cycle)
		in_dash = pos_in_cycle < DASH_LENGTH

		if in_dash:
			_add_quad_to_st(st, left, right, right_next, left_next, Vector3.UP)

		accumulated_length += seg_length


## Add white edge lines at road edges
static func _add_edge_lines_to_batch(path_3d: Array, st: SurfaceTool, chunk_center: Vector3, half_width: float) -> void:
	var edge_offset = half_width - MARKING_WIDTH - 0.1  # Slightly inside curb

	for i in range(path_3d.size() - 1):
		var pos = path_3d[i] - chunk_center
		var next_pos = path_3d[i + 1] - chunk_center

		var direction = (path_3d[i + 1] - path_3d[i]).normalized()
		var perpendicular = Vector3(-direction.z, 0, direction.x).normalized()

		pos.y += MARKING_HEIGHT
		next_pos.y += MARKING_HEIGHT

		# Left edge line
		var left_inner = pos + perpendicular * edge_offset
		var left_outer = pos + perpendicular * (edge_offset + MARKING_WIDTH)
		var left_inner_next = next_pos + perpendicular * edge_offset
		var left_outer_next = next_pos + perpendicular * (edge_offset + MARKING_WIDTH)

		_add_quad_to_st(st, left_inner, left_outer, left_outer_next, left_inner_next, Vector3.UP)

		# Right edge line
		var right_inner = pos - perpendicular * edge_offset
		var right_outer = pos - perpendicular * (edge_offset + MARKING_WIDTH)
		var right_inner_next = next_pos - perpendicular * edge_offset
		var right_outer_next = next_pos - perpendicular * (edge_offset + MARKING_WIDTH)

		_add_quad_to_st(st, right_outer, right_inner, right_inner_next, right_outer_next, Vector3.UP)


## Add white dashed lane dividers for multi-lane roads
static func _add_lane_dividers_to_batch(path_3d: Array, st: SurfaceTool, chunk_center: Vector3, half_width: float, lanes: int, is_oneway: bool) -> void:
	# Calculate lane positions
	var lane_width = (half_width * 2.0) / float(lanes)
	var divider_positions: Array = []

	if is_oneway:
		# All lanes same direction - dividers between each lane
		for lane_idx in range(1, lanes):
			var offset = -half_width + lane_idx * lane_width
			divider_positions.append(offset)
	else:
		# Two-way road - dividers on each half (skip center, that's yellow)
		var half_lanes = lanes / 2
		for lane_idx in range(1, half_lanes):
			# Left side dividers
			divider_positions.append(lane_idx * lane_width)
			# Right side dividers
			divider_positions.append(-lane_idx * lane_width)

	var accumulated_length = 0.0

	for i in range(path_3d.size() - 1):
		var pos = path_3d[i] - chunk_center
		var next_pos = path_3d[i + 1] - chunk_center
		var seg_length = path_3d[i].distance_to(path_3d[i + 1])

		var direction = (path_3d[i + 1] - path_3d[i]).normalized()
		var perpendicular = Vector3(-direction.z, 0, direction.x).normalized()

		pos.y += MARKING_HEIGHT
		next_pos.y += MARKING_HEIGHT

		# Check if in dash
		var dash_cycle = DASH_LENGTH + DASH_GAP
		var pos_in_cycle = fmod(accumulated_length, dash_cycle)
		var in_dash = pos_in_cycle < DASH_LENGTH

		if in_dash:
			for offset in divider_positions:
				var left = pos + perpendicular * (offset + MARKING_WIDTH / 2.0)
				var right = pos + perpendicular * (offset - MARKING_WIDTH / 2.0)
				var left_next = next_pos + perpendicular * (offset + MARKING_WIDTH / 2.0)
				var right_next = next_pos + perpendicular * (offset - MARKING_WIDTH / 2.0)

				_add_quad_to_st(st, left, right, right_next, left_next, Vector3.UP)

		accumulated_length += seg_length


## Crosswalk constants
const CROSSWALK_WIDTH: float = 3.0      # 3m wide crosswalks
const CROSSWALK_STRIPE_WIDTH: float = 0.4
const CROSSWALK_STRIPE_GAP: float = 0.4


## Add intersection geometry to batches
static func _add_intersection_to_batch(intersection, batches: Dictionary, heightmap, chunk_center: Vector3) -> void:
	if intersection.polygon.size() < 3:
		return

	var asphalt_st: SurfaceTool = batches[MaterialType.ASPHALT]

	# Get elevation at intersection
	var elevation = 0.0
	if heightmap:
		elevation = TerrainPathSmoother.get_smoothed_elevation(
			intersection.position, heightmap, intersection.get_max_road_width() / 2.0
		)

	# Convert polygon to local coordinates
	var local_polygon: Array = []
	for point in intersection.polygon:
		var world_pos = Vector3(point.x, elevation + 0.05, -point.y)
		var local = world_pos - chunk_center
		local_polygon.append(local)

	# Triangulate using fan from center
	var center = Vector3.ZERO
	for point in local_polygon:
		center += point
	center /= local_polygon.size()

	for i in range(local_polygon.size()):
		var p1 = local_polygon[i]
		var p2 = local_polygon[(i + 1) % local_polygon.size()]

		asphalt_st.set_normal(Vector3.UP)
		asphalt_st.set_uv(Vector2(0.5, 0.5))
		asphalt_st.add_vertex(center)

		asphalt_st.set_normal(Vector3.UP)
		asphalt_st.set_uv(Vector2(0, 0))
		asphalt_st.add_vertex(p1)

		asphalt_st.set_normal(Vector3.UP)
		asphalt_st.set_uv(Vector2(1, 0))
		asphalt_st.add_vertex(p2)

	# Add crosswalks at intersections with 3+ driveable roads
	if intersection.connections.size() >= 3:
		_add_crosswalks_to_intersection(intersection, batches[MaterialType.MARKING_WHITE], elevation, chunk_center, heightmap)


## Add crosswalk stripes at intersection entrances
## Places crosswalk perpendicular to each road leaving the intersection
static func _add_crosswalks_to_intersection(intersection, st: SurfaceTool, elevation: float, chunk_center: Vector3, heightmap = null) -> void:
	var white_st = st

	# For each road connection, place a crosswalk across its entrance
	for connection in intersection.connections:
		var segment = connection.get("segment")
		if segment == null or not segment.is_driveable():
			continue

		var is_start = connection.get("is_start", false)

		# Get direction of road leaving intersection (outward)
		var outgoing_dir: Vector2
		if is_start:
			outgoing_dir = segment.get_start_direction()
		else:
			outgoing_dir = -segment.get_end_direction()

		# Road width determines crosswalk length
		var road_width = segment.calculated_width
		if road_width < 4.0:
			continue  # Skip very narrow roads

		# Crosswalk is perpendicular to road direction
		var crosswalk_dir = Vector2(-outgoing_dir.y, outgoing_dir.x)

		# Position crosswalk on the road, setback from intersection
		# Use max road width to clear the intersection area
		var setback = intersection.get_max_road_width() * 0.5 + 3.0

		var crosswalk_center_2d = intersection.position + outgoing_dir * setback

		# Get elevation at actual crosswalk position for proper height
		var crosswalk_elevation = elevation
		if heightmap:
			crosswalk_elevation = heightmap.get_elevation(crosswalk_center_2d.x, -crosswalk_center_2d.y)

		# Place crosswalks above road surface (road is at +0.05)
		var crosswalk_center = Vector3(crosswalk_center_2d.x, crosswalk_elevation + 0.08, -crosswalk_center_2d.y) - chunk_center

		# Convert directions to 3D
		var crosswalk_dir_3d = Vector3(crosswalk_dir.x, 0, -crosswalk_dir.y)
		var road_dir_3d = Vector3(outgoing_dir.x, 0, -outgoing_dir.y)

		# Stripe dimensions - full road width
		var stripe_length = road_width * 0.9
		var half_stripe_length = stripe_length / 2.0

		# Draw zebra stripes
		var num_stripes = int(CROSSWALK_WIDTH / (CROSSWALK_STRIPE_WIDTH + CROSSWALK_STRIPE_GAP))

		for stripe_idx in range(num_stripes):
			var stripe_offset = -CROSSWALK_WIDTH / 2.0 + stripe_idx * (CROSSWALK_STRIPE_WIDTH + CROSSWALK_STRIPE_GAP)
			var stripe_center = crosswalk_center + road_dir_3d * stripe_offset

			# Stripe corners (stripe runs perpendicular to road)
			var p1 = stripe_center - crosswalk_dir_3d * half_stripe_length - road_dir_3d * CROSSWALK_STRIPE_WIDTH / 2.0
			var p2 = stripe_center + crosswalk_dir_3d * half_stripe_length - road_dir_3d * CROSSWALK_STRIPE_WIDTH / 2.0
			var p3 = stripe_center + crosswalk_dir_3d * half_stripe_length + road_dir_3d * CROSSWALK_STRIPE_WIDTH / 2.0
			var p4 = stripe_center - crosswalk_dir_3d * half_stripe_length + road_dir_3d * CROSSWALK_STRIPE_WIDTH / 2.0

			_add_quad_to_st(white_st, p1, p2, p3, p4, Vector3.UP)


## Helper to add a quad to SurfaceTool
static func _add_quad_to_st(st: SurfaceTool, p1: Vector3, p2: Vector3, p3: Vector3, p4: Vector3, normal: Vector3) -> void:
	st.set_normal(normal)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(p1)

	st.set_normal(normal)
	st.set_uv(Vector2(1, 0))
	st.add_vertex(p2)

	st.set_normal(normal)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(p3)

	st.set_normal(normal)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(p1)

	st.set_normal(normal)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(p3)

	st.set_normal(normal)
	st.set_uv(Vector2(0, 1))
	st.add_vertex(p4)


## Clear material cache (delegates to RoadMaterialBuilder)
static func clear_material_cache() -> void:
	RoadMaterialBuilder.clear_cache()
