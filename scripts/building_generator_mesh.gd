extends Node

## Mesh-Based Building Generator
## Creates realistic 3D buildings using proper mesh generation
##
## Features:
## - Real mesh geometry with vertices, normals, and UVs
## - Windows embedded into wall geometry
## - Proper material and texture support
## - Multiple roof shapes (flat, gabled, hipped, pyramidal)
## - Optimized for city-scale rendering
## - Full OSM data integration

class_name BuildingGeneratorMesh

## Material definitions with texture support
const MATERIALS = {
	"brick": {"color": Color(0.7, 0.4, 0.3), "roughness": 0.9, "texture_scale": 2.0},
	"concrete": {"color": Color(0.7, 0.7, 0.7), "roughness": 0.7, "texture_scale": 4.0},
	"glass": {"color": Color(0.8, 0.9, 1.0, 0.3), "roughness": 0.1, "metallic": 0.2},
	"metal": {"color": Color(0.6, 0.6, 0.65), "roughness": 0.3, "metallic": 0.8},
	"wood": {"color": Color(0.6, 0.4, 0.2), "roughness": 0.8, "texture_scale": 1.0},
	"stone": {"color": Color(0.65, 0.65, 0.6), "roughness": 0.85, "texture_scale": 3.0},
	"plaster": {"color": Color(0.9, 0.9, 0.85), "roughness": 0.6, "texture_scale": 5.0}
}

## Generate complete building from OSM data
static func create_building(osm_data: Dictionary, parent: Node3D, detailed: bool = true) -> Node3D:
	var building = Node3D.new()
	var building_name = osm_data.get("name", "")
	if building_name == "":
		building_name = "Building_" + str(osm_data.get("id", randi()))
	building.name = building_name

	# Extract data
	var footprint = osm_data.get("footprint", [])
	var center = osm_data.get("center", Vector2.ZERO)
	var height = osm_data.get("height", 6.0)
	var levels = osm_data.get("levels", 2)

	# Calculate elevation
	var layer = osm_data.get("layer", 0)
	var min_level = osm_data.get("min_level", 0)
	var base_elevation = (layer * 5.0) + (min_level * 3.0)

	# Create building mesh
	var building_mesh = _create_building_mesh(footprint, center, height, levels, osm_data, detailed)
	building_mesh.position.y = base_elevation
	building.add_child(building_mesh)

	# Add building label (ALWAYS, not just for named buildings)
	var label_text = ""
	if osm_data.get("name", "") != "":
		label_text = osm_data.get("name")
	else:
		var building_type = osm_data.get("building_type", "building")
		label_text = building_type.capitalize().replace("_", " ")

	# Add floor count and type to label
	var full_label = "BUILDING: " + label_text + "\n" + str(levels) + " floors, " + str(int(height)) + "m"
	_add_name_label(building, full_label, height, base_elevation)

	parent.add_child(building)

	# Debug output (disabled to reduce console spam)
	# var color_info = ""
	# if osm_data.get("building:colour", "") != "":
	# 	color_info = " (color: " + osm_data.get("building:colour") + ")"
	# print("  ✅ ", building.name, " - ", levels, " floors, ", height, "m", color_info)

	return building

## Create complete building mesh (walls + roof + windows)
static func _create_building_mesh(footprint: Array, center: Vector2, height: float, levels: int, osm_data: Dictionary, detailed: bool) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "BuildingMesh"

	var array_mesh = ArrayMesh.new()

	# Surface 0: Walls (opaque)
	var wall_vertices = PackedVector3Array()
	var wall_normals = PackedVector3Array()
	var wall_uvs = PackedVector2Array()
	var wall_indices = PackedInt32Array()

	# Surface 1: Windows (transparent glass)
	var window_vertices = PackedVector3Array()
	var window_normals = PackedVector3Array()
	var window_uvs = PackedVector2Array()
	var window_indices = PackedInt32Array()

	# Surface 2: Window frames (darker color)
	var frame_vertices = PackedVector3Array()
	var frame_normals = PackedVector3Array()
	var frame_uvs = PackedVector2Array()
	var frame_indices = PackedInt32Array()

	# Surface 3: Roof (separate material for colors/materials)
	var roof_vertices = PackedVector3Array()
	var roof_normals = PackedVector3Array()
	var roof_uvs = PackedVector2Array()
	var roof_indices = PackedInt32Array()

	# Generate walls with windows (now populates separate arrays)
	_generate_walls_multi_surface(footprint, center, height, levels, osm_data, detailed,
		wall_vertices, wall_normals, wall_uvs, wall_indices,
		window_vertices, window_normals, window_uvs, window_indices,
		frame_vertices, frame_normals, frame_uvs, frame_indices)

	# Generate roof (separate surface for OSM colors/materials)
	var roof_shape = osm_data.get("roof:shape", "flat")
	_generate_roof(footprint, center, height, roof_shape, osm_data, roof_vertices, roof_normals, roof_uvs, roof_indices)

	# Build surfaces and track actual indices (they shift based on what's added)
	var current_surface_index = 0
	var wall_surface_index = -1
	var window_surface_index = -1
	var frame_surface_index = -1
	var roof_surface_index = -1

	# Surface: Walls (always present)
	var wall_arrays = []
	wall_arrays.resize(Mesh.ARRAY_MAX)
	wall_arrays[Mesh.ARRAY_VERTEX] = wall_vertices
	wall_arrays[Mesh.ARRAY_NORMAL] = wall_normals
	wall_arrays[Mesh.ARRAY_TEX_UV] = wall_uvs
	wall_arrays[Mesh.ARRAY_INDEX] = wall_indices
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, wall_arrays)
	wall_surface_index = current_surface_index
	current_surface_index += 1

	# Surface: Windows (if any)
	if window_vertices.size() > 0:
		var window_arrays = []
		window_arrays.resize(Mesh.ARRAY_MAX)
		window_arrays[Mesh.ARRAY_VERTEX] = window_vertices
		window_arrays[Mesh.ARRAY_NORMAL] = window_normals
		window_arrays[Mesh.ARRAY_TEX_UV] = window_uvs
		window_arrays[Mesh.ARRAY_INDEX] = window_indices
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, window_arrays)
		window_surface_index = current_surface_index
		current_surface_index += 1

	# Surface: Frames (if any)
	if frame_vertices.size() > 0:
		var frame_arrays = []
		frame_arrays.resize(Mesh.ARRAY_MAX)
		frame_arrays[Mesh.ARRAY_VERTEX] = frame_vertices
		frame_arrays[Mesh.ARRAY_NORMAL] = frame_normals
		frame_arrays[Mesh.ARRAY_TEX_UV] = frame_uvs
		frame_arrays[Mesh.ARRAY_INDEX] = frame_indices
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, frame_arrays)
		frame_surface_index = current_surface_index
		current_surface_index += 1

	# Surface: Roof (if any)
	if roof_vertices.size() > 0:
		var roof_arrays = []
		roof_arrays.resize(Mesh.ARRAY_MAX)
		roof_arrays[Mesh.ARRAY_VERTEX] = roof_vertices
		roof_arrays[Mesh.ARRAY_NORMAL] = roof_normals
		roof_arrays[Mesh.ARRAY_TEX_UV] = roof_uvs
		roof_arrays[Mesh.ARRAY_INDEX] = roof_indices
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, roof_arrays)
		roof_surface_index = current_surface_index
		current_surface_index += 1

	mesh_instance.mesh = array_mesh

	# Apply materials to each surface using tracked indices
	if wall_surface_index >= 0:
		mesh_instance.set_surface_override_material(wall_surface_index, _create_building_material(osm_data))
	if window_surface_index >= 0:
		mesh_instance.set_surface_override_material(window_surface_index, _create_window_material())
	if frame_surface_index >= 0:
		mesh_instance.set_surface_override_material(frame_surface_index, _create_frame_material())
	if roof_surface_index >= 0:
		mesh_instance.set_surface_override_material(roof_surface_index, _create_roof_material(osm_data))

	return mesh_instance

## Generate wall geometry with window openings (multi-surface version)
static func _generate_walls_multi_surface(footprint: Array, center: Vector2, height: float, levels: int, osm_data: Dictionary, detailed: bool,
	wall_vertices: PackedVector3Array, wall_normals: PackedVector3Array, wall_uvs: PackedVector2Array, wall_indices: PackedInt32Array,
	window_vertices: PackedVector3Array, window_normals: PackedVector3Array, window_uvs: PackedVector2Array, window_indices: PackedInt32Array,
	frame_vertices: PackedVector3Array, frame_normals: PackedVector3Array, frame_uvs: PackedVector2Array, frame_indices: PackedInt32Array):

	if footprint.size() < 3:
		return

	# Calculate window parameters
	var floor_height = height / float(levels) if levels > 0 else height
	var window_params = _get_window_parameters(osm_data.get("building_type", "yes"))

	# Generate each wall segment
	for i in range(footprint.size()):
		var p1 = footprint[i] - center
		var p2 = footprint[(i + 1) % footprint.size()] - center

		# Create wall segment with windows (outputs to separate surfaces)
		_create_wall_segment_multi_surface(p1, p2, height, floor_height, levels, window_params, detailed,
			wall_vertices, wall_normals, wall_uvs, wall_indices,
			window_vertices, window_normals, window_uvs, window_indices,
			frame_vertices, frame_normals, frame_uvs, frame_indices)

## Create a single wall segment with window openings (multi-surface version)
static func _create_wall_segment_multi_surface(p1: Vector2, p2: Vector2, height: float, floor_height: float, levels: int, window_params: Dictionary, detailed: bool,
	wall_vertices: PackedVector3Array, wall_normals: PackedVector3Array, wall_uvs: PackedVector2Array, wall_indices: PackedInt32Array,
	window_vertices: PackedVector3Array, window_normals: PackedVector3Array, window_uvs: PackedVector2Array, window_indices: PackedInt32Array,
	frame_vertices: PackedVector3Array, frame_normals: PackedVector3Array, frame_uvs: PackedVector2Array, frame_indices: PackedInt32Array):

	var wall_length = p1.distance_to(p2)
	var wall_dir = (p2 - p1).normalized()
	var wall_normal = Vector3(-wall_dir.y, 0, wall_dir.x)

	# Calculate window placement
	var windows_per_floor = []
	if detailed and levels > 0:
		var num_windows = max(0, int(wall_length / window_params.spacing))
		for w in range(num_windows):
			var t = (w + 0.5) / float(num_windows) if num_windows > 0 else 0.5
			windows_per_floor.append({
				"position": t,
				"width": window_params.width,
				"height": window_params.height
			})

	if windows_per_floor.is_empty() or not detailed:
		# Simple wall without windows
		var base_index = wall_vertices.size()
		_add_wall_quad(p1, p2, 0.0, height, wall_normal, wall_vertices, wall_normals, wall_uvs, wall_indices, base_index)
	else:
		# Complex wall with window cutouts
		for floor_num in range(levels):
			var floor_bottom = floor_num * floor_height
			var floor_top = (floor_num + 1) * floor_height

			# Create wall segments around windows (multi-surface)
			_create_wall_with_windows_multi_surface(p1, p2, floor_bottom, floor_top, windows_per_floor, wall_normal, wall_length,
				wall_vertices, wall_normals, wall_uvs, wall_indices,
				window_vertices, window_normals, window_uvs, window_indices,
				frame_vertices, frame_normals, frame_uvs, frame_indices)

## Create a single wall segment with window openings (old single-surface version - unused)
static func _create_wall_segment(p1: Vector2, p2: Vector2, height: float, floor_height: float, levels: int, window_params: Dictionary, detailed: bool, vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array):
	var wall_length = p1.distance_to(p2)
	var wall_dir = (p2 - p1).normalized()
	var wall_normal = Vector3(-wall_dir.y, 0, wall_dir.x)  # Perpendicular to wall, pointing outward

	# Calculate window placement
	var windows_per_floor = []
	if detailed and levels > 0:
		var num_windows = max(0, int(wall_length / window_params.spacing))
		for w in range(num_windows):
			var t = (w + 0.5) / float(num_windows) if num_windows > 0 else 0.5
			windows_per_floor.append({
				"position": t,
				"width": window_params.width,
				"height": window_params.height
			})

	# Generate wall with window cutouts
	var base_index = vertices.size()

	if windows_per_floor.is_empty() or not detailed:
		# Simple wall without windows
		_add_wall_quad(p1, p2, 0.0, height, wall_normal, vertices, normals, uvs, indices, base_index)
	else:
		# Complex wall with window cutouts
		for floor_num in range(levels):
			var floor_bottom = floor_num * floor_height
			var floor_top = (floor_num + 1) * floor_height

			# Create wall segments around windows
			_create_wall_with_windows(p1, p2, floor_bottom, floor_top, windows_per_floor, wall_normal, wall_length, vertices, normals, uvs, indices)

## Create wall quad with windows cut out (multi-surface version)
static func _create_wall_with_windows_multi_surface(p1: Vector2, p2: Vector2, floor_bottom: float, floor_top: float, windows: Array, wall_normal: Vector3, wall_length: float,
	wall_vertices: PackedVector3Array, wall_normals: PackedVector3Array, wall_uvs: PackedVector2Array, wall_indices: PackedInt32Array,
	window_vertices: PackedVector3Array, window_normals: PackedVector3Array, window_uvs: PackedVector2Array, window_indices: PackedInt32Array,
	frame_vertices: PackedVector3Array, frame_normals: PackedVector3Array, frame_uvs: PackedVector2Array, frame_indices: PackedInt32Array):

	if windows.is_empty():
		# No windows - create full wall
		var base_index = wall_vertices.size()
		_add_wall_quad(p1, p2, floor_bottom, floor_top, wall_normal, wall_vertices, wall_normals, wall_uvs, wall_indices, base_index)
		return

	var floor_height = floor_top - floor_bottom
	var window_vertical_offset = floor_height * 0.15
	var window_bottom = floor_bottom + window_vertical_offset

	var prev_end_t = 0.0

	for window_idx in range(windows.size()):
		var window = windows[window_idx]
		var window_center_t = window.position
		var window_half_width = window.width / 2.0

		var window_left_t = clamp(window_center_t - (window_half_width / wall_length), 0.0, 1.0)
		var window_right_t = clamp(window_center_t + (window_half_width / wall_length), 0.0, 1.0)
		var window_top = min(floor_top, window_bottom + window.height)

		# ALWAYS create wall segment to the left of window (from previous window or wall start)
		if window_left_t > prev_end_t + 0.01:
			var seg_p1 = p1.lerp(p2, prev_end_t)
			var seg_p2 = p1.lerp(p2, window_left_t)
			var base_index = wall_vertices.size()
			_add_wall_quad(seg_p1, seg_p2, floor_bottom, floor_top, wall_normal, wall_vertices, wall_normals, wall_uvs, wall_indices, base_index)

		# Wall segment above window
		if window_top < floor_top - 0.01:
			var seg_p1 = p1.lerp(p2, window_left_t)
			var seg_p2 = p1.lerp(p2, window_right_t)
			var base_index = wall_vertices.size()
			_add_wall_quad(seg_p1, seg_p2, window_top, floor_top, wall_normal, wall_vertices, wall_normals, wall_uvs, wall_indices, base_index)

		# Wall segment below window
		if window_bottom > floor_bottom + 0.01:
			var seg_p1 = p1.lerp(p2, window_left_t)
			var seg_p2 = p1.lerp(p2, window_right_t)
			var base_index = wall_vertices.size()
			_add_wall_quad(seg_p1, seg_p2, floor_bottom, window_bottom, wall_normal, wall_vertices, wall_normals, wall_uvs, wall_indices, base_index)

		# Add window glass (goes to window surface)
		var window_base = window_vertices.size()
		_add_window_glass_multi(p1, p2, window_left_t, window_right_t, window_bottom, window_top, wall_normal, window_vertices, window_normals, window_uvs, window_indices, window_base)

		# Add window frame (goes to frame surface)
		_add_window_frame_multi(p1, p2, window_left_t, window_right_t, window_bottom, window_top, wall_normal, frame_vertices, frame_normals, frame_uvs, frame_indices)

		# Update prev_end_t for next window
		prev_end_t = window_right_t

	# ALWAYS create wall segment from last window to end of wall
	if prev_end_t < 0.99:
		var seg_p1 = p1.lerp(p2, prev_end_t)
		var seg_p2 = p2
		var base_index = wall_vertices.size()
		_add_wall_quad(seg_p1, seg_p2, floor_bottom, floor_top, wall_normal, wall_vertices, wall_normals, wall_uvs, wall_indices, base_index)

## Create wall quad with windows cut out (old single-surface version - unused)
static func _create_wall_with_windows(p1: Vector2, p2: Vector2, floor_bottom: float, floor_top: float, windows: Array, wall_normal: Vector3, wall_length: float, vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array):
	var floor_height = floor_top - floor_bottom
	var window_vertical_offset = floor_height * 0.15  # Windows start 15% up from floor
	var window_bottom = floor_bottom + window_vertical_offset

	# For each window, create wall segments around it
	for window_idx in range(windows.size()):
		var window = windows[window_idx]
		var window_center_t = window.position
		var window_half_width = window.width / 2.0

		# Calculate window horizontal position on wall
		var window_left_t = max(0.0, window_center_t - (window_half_width / wall_length))
		var window_right_t = min(1.0, window_center_t + (window_half_width / wall_length))
		var window_top = min(floor_top, window_bottom + window.height)

		# Get previous segment end (or wall start)
		var prev_end_t = 0.0
		if window_idx > 0:
			var prev_window = windows[window_idx - 1]
			prev_end_t = prev_window.position + ((prev_window.width / 2.0) / wall_length)

		# Wall segment to the left of window
		if window_left_t > prev_end_t + 0.01:  # Small threshold to avoid tiny segments
			var seg_p1 = p1.lerp(p2, prev_end_t)
			var seg_p2 = p1.lerp(p2, window_left_t)
			var base_index = vertices.size()
			_add_wall_quad(seg_p1, seg_p2, floor_bottom, floor_top, wall_normal, vertices, normals, uvs, indices, base_index)

		# Wall segment above window
		if window_top < floor_top - 0.01:
			var seg_p1 = p1.lerp(p2, window_left_t)
			var seg_p2 = p1.lerp(p2, window_right_t)
			var base_index = vertices.size()
			_add_wall_quad(seg_p1, seg_p2, window_top, floor_top, wall_normal, vertices, normals, uvs, indices, base_index)

		# Wall segment below window
		if window_bottom > floor_bottom + 0.01:
			var seg_p1 = p1.lerp(p2, window_left_t)
			var seg_p2 = p1.lerp(p2, window_right_t)
			var base_index = vertices.size()
			_add_wall_quad(seg_p1, seg_p2, floor_bottom, window_bottom, wall_normal, vertices, normals, uvs, indices, base_index)

		# Add window glass
		_add_window_glass(p1, p2, window_left_t, window_right_t, window_bottom, window_top, wall_normal, vertices, normals, uvs, indices)

		# Add window frame
		_add_window_frame(p1, p2, window_left_t, window_right_t, window_bottom, window_top, wall_normal, vertices, normals, uvs, indices)

		# Last window - add wall segment to the right
		if window_idx == windows.size() - 1 and window_right_t < 0.99:
			var seg_p1 = p1.lerp(p2, window_right_t)
			var seg_p2 = p2
			var base_index = vertices.size()
			_add_wall_quad(seg_p1, seg_p2, floor_bottom, floor_top, wall_normal, vertices, normals, uvs, indices, base_index)

## Add a simple wall quad
static func _add_wall_quad(p1: Vector2, p2: Vector2, y_bottom: float, y_top: float, normal: Vector3, vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, base_index: int):
	# Four corners of the wall quad
	var v1 = Vector3(p1.x, y_bottom, -p1.y)
	var v2 = Vector3(p2.x, y_bottom, -p2.y)
	var v3 = Vector3(p2.x, y_top, -p2.y)
	var v4 = Vector3(p1.x, y_top, -p1.y)

	vertices.append(v1)
	vertices.append(v2)
	vertices.append(v3)
	vertices.append(v4)

	# Normals (all pointing outward)
	for i in range(4):
		normals.append(normal)

	# UVs (simple planar mapping)
	var wall_width = p1.distance_to(p2)
	var wall_height = y_top - y_bottom
	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(wall_width, 0))
	uvs.append(Vector2(wall_width, wall_height))
	uvs.append(Vector2(0, wall_height))

	# Indices (two triangles)
	indices.append(base_index + 0)
	indices.append(base_index + 1)
	indices.append(base_index + 2)

	indices.append(base_index + 0)
	indices.append(base_index + 2)
	indices.append(base_index + 3)

## Add window glass quad (multi-surface version)
static func _add_window_glass_multi(p1: Vector2, p2: Vector2, t1: float, t2: float, y_bottom: float, y_top: float, normal: Vector3, vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, base_index: int):
	var window_p1 = p1.lerp(p2, t1)
	var window_p2 = p1.lerp(p2, t2)

	# Offset slightly forward from wall (0.05m)
	var offset = Vector3(normal.x * 0.05, 0, normal.z * 0.05)

	var v1 = Vector3(window_p1.x, y_bottom, -window_p1.y) + offset
	var v2 = Vector3(window_p2.x, y_bottom, -window_p2.y) + offset
	var v3 = Vector3(window_p2.x, y_top, -window_p2.y) + offset
	var v4 = Vector3(window_p1.x, y_top, -window_p1.y) + offset

	vertices.append(v1)
	vertices.append(v2)
	vertices.append(v3)
	vertices.append(v4)

	for i in range(4):
		normals.append(normal)

	# Simple UVs for glass
	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(1, 0))
	uvs.append(Vector2(1, 1))
	uvs.append(Vector2(0, 1))

	indices.append(base_index + 0)
	indices.append(base_index + 1)
	indices.append(base_index + 2)

	indices.append(base_index + 0)
	indices.append(base_index + 2)
	indices.append(base_index + 3)

## Add window glass quad (old single-surface version - unused)
static func _add_window_glass(p1: Vector2, p2: Vector2, t1: float, t2: float, y_bottom: float, y_top: float, normal: Vector3, vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array):
	var base_index = vertices.size()
	_add_window_glass_multi(p1, p2, t1, t2, y_bottom, y_top, normal, vertices, normals, uvs, indices, base_index)

## Add window frame around window opening (multi-surface version)
static func _add_window_frame_multi(p1: Vector2, p2: Vector2, t1: float, t2: float, y_bottom: float, y_top: float, normal: Vector3, vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array):
	var window_p1 = p1.lerp(p2, t1)
	var window_p2 = p1.lerp(p2, t2)
	var window_width = window_p1.distance_to(window_p2)

	var frame_thickness = 0.08  # 8cm frame thickness
	var frame_depth = 0.1  # 10cm depth into wall

	# Get tangent vector along wall
	var wall_tangent = (window_p2 - window_p1).normalized()
	var tangent_3d = Vector3(wall_tangent.x, 0, -wall_tangent.y)

	# Left frame (vertical)
	_add_frame_piece(window_p1, window_p1, y_bottom, y_top, frame_thickness, frame_depth, normal, tangent_3d, true, vertices, normals, uvs, indices)

	# Right frame (vertical)
	var right_offset = wall_tangent * (window_width - frame_thickness)
	var right_p1 = window_p1 + right_offset
	_add_frame_piece(right_p1, right_p1, y_bottom, y_top, frame_thickness, frame_depth, normal, tangent_3d, true, vertices, normals, uvs, indices)

	# Top frame (horizontal)
	_add_frame_piece(window_p1, window_p2, y_top - frame_thickness, y_top, window_width, frame_depth, normal, tangent_3d, false, vertices, normals, uvs, indices)

	# Bottom frame (horizontal)
	_add_frame_piece(window_p1, window_p2, y_bottom, y_bottom + frame_thickness, window_width, frame_depth, normal, tangent_3d, false, vertices, normals, uvs, indices)

## Add window frame around window opening (old single-surface version - unused)
static func _add_window_frame(p1: Vector2, p2: Vector2, t1: float, t2: float, y_bottom: float, y_top: float, normal: Vector3, vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array):
	_add_window_frame_multi(p1, p2, t1, t2, y_bottom, y_top, normal, vertices, normals, uvs, indices)

## Add a single piece of window frame
static func _add_frame_piece(p1: Vector2, p2: Vector2, y_bottom: float, y_top: float, width: float, _depth: float, normal: Vector3, tangent: Vector3, is_vertical: bool, vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array):
	# Simple frame quad at wall surface level
	var offset = Vector3(normal.x * 0.02, 0, normal.z * 0.02)  # Slightly recessed

	var base_index = vertices.size()
	var v1 = Vector3(p1.x, y_bottom, -p1.y) + offset
	var v2: Vector3
	if is_vertical:
		v2 = Vector3(p1.x, y_bottom, -p1.y) + offset + tangent * width
	else:
		v2 = Vector3(p2.x, y_bottom, -p2.y) + offset
	var v3 = v2 + Vector3(0, y_top - y_bottom, 0)
	var v4 = v1 + Vector3(0, y_top - y_bottom, 0)

	vertices.append(v1)
	vertices.append(v2)
	vertices.append(v3)
	vertices.append(v4)

	for i in range(4):
		normals.append(normal)

	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(1, 0))
	uvs.append(Vector2(1, 1))
	uvs.append(Vector2(0, 1))

	indices.append(base_index + 0)
	indices.append(base_index + 1)
	indices.append(base_index + 2)

	indices.append(base_index + 0)
	indices.append(base_index + 2)
	indices.append(base_index + 3)

## Generate roof geometry
static func _generate_roof(footprint: Array, center: Vector2, building_height: float, roof_shape: String, osm_data: Dictionary, vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array):
	match roof_shape:
		"flat", "":
			_generate_flat_roof(footprint, center, building_height, vertices, normals, uvs, indices)
		"gabled":
			_generate_gabled_roof(footprint, center, building_height, osm_data, vertices, normals, uvs, indices)
		"hipped":
			_generate_hipped_roof(footprint, center, building_height, osm_data, vertices, normals, uvs, indices)
		"pyramidal":
			_generate_pyramidal_roof(footprint, center, building_height, osm_data, vertices, normals, uvs, indices)
		_:
			# Fallback to flat
			_generate_flat_roof(footprint, center, building_height, vertices, normals, uvs, indices)

## Generate flat roof
static func _generate_flat_roof(footprint: Array, center: Vector2, building_height: float, vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array):
	if footprint.size() < 3:
		return

	var roof_y = building_height
	var base_index = vertices.size()

	# Convert footprint to local coordinates
	var local_polygon = []
	for point in footprint:
		local_polygon.append(point - center)

	# Use Godot's built-in triangulation (handles concave footprints correctly)
	var roof_indices = PolygonTriangulator.triangulate(local_polygon)

	# Add roof vertices
	for point in local_polygon:
		vertices.append(Vector3(point.x, roof_y, -point.y))
		normals.append(Vector3.UP)
		uvs.append(Vector2(point.x, point.y))

	# Add triangulated indices (offset by base_index)
	for idx in roof_indices:
		indices.append(base_index + idx)

## Generate gabled roof (peaked roof with two sloped sides)
static func _generate_gabled_roof(footprint: Array, center: Vector2, building_height: float, osm_data: Dictionary, vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array):
	if footprint.size() < 3:
		return

	# Get roof parameters from OSM data
	var roof_height = _get_roof_height(building_height, osm_data)
	var ridge_height = building_height + roof_height

	# Calculate building bounding box to determine ridge orientation
	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF

	for point in footprint:
		min_x = min(min_x, point.x)
		max_x = max(max_x, point.x)
		min_y = min(min_y, point.y)
		max_y = max(max_y, point.y)

	var width = max_x - min_x
	var depth = max_y - min_y

	# Determine ridge direction (along longer dimension by default)
	# roof:orientation from OSM can override this
	var ridge_along_x = width > depth
	var orientation = osm_data.get("roof:orientation", "")
	if orientation == "along" or orientation == "across":
		ridge_along_x = (orientation == "along")

	# Create ridge line
	var ridge_start: Vector2
	var ridge_end: Vector2

	if ridge_along_x:
		# Ridge runs along X axis
		ridge_start = Vector2(min_x, (min_y + max_y) / 2) - center
		ridge_end = Vector2(max_x, (min_y + max_y) / 2) - center
	else:
		# Ridge runs along Y axis
		ridge_start = Vector2((min_x + max_x) / 2, min_y) - center
		ridge_end = Vector2((min_x + max_x) / 2, max_y) - center

	# Create roof geometry
	# Add ridge vertices
	vertices.append(Vector3(ridge_start.x, ridge_height, -ridge_start.y))
	vertices.append(Vector3(ridge_end.x, ridge_height, -ridge_end.y))
	normals.append(Vector3.UP)
	normals.append(Vector3.UP)
	uvs.append(Vector2(0, 0.5))
	uvs.append(Vector2(1, 0.5))

	# Create triangular faces from ridge to building edges
	for i in range(footprint.size()):
		var p1 = footprint[i] - center
		var p2 = footprint[(i + 1) % footprint.size()] - center

		var v1 = Vector3(p1.x, building_height, -p1.y)
		var v2 = Vector3(p2.x, building_height, -p2.y)

		# Determine which ridge point to connect to (closest one)
		var ridge_v1 = Vector3(ridge_start.x, ridge_height, -ridge_start.y)
		var ridge_v2 = Vector3(ridge_end.x, ridge_height, -ridge_end.y)
		var mid_point = (v1 + v2) / 2

		var use_start = mid_point.distance_to(ridge_v1) < mid_point.distance_to(ridge_v2)
		var ridge_point = ridge_v1 if use_start else ridge_v2

		# Create quad (two triangles) from edge to ridge
		var face_base = vertices.size()
		var edge1 = ridge_point - v1
		var edge2 = v2 - v1
		var face_normal = edge1.cross(edge2).normalized()

		# Quad vertices
		vertices.append(v1)
		vertices.append(v2)
		vertices.append(ridge_point)

		normals.append(face_normal)
		normals.append(face_normal)
		normals.append(face_normal)

		uvs.append(Vector2(0, 0))
		uvs.append(Vector2(1, 0))
		uvs.append(Vector2(0.5, 1))

		# Triangle
		indices.append(face_base + 0)
		indices.append(face_base + 1)
		indices.append(face_base + 2)

## Generate hipped roof (all sides slope inward)
static func _generate_hipped_roof(footprint: Array, center: Vector2, building_height: float, osm_data: Dictionary, vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array):
	if footprint.size() < 3:
		return

	# Get roof parameters from OSM data
	var roof_height = _get_roof_height(building_height, osm_data)
	var peak_height = building_height + roof_height

	# Calculate inset polygon (hipped roofs have a flat top polygon)
	# Inset by 20% of building dimensions
	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF

	for point in footprint:
		min_x = min(min_x, point.x)
		max_x = max(max_x, point.x)
		min_y = min(min_y, point.y)
		max_y = max(max_y, point.y)

	var width = max_x - min_x
	var depth = max_y - min_y
	var inset_amount = min(width, depth) * 0.2

	# Create inset polygon at peak
	var inset_polygon: Array = []
	var building_center_local = Vector2((max_x + min_x) / 2, (max_y + min_y) / 2) - center

	for point in footprint:
		var local_point = point - center
		var direction = (local_point - building_center_local).normalized()
		var inset_point = local_point - direction * inset_amount
		inset_polygon.append(inset_point)

	# Create top flat surface
	var base_index = vertices.size()
	for point in inset_polygon:
		vertices.append(Vector3(point.x, peak_height, -point.y))
		normals.append(Vector3.UP)
		uvs.append(Vector2(point.x, point.y))

	# Triangulate top surface
	for i in range(1, inset_polygon.size() - 1):
		indices.append(base_index + 0)
		indices.append(base_index + i)
		indices.append(base_index + i + 1)

	# Create sloped sides connecting base to inset polygon
	for i in range(footprint.size()):
		var next_i = (i + 1) % footprint.size()
		var base_p1 = footprint[i] - center
		var base_p2 = footprint[next_i] - center
		var top_p1 = inset_polygon[i]
		var top_p2 = inset_polygon[next_i]

		var v1 = Vector3(base_p1.x, building_height, -base_p1.y)
		var v2 = Vector3(base_p2.x, building_height, -base_p2.y)
		var v3 = Vector3(top_p2.x, peak_height, -top_p2.y)
		var v4 = Vector3(top_p1.x, peak_height, -top_p1.y)

		# Calculate normal for this face
		var edge1 = v2 - v1
		var edge2 = v4 - v1
		var face_normal = edge1.cross(edge2).normalized()

		# Create quad as two triangles
		var face_base = vertices.size()

		vertices.append(v1)
		vertices.append(v2)
		vertices.append(v3)
		vertices.append(v4)

		normals.append(face_normal)
		normals.append(face_normal)
		normals.append(face_normal)
		normals.append(face_normal)

		uvs.append(Vector2(0, 0))
		uvs.append(Vector2(1, 0))
		uvs.append(Vector2(1, 1))
		uvs.append(Vector2(0, 1))

		# First triangle
		indices.append(face_base + 0)
		indices.append(face_base + 1)
		indices.append(face_base + 2)

		# Second triangle
		indices.append(face_base + 0)
		indices.append(face_base + 2)
		indices.append(face_base + 3)

## Generate pyramidal roof (all sides meet at center point)
static func _generate_pyramidal_roof(footprint: Array, center: Vector2, building_height: float, osm_data: Dictionary, vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array):
	if footprint.size() < 3:
		return

	# Get roof parameters from OSM data
	var roof_height_delta = _get_roof_height(building_height, osm_data)
	var apex_height = building_height + roof_height_delta
	var apex = Vector3(0, apex_height, 0)

	# Add apex
	vertices.append(apex)
	normals.append(Vector3.UP)
	uvs.append(Vector2(0.5, 0.5))

	# Add base vertices and create triangular faces
	for i in range(footprint.size()):
		var p1 = footprint[i] - center
		var p2 = footprint[(i + 1) % footprint.size()] - center

		var v1 = Vector3(p1.x, building_height, -p1.y)
		var v2 = Vector3(p2.x, building_height, -p2.y)

		# Calculate normal for this face
		var edge1 = v1 - apex
		var edge2 = v2 - apex
		var face_normal = edge1.cross(edge2).normalized()

		var face_base = vertices.size()
		vertices.append(apex)
		vertices.append(v1)
		vertices.append(v2)

		normals.append(face_normal)
		normals.append(face_normal)
		normals.append(face_normal)

		uvs.append(Vector2(0.5, 1))
		uvs.append(Vector2(0, 0))
		uvs.append(Vector2(1, 0))

		indices.append(face_base + 0)
		indices.append(face_base + 1)
		indices.append(face_base + 2)

## Get roof height from OSM data with intelligent fallbacks
static func _get_roof_height(building_height: float, osm_data: Dictionary) -> float:
	# Priority 1: Explicit roof:height from OSM (in meters)
	var roof_height_osm = osm_data.get("roof:height", 0.0)
	if roof_height_osm > 0:
		return roof_height_osm

	# Priority 2: Calculate from roof:angle and building dimensions
	var roof_angle = osm_data.get("roof:angle", 0.0)
	if roof_angle > 0:
		# Get building dimensions to calculate rise from angle
		var footprint = osm_data.get("footprint", [])
		if footprint.size() >= 3:
			var min_x = INF
			var max_x = -INF
			var min_y = INF
			var max_y = -INF

			for point in footprint:
				min_x = min(min_x, point.x)
				max_x = max(max_x, point.x)
				min_y = min(min_y, point.y)
				max_y = max(max_y, point.y)

			var width = max_x - min_x
			var depth = max_y - min_y
			var half_span = min(width, depth) / 2.0

			# Calculate height from angle: tan(angle) = height / half_span
			# roof:angle is typically in degrees
			var angle_rad = deg_to_rad(roof_angle)
			return tan(angle_rad) * half_span

	# Priority 3: Use roof:levels if available (3m per roof level)
	var roof_levels = osm_data.get("roof:levels", 0)
	if roof_levels > 0:
		return roof_levels * 3.0

	# Fallback: 15% of building height (default)
	return building_height * 0.15

## Get window parameters based on building type
static func _get_window_parameters(building_type: String) -> Dictionary:
	match building_type:
		"commercial", "office", "retail":
			return {"spacing": 2.5, "width": 2.0, "height": 2.5}
		"residential", "apartments", "house":
			return {"spacing": 3.5, "width": 1.2, "height": 1.8}
		"industrial", "warehouse":
			return {"spacing": 5.0, "width": 1.0, "height": 1.5}
		_:
			return {"spacing": 3.0, "width": 1.5, "height": 2.0}

## Create building material from OSM data
static func _create_building_material(osm_data: Dictionary) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()

	# Priority 1: Use OSM building:colour if available
	var osm_color = osm_data.get("building:colour", "")
	if osm_color != "":
		var color = _parse_osm_color(osm_color)
		if color != Color.TRANSPARENT:
			material.albedo_color = color
			material.roughness = 0.7
			return material

	# Priority 2: Use material type
	var material_type = osm_data.get("building:material", osm_data.get("building:cladding", "")).to_lower()
	if MATERIALS.has(material_type):
		var mat_def = MATERIALS[material_type]
		material.albedo_color = mat_def["color"]
		material.roughness = mat_def.get("roughness", 0.7)
		if mat_def.has("metallic"):
			material.metallic = mat_def["metallic"]
		if mat_def.has("color") and mat_def["color"].a < 1.0:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		return material

	# Priority 3: Use building type defaults
	var building_type = osm_data.get("building_type", "yes")
	match building_type:
		"commercial", "office", "retail":
			material.albedo_color = Color(0.85, 0.85, 0.9)
		"residential", "apartments", "house":
			material.albedo_color = Color(0.9, 0.85, 0.75)
		"industrial", "warehouse":
			material.albedo_color = Color(0.6, 0.6, 0.65)
		"civic", "public", "government":
			material.albedo_color = Color(0.8, 0.75, 0.7)
		"historic", "heritage":
			material.albedo_color = Color(0.7, 0.4, 0.3)
		_:
			material.albedo_color = Color(0.8, 0.8, 0.8)

	material.roughness = 0.7
	return material

## Parse OSM color (hex or named)
static func _parse_osm_color(color_string: String) -> Color:
	if color_string == "" or color_string == "yes":
		return Color.TRANSPARENT

	# Hex colors like "#e8ead4"
	if color_string.begins_with("#"):
		return Color.html(color_string)

	# Try HTML/CSS color name (Godot supports many CSS colors)
	var html_color = Color.from_string(color_string, Color.TRANSPARENT)
	if html_color != Color.TRANSPARENT:
		return html_color

	# Fallback named colors
	match color_string.to_lower():
		"red": return Color.RED
		"blue": return Color.BLUE
		"green": return Color.GREEN
		"white": return Color.WHITE
		"gray", "grey": return Color.GRAY
		"brown": return Color(0.6, 0.4, 0.2)
		"tan": return Color(0.8, 0.7, 0.5)
		"yellow": return Color.YELLOW
		"orange": return Color.ORANGE
		_: return Color.TRANSPARENT

## Create roof material from OSM data (separate from walls)
static func _create_roof_material(osm_data: Dictionary) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()

	# Priority 1: Use OSM roof:colour if available
	var roof_color = osm_data.get("roof:colour", "")
	if roof_color != "":
		var color = _parse_osm_color(roof_color)
		if color != Color.TRANSPARENT:
			material.albedo_color = color
			material.roughness = 0.7
			return material

	# Priority 2: Use roof:material type with presets
	var roof_material_type = osm_data.get("roof:material", "").to_lower()
	match roof_material_type:
		"tiles", "tile":
			material.albedo_color = Color(0.6, 0.3, 0.2)  # Terracotta/clay tiles
			material.roughness = 0.7
			return material
		"metal", "steel":
			material.albedo_color = Color(0.4, 0.4, 0.45)
			material.metallic = 0.8
			material.roughness = 0.3
			return material
		"slate":
			material.albedo_color = Color(0.25, 0.25, 0.3)  # Dark gray slate
			material.roughness = 0.6
			return material
		"concrete":
			material.albedo_color = Color(0.5, 0.5, 0.5)
			material.roughness = 0.8
			return material
		"shingles", "asphalt":
			material.albedo_color = Color(0.3, 0.3, 0.35)  # Dark asphalt shingles
			material.roughness = 0.9
			return material
		"glass":
			material.albedo_color = Color(0.7, 0.8, 0.9, 0.5)
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.roughness = 0.1
			material.metallic = 0.2
			return material
		"copper":
			material.albedo_color = Color(0.3, 0.6, 0.4)  # Green patina copper
			material.metallic = 0.7
			material.roughness = 0.4
			return material
		"tar_paper", "gravel":
			material.albedo_color = Color(0.2, 0.2, 0.2)  # Dark flat roof
			material.roughness = 1.0
			return material

	# Priority 3: Fallback based on roof shape
	var roof_shape = osm_data.get("roof:shape", "flat")
	match roof_shape:
		"flat":
			# Flat roofs are often tar/gravel
			material.albedo_color = Color(0.25, 0.25, 0.25)
			material.roughness = 0.9
		"gabled", "hipped", "pyramidal":
			# Sloped roofs typically have shingles or tiles
			material.albedo_color = Color(0.4, 0.25, 0.2)  # Red-brown tiles
			material.roughness = 0.7
		_:
			# Default gray roof
			material.albedo_color = Color(0.4, 0.4, 0.4)
			material.roughness = 0.7

	return material

## Create window glass material (transparent blue)
static func _create_window_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.6, 0.7, 0.9, 0.4)  # Light blue glass with transparency
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.metallic = 0.1
	material.roughness = 0.1
	material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Visible from both sides
	return material

## Create window frame material (dark, contrasting)
static func _create_frame_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.2, 0.2)  # Dark gray/black frames
	material.roughness = 0.6
	material.metallic = 0.1
	return material

## Add name label to building
static func _add_name_label(building: Node3D, building_name: String, height: float, base_elevation: float):
	var label = Label3D.new()
	label.name = "BuildingLabel"  # Name it so we can find it later for culling
	label.text = building_name
	label.position = Vector3(0, height + base_elevation + 10, 0)  # 10m above building
	label.font_size = 256  # HUGE for maximum visibility
	label.outline_size = 24  # Very thick outline
	label.modulate = Color(1, 0, 0)  # Bright red
	label.outline_modulate = Color(0, 0, 0)  # Black outline
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true  # Always visible through objects
	building.add_child(label)
