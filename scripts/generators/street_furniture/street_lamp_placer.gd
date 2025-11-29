extends RefCounted
class_name StreetLampPlacer

## Street Lamp Placer
## Places street lamps using the road network graph for proper positioning.
##
## Features:
## - Places lamps on sidewalks (alongside road segments)
## - Places lamps at intersection corners
## - Global spacing coordination (doesn't restart at each road)
## - Uses GPU instancing for performance

const TerrainPathSmoother = preload("res://scripts/terrain/terrain_path_smoother.gd")

## Lamp placement parameters
const LAMP_SPACING: float = 60.0        # 60m between lamps along roads (reduced density)
const SIDEWALK_OFFSET: float = 3.5      # Distance from road edge to lamp
const INTERSECTION_CORNER_INSET: float = 5.0  # How far into intersection for corner lamps
const MIN_SEGMENT_LENGTH: float = 40.0  # Skip short segments
const MAX_LAMPS_PER_CHUNK: int = 30     # Limit lamps per chunk to avoid light limits

## Lamp dimensions (for instancing)
const LAMP_HEIGHT: float = 4.5
const LAMP_MESH_RESOURCE: String = "res://assets/meshes/street_lamp.tres"

## Cached data
static var _lamp_mesh: Mesh = null
static var _pole_material: StandardMaterial3D = null
static var _housing_material: StandardMaterial3D = null


## Generate lamps for a chunk using the road network
## Returns a Node3D containing all lamp instances (using MultiMeshInstance3D for performance)
static func create_chunk_lamps(
	road_network,
	chunk_key: Vector2i,
	chunk_size: float,
	heightmap,
	parent: Node = null
) -> Node3D:
	var lamp_node = Node3D.new()
	lamp_node.name = "StreetLamps_%d_%d" % [chunk_key.x, chunk_key.y]

	# Collect all lamp positions for this chunk
	var lamp_positions: Array = []  # Array of {pos: Vector3, rotation: float}

	# Get segments in this chunk
	var segments = road_network.get_segments_in_chunk(chunk_key, chunk_size)

	# Place lamps along segments (on sidewalks) - only major roads
	for segment in segments:
		if _is_major_road(segment):
			_collect_segment_lamp_positions(segment, heightmap, lamp_positions)
			# Stop if we hit the limit
			if lamp_positions.size() >= MAX_LAMPS_PER_CHUNK:
				break

	# Limit total lamps per chunk
	if lamp_positions.size() > MAX_LAMPS_PER_CHUNK:
		lamp_positions.resize(MAX_LAMPS_PER_CHUNK)

	if lamp_positions.is_empty():
		if parent:
			parent.add_child(lamp_node)
		return lamp_node

	# Create using MultiMeshInstance3D for GPU instancing
	_create_instanced_lamps(lamp_node, lamp_positions)

	if parent:
		parent.add_child(lamp_node)

	return lamp_node


## Check if road is suitable for street lamps
static func _is_major_road(segment) -> bool:
	# Place lamps on most driveable roads, skip only footways/paths/service
	var lamp_types = ["primary", "primary_link", "secondary", "secondary_link",
					  "tertiary", "tertiary_link", "trunk", "trunk_link",
					  "residential", "unclassified", "living_street"]
	return segment.highway_type in lamp_types


## Collect lamp positions along a road segment's sidewalks
static func _collect_segment_lamp_positions(segment, heightmap, positions: Array) -> void:
	if segment.path.size() < 2:
		return

	# Calculate segment length
	var total_length = segment.length
	if total_length < MIN_SEGMENT_LENGTH:
		return

	# Get smoothed 3D path
	var path_3d = TerrainPathSmoother.smooth_path(segment.path, heightmap, segment.calculated_width)
	if path_3d.size() < 2:
		return

	var half_width = segment.calculated_width / 2.0

	# Use segment's way_id to create consistent global spacing
	# This ensures lamps are placed at consistent intervals regardless of which chunk they're in
	var segment_hash = hash(segment.way_id)
	var global_offset = fmod(float(abs(segment_hash)), LAMP_SPACING)

	# Calculate number of lamps for this segment
	var num_lamps = int((total_length - global_offset) / LAMP_SPACING)
	if num_lamps < 1:
		return

	# Track accumulated distance
	var accumulated_length = 0.0
	var path_segment_idx = 0

	# Place lamps along the segment
	for lamp_idx in range(num_lamps):
		var target_dist = global_offset + lamp_idx * LAMP_SPACING

		# Skip if too close to start/end (intersection area)
		if target_dist < 8.0 or target_dist > total_length - 8.0:
			continue

		# Find position along path at target distance
		while path_segment_idx < path_3d.size() - 1:
			var seg_length = path_3d[path_segment_idx].distance_to(path_3d[path_segment_idx + 1])
			if accumulated_length + seg_length >= target_dist:
				break
			accumulated_length += seg_length
			path_segment_idx += 1

		if path_segment_idx >= path_3d.size() - 1:
			break

		# Interpolate position
		var seg_start = path_3d[path_segment_idx]
		var seg_end = path_3d[path_segment_idx + 1]
		var seg_length = seg_start.distance_to(seg_end)
		var t = (target_dist - accumulated_length) / seg_length if seg_length > 0 else 0
		t = clamp(t, 0.0, 1.0)

		var center_pos = seg_start.lerp(seg_end, t)

		# Calculate direction and perpendicular
		var direction = (seg_end - seg_start).normalized()
		var perpendicular = Vector3(-direction.z, 0, direction.x).normalized()

		# Calculate rotation (facing along the road)
		var rotation = atan2(direction.x, direction.z)

		# Place lamps on both sides of the road (staggered)
		var side = 1.0 if lamp_idx % 2 == 0 else -1.0
		var lamp_offset = half_width + SIDEWALK_OFFSET

		var lamp_pos = center_pos + perpendicular * (lamp_offset * side)
		lamp_pos.y += 0.02  # Slightly above terrain

		positions.append({
			"position": lamp_pos,
			"rotation": rotation + (PI if side < 0 else 0)  # Face inward toward road
		})


## Collect lamp positions at intersection corners
static func _collect_intersection_lamp_positions(intersection, heightmap, positions: Array) -> void:
	if intersection.polygon.size() < 3:
		return

	# Only place corner lamps at real intersections (2+ roads meeting)
	if intersection.connections.size() < 2:
		return

	# Get elevation at intersection
	var elevation = 0.0
	if heightmap:
		elevation = TerrainPathSmoother.get_smoothed_elevation(
			intersection.position, heightmap, intersection.get_max_road_width() / 2.0
		)

	# For each corner of the intersection polygon, potentially place a lamp
	# We want lamps at "outer" corners where roads diverge
	var polygon_size = intersection.polygon.size()

	# Find corners that are suitable for lamps (between different road arms)
	for i in range(polygon_size):
		var corner = intersection.polygon[i]

		# Check if this corner is far enough from the center
		var corner_dist = corner.distance_to(intersection.position)
		if corner_dist < 3.0:  # Too close to center
			continue

		# Calculate world position
		var corner_3d = Vector3(corner.x, elevation + 0.02, -corner.y)

		# Move corner outward slightly for lamp position
		var outward_dir = (corner - intersection.position).normalized()
		var lamp_pos_2d = corner + outward_dir * INTERSECTION_CORNER_INSET
		var lamp_pos = Vector3(lamp_pos_2d.x, elevation + 0.02, -lamp_pos_2d.y)

		# Calculate rotation (facing toward intersection center)
		var facing_dir = intersection.position - corner
		var rotation = atan2(facing_dir.x, -facing_dir.y)

		# Only add every other corner to avoid overcrowding
		# Use a deterministic selection based on corner index and intersection ID
		var selection_hash = hash(str(intersection.node_id) + "_" + str(i))
		if selection_hash % 3 != 0:  # Skip ~2/3 of corners
			continue

		positions.append({
			"position": lamp_pos,
			"rotation": rotation
		})


## Create instanced lamps using MultiMeshInstance3D
static func _create_instanced_lamps(parent: Node3D, positions: Array) -> void:
	if positions.is_empty():
		return

	# Create the lamp mesh if not cached
	if _lamp_mesh == null:
		_lamp_mesh = _create_lamp_mesh()

	# Create MultiMesh
	var multi_mesh = MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.mesh = _lamp_mesh
	multi_mesh.instance_count = positions.size()

	# Set transforms for each lamp
	for i in range(positions.size()):
		var data = positions[i]
		var pos: Vector3 = data["position"]
		var rot: float = data["rotation"]

		var transform = Transform3D()
		transform = transform.rotated(Vector3.UP, rot)
		transform.origin = pos

		multi_mesh.set_instance_transform(i, transform)

	# Create MultiMeshInstance3D
	var mmi = MultiMeshInstance3D.new()
	mmi.name = "LampInstances"
	mmi.multimesh = multi_mesh
	parent.add_child(mmi)

	# Add actual lights for each lamp (can't be instanced)
	_add_lamp_lights(parent, positions)


## Add OmniLight3D for each lamp position
static func _add_lamp_lights(parent: Node3D, positions: Array) -> void:
	var lights_container = Node3D.new()
	lights_container.name = "LampLights"
	parent.add_child(lights_container)

	for i in range(positions.size()):
		var data = positions[i]
		var pos: Vector3 = data["position"]

		var light = OmniLight3D.new()
		light.name = "LampLight_%d" % i
		# Position light at lamp housing height
		light.position = pos + Vector3(0.4, LAMP_HEIGHT - 0.3, 0)  # Offset for arm
		light.light_color = Color(1.0, 0.95, 0.8)  # Warm white
		light.light_energy = 1.5
		light.omni_range = 12.0
		light.omni_attenuation = 1.2
		light.shadow_enabled = false  # Too many lamps for shadows
		lights_container.add_child(light)


## Create the combined lamp mesh (pole + housing)
static func _create_lamp_mesh() -> ArrayMesh:
	var mesh = ArrayMesh.new()

	# Pole parameters
	var pole_height = 4.5
	var pole_radius = 0.06
	var base_height = 0.3
	var base_radius = 0.15
	var arm_length = 0.8
	var segments = 6

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Decorative base
	_add_cylinder_to_st(st, Vector3.ZERO, base_radius, base_height, segments)

	# Main pole
	_add_cylinder_to_st(st, Vector3(0, base_height, 0), pole_radius, pole_height - base_height, segments)

	# Horizontal arm
	_add_horizontal_cylinder_to_st(st, Vector3(0, pole_height, 0), Vector3(arm_length, pole_height - 0.1, 0), pole_radius * 0.7, segments)

	st.generate_normals()
	var pole_mesh = st.commit()

	# Add pole surface to main mesh
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, pole_mesh.surface_get_arrays(0))

	# Set pole material
	if _pole_material == null:
		_pole_material = StandardMaterial3D.new()
		_pole_material.albedo_color = Color(0.15, 0.15, 0.15)  # Dark iron
		_pole_material.roughness = 0.6
		_pole_material.metallic = 0.5
	mesh.surface_set_material(0, _pole_material)

	# Create lamp housing
	var st2 = SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)

	var lamp_size = 0.35
	var lamp_height = 0.5
	var lamp_pos = Vector3(arm_length * 0.5, pole_height, 0)

	_add_lantern_to_st(st2, lamp_pos, lamp_size, lamp_height)

	st2.generate_normals()
	var housing_mesh = st2.commit()

	# Add housing surface
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, housing_mesh.surface_get_arrays(0))

	# Set housing material (emissive)
	if _housing_material == null:
		_housing_material = StandardMaterial3D.new()
		_housing_material.albedo_color = Color(0.9, 0.85, 0.7)
		_housing_material.roughness = 0.3
		_housing_material.emission_enabled = true
		_housing_material.emission = Color(1.0, 0.9, 0.7)
		_housing_material.emission_energy_multiplier = 2.0
	mesh.surface_set_material(1, _housing_material)

	return mesh


## Add a vertical cylinder to SurfaceTool
static func _add_cylinder_to_st(st: SurfaceTool, base: Vector3, radius: float, height: float, segments: int) -> void:
	for i in range(segments):
		var angle1 = TAU * i / segments
		var angle2 = TAU * (i + 1) / segments

		var x1 = cos(angle1) * radius
		var z1 = sin(angle1) * radius
		var x2 = cos(angle2) * radius
		var z2 = sin(angle2) * radius

		var v0 = base + Vector3(x1, 0, z1)
		var v1 = base + Vector3(x2, 0, z2)
		var v2 = base + Vector3(x2, height, z2)
		var v3 = base + Vector3(x1, height, z1)

		# Quad as two triangles
		st.add_vertex(v0)
		st.add_vertex(v1)
		st.add_vertex(v2)

		st.add_vertex(v0)
		st.add_vertex(v2)
		st.add_vertex(v3)


## Add a horizontal cylinder (tube) between two points
static func _add_horizontal_cylinder_to_st(st: SurfaceTool, start: Vector3, end: Vector3, radius: float, segments: int) -> void:
	var direction = (end - start).normalized()
	var right = direction.cross(Vector3.UP).normalized()
	if right.length() < 0.1:
		right = direction.cross(Vector3.RIGHT).normalized()
	var up = right.cross(direction).normalized()

	for i in range(segments):
		var angle1 = TAU * i / segments
		var angle2 = TAU * (i + 1) / segments

		var offset1 = (right * cos(angle1) + up * sin(angle1)) * radius
		var offset2 = (right * cos(angle2) + up * sin(angle2)) * radius

		var v0 = start + offset1
		var v1 = start + offset2
		var v2 = end + offset2
		var v3 = end + offset1

		st.add_vertex(v0)
		st.add_vertex(v1)
		st.add_vertex(v2)

		st.add_vertex(v0)
		st.add_vertex(v2)
		st.add_vertex(v3)


## Add lantern housing geometry
static func _add_lantern_to_st(st: SurfaceTool, pos: Vector3, size: float, height: float) -> void:
	var half_size = size / 2.0

	var corners_top = [
		pos + Vector3(-half_size, 0, -half_size),
		pos + Vector3(half_size, 0, -half_size),
		pos + Vector3(half_size, 0, half_size),
		pos + Vector3(-half_size, 0, half_size),
	]

	var corners_bottom = [
		pos + Vector3(-half_size * 0.7, -height, -half_size * 0.7),
		pos + Vector3(half_size * 0.7, -height, -half_size * 0.7),
		pos + Vector3(half_size * 0.7, -height, half_size * 0.7),
		pos + Vector3(-half_size * 0.7, -height, half_size * 0.7),
	]

	# Side faces
	for i in range(4):
		var next = (i + 1) % 4

		st.add_vertex(corners_top[i])
		st.add_vertex(corners_top[next])
		st.add_vertex(corners_bottom[next])

		st.add_vertex(corners_top[i])
		st.add_vertex(corners_bottom[next])
		st.add_vertex(corners_bottom[i])

	# Bottom cap
	st.add_vertex(corners_bottom[0])
	st.add_vertex(corners_bottom[1])
	st.add_vertex(corners_bottom[2])

	st.add_vertex(corners_bottom[0])
	st.add_vertex(corners_bottom[2])
	st.add_vertex(corners_bottom[3])


## Clear cached resources
static func clear_cache() -> void:
	_lamp_mesh = null
	_pole_material = null
	_housing_material = null
