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

## Wall thickness for volumetric walls (in meters)
const WALL_THICKNESS = 0.25  # 25cm thick walls (realistic for buildings)

## Generate complete building from OSM data
static func create_building(osm_data: Dictionary, parent: Node, detailed: bool = true, material_lib = null) -> Node3D:
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

	# Create building mesh (with interior walls if detailed)
	var building_mesh = _create_building_mesh(footprint, center, height, levels, osm_data, detailed, material_lib)
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
static func _create_building_mesh(footprint: Array, center: Vector2, height: float, levels: int, osm_data: Dictionary, detailed: bool, material_lib = null) -> MeshInstance3D:
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
	var window_colors = PackedColorArray()  # Per-window emission control
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

	# Surface 4: Floor slabs (horizontal concrete floors)
	var floor_vertices = PackedVector3Array()
	var floor_normals = PackedVector3Array()
	var floor_uvs = PackedVector2Array()
	var floor_indices = PackedInt32Array()

	# Generate walls with windows (now populates separate arrays)
	_generate_walls_multi_surface(footprint, center, height, levels, osm_data, detailed,
		wall_vertices, wall_normals, wall_uvs, wall_indices,
		window_vertices, window_normals, window_uvs, window_colors, window_indices,
		frame_vertices, frame_normals, frame_uvs, frame_indices)

	# Generate architectural details - adds to wall geometry
	if detailed:
		_generate_building_foundation(footprint, center, wall_vertices, wall_normals, wall_uvs, wall_indices)
		if levels > 1:  # Only for multi-story buildings
			_generate_cornice(footprint, center, height, wall_vertices, wall_normals, wall_uvs, wall_indices)
			_generate_floor_ledges(footprint, center, height, levels, wall_vertices, wall_normals, wall_uvs, wall_indices)
			# Add floor slabs (horizontal concrete floors at each level)
			_generate_floor_slabs(footprint, center, height, levels, floor_vertices, floor_normals, floor_uvs, floor_indices)

		# DISABLED: Interior walls add too much geometry (performance issue)
		# TODO: Re-enable with LOD system (only nearest buildings)
		# var building_type = osm_data.get("building_type", "commercial")
		# var floor_height = height / float(levels) if levels > 0 else height
		# var rooms = _subdivide_footprint_into_rooms(footprint, center, building_type, levels)
		# _create_interior_walls(rooms, floor_height, wall_vertices, wall_normals, wall_uvs, wall_indices)

	# Generate roof (separate surface for OSM colors/materials)
	var roof_shape = osm_data.get("roof:shape", "")
	var building_id = int(osm_data.get("id", 0))

	# TEMPORARY: Use flat roofs for all buildings until proper roof generation is implemented
	# The sloped roof algorithms (gabled/hipped/pyramidal) create messy geometry on irregular footprints
	# TODO: Implement proper roof generation module in future
	if roof_shape == "" or roof_shape in ["gabled", "hipped", "pyramidal"]:
		roof_shape = "flat"  # Force flat roofs for now

	# Future roof inference code (disabled):
	# if roof_shape == "":
	#	var building_type = osm_data.get("building_type", "")
	#	match building_type:
	#		"house", "residential", "apartments":
	#			var shapes = ["gabled", "hipped"]
	#			roof_shape = shapes[building_id % shapes.size()]
	#		_:
	#			roof_shape = "flat"

	_generate_roof(footprint, center, height, roof_shape, osm_data, roof_vertices, roof_normals, roof_uvs, roof_indices)


	# Build surfaces and track actual indices (they shift based on what's added)
	var current_surface_index = 0
	var wall_surface_index = -1
	var window_surface_index = -1
	var frame_surface_index = -1
	var roof_surface_index = -1
	var floor_surface_index = -1

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
		window_arrays[Mesh.ARRAY_COLOR] = window_colors  # Per-vertex emission control
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

	# Surface: Floor slabs (if any)
	if floor_vertices.size() > 0:
		var floor_arrays = []
		floor_arrays.resize(Mesh.ARRAY_MAX)
		floor_arrays[Mesh.ARRAY_VERTEX] = floor_vertices
		floor_arrays[Mesh.ARRAY_NORMAL] = floor_normals
		floor_arrays[Mesh.ARRAY_TEX_UV] = floor_uvs
		floor_arrays[Mesh.ARRAY_INDEX] = floor_indices
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, floor_arrays)
		floor_surface_index = current_surface_index
		current_surface_index += 1

	mesh_instance.mesh = array_mesh

	# Apply materials to each surface using tracked indices
	if wall_surface_index >= 0:
		mesh_instance.set_surface_override_material(wall_surface_index, _create_building_material(osm_data, material_lib))
	if window_surface_index >= 0:
		mesh_instance.set_surface_override_material(window_surface_index, _create_window_material(osm_data, material_lib))
	if frame_surface_index >= 0:
		mesh_instance.set_surface_override_material(frame_surface_index, _create_frame_material(material_lib))
	if roof_surface_index >= 0:
		mesh_instance.set_surface_override_material(roof_surface_index, _create_roof_material(osm_data, material_lib))
	if floor_surface_index >= 0:
		mesh_instance.set_surface_override_material(floor_surface_index, _create_floor_material(material_lib))

	return mesh_instance

## Generate wall geometry with window openings (multi-surface version)
static func _generate_walls_multi_surface(footprint: Array, center: Vector2, height: float, levels: int, osm_data: Dictionary, detailed: bool,
	wall_vertices: PackedVector3Array, wall_normals: PackedVector3Array, wall_uvs: PackedVector2Array, wall_indices: PackedInt32Array,
	window_vertices: PackedVector3Array, window_normals: PackedVector3Array, window_uvs: PackedVector2Array, window_colors: PackedColorArray, window_indices: PackedInt32Array,
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
			window_vertices, window_normals, window_uvs, window_colors, window_indices,
			frame_vertices, frame_normals, frame_uvs, frame_indices)

## Create a single wall segment with window openings (multi-surface version)
static func _create_wall_segment_multi_surface(p1: Vector2, p2: Vector2, height: float, floor_height: float, levels: int, window_params: Dictionary, detailed: bool,
	wall_vertices: PackedVector3Array, wall_normals: PackedVector3Array, wall_uvs: PackedVector2Array, wall_indices: PackedInt32Array,
	window_vertices: PackedVector3Array, window_normals: PackedVector3Array, window_uvs: PackedVector2Array, window_colors: PackedColorArray, window_indices: PackedInt32Array,
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
		# Simple wall without windows (volumetric)
		var base_index = wall_vertices.size()
		_add_volumetric_wall_quad(p1, p2, 0.0, height, wall_normal, wall_vertices, wall_normals, wall_uvs, wall_indices, base_index)
	else:
		# Complex wall with window cutouts
		for floor_num in range(levels):
			var floor_bottom = floor_num * floor_height
			var floor_top = (floor_num + 1) * floor_height

			# Create wall segments around windows (multi-surface)
			_create_wall_with_windows_multi_surface(p1, p2, floor_bottom, floor_top, windows_per_floor, wall_normal, wall_length,
				wall_vertices, wall_normals, wall_uvs, wall_indices,
				window_vertices, window_normals, window_uvs, window_colors, window_indices,
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
	window_vertices: PackedVector3Array, window_normals: PackedVector3Array, window_uvs: PackedVector2Array, window_colors: PackedColorArray, window_indices: PackedInt32Array,
	frame_vertices: PackedVector3Array, frame_normals: PackedVector3Array, frame_uvs: PackedVector2Array, frame_indices: PackedInt32Array):

	if windows.is_empty():
		# No windows - create full volumetric wall
		var base_index = wall_vertices.size()
		_add_volumetric_wall_quad(p1, p2, floor_bottom, floor_top, wall_normal, wall_vertices, wall_normals, wall_uvs, wall_indices, base_index)
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
			_add_volumetric_wall_quad(seg_p1, seg_p2, floor_bottom, floor_top, wall_normal, wall_vertices, wall_normals, wall_uvs, wall_indices, base_index)

		# Wall segment above window
		if window_top < floor_top - 0.01:
			var seg_p1 = p1.lerp(p2, window_left_t)
			var seg_p2 = p1.lerp(p2, window_right_t)
			var base_index = wall_vertices.size()
			_add_volumetric_wall_quad(seg_p1, seg_p2, window_top, floor_top, wall_normal, wall_vertices, wall_normals, wall_uvs, wall_indices, base_index)

		# Wall segment below window
		if window_bottom > floor_bottom + 0.01:
			var seg_p1 = p1.lerp(p2, window_left_t)
			var seg_p2 = p1.lerp(p2, window_right_t)
			var base_index = wall_vertices.size()
			_add_volumetric_wall_quad(seg_p1, seg_p2, floor_bottom, window_bottom, wall_normal, wall_vertices, wall_normals, wall_uvs, wall_indices, base_index)

		# Add window reveal (wall edge around window opening - goes to wall surface)
		_add_window_reveal(p1, p2, window_left_t, window_right_t, window_bottom, window_top, wall_normal, wall_vertices, wall_normals, wall_uvs, wall_indices)

		# Add window glass (goes to window surface)
		var window_base = window_vertices.size()

		# Generate per-window emission parameters (40% chance of lit window)
		var window_emission_color = Color.BLACK  # Default: no emission
		if randf() < 0.4:
			# Window is lit - emission stored in vertex color RGB
			# Alpha channel stores emission multiplier with WIDE variation
			var emission_multiplier = randf_range(0.2, 1.0)

			# Add COLOR VARIATION to simulate different light sources and occupancy
			var color_roll = randf()
			var emission_base: Color

			if color_roll < 0.60:
				# Warm yellow/orange (most common - incandescent/warm LED)
				emission_base = Color(1.0, randf_range(0.85, 0.95), randf_range(0.6, 0.8))
			elif color_roll < 0.85:
				# Neutral white (cool LED, office lighting)
				emission_base = Color(randf_range(0.95, 1.0), randf_range(0.95, 1.0), randf_range(0.9, 1.0))
			elif color_roll < 0.95:
				# Dim warm (candles, dim lamps, cozy)
				emission_base = Color(1.0, randf_range(0.7, 0.85), randf_range(0.4, 0.6)) * 0.6
			else:
				# Blue glow (TV/monitor light)
				emission_base = Color(randf_range(0.6, 0.8), randf_range(0.7, 0.9), 1.0) * 0.8

			# Apply occupancy variation (curtains, blinds, furniture blocking)
			# Reduce alpha for "partially blocked" windows
			if randf() < 0.3:
				emission_multiplier *= randf_range(0.3, 0.6)  # Curtains/blinds partially closed

			window_emission_color = Color(emission_base.r, emission_base.g, emission_base.b, emission_multiplier)

		_add_window_glass_multi(p1, p2, window_left_t, window_right_t, window_bottom, window_top, wall_normal, window_vertices, window_normals, window_uvs, window_colors, window_indices, window_base, window_emission_color)

		# Add window frame (goes to frame surface)
		_add_window_frame_multi(p1, p2, window_left_t, window_right_t, window_bottom, window_top, wall_normal, frame_vertices, frame_normals, frame_uvs, frame_indices)

		# Update prev_end_t for next window
		prev_end_t = window_right_t

	# ALWAYS create wall segment from last window to end of wall
	if prev_end_t < 0.99:
		var seg_p1 = p1.lerp(p2, prev_end_t)
		var seg_p2 = p2
		var base_index = wall_vertices.size()
		_add_volumetric_wall_quad(seg_p1, seg_p2, floor_bottom, floor_top, wall_normal, wall_vertices, wall_normals, wall_uvs, wall_indices, base_index)

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

## Add a volumetric wall quad with thickness (creates 6 faces: outer, inner, and 4 edges)
static func _add_volumetric_wall_quad(p1: Vector2, p2: Vector2, y_bottom: float, y_top: float, normal: Vector3, vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, base_index: int, wall_thickness: float = WALL_THICKNESS):
	# Calculate inward offset for inner wall face
	var thickness_offset = Vector3(normal.x * -wall_thickness, 0, normal.z * -wall_thickness)

	# Outer face vertices (visible from outside)
	var outer_v1 = Vector3(p1.x, y_bottom, -p1.y)
	var outer_v2 = Vector3(p2.x, y_bottom, -p2.y)
	var outer_v3 = Vector3(p2.x, y_top, -p2.y)
	var outer_v4 = Vector3(p1.x, y_top, -p1.y)

	# Inner face vertices (offset inward)
	var inner_v1 = outer_v1 + thickness_offset
	var inner_v2 = outer_v2 + thickness_offset
	var inner_v3 = outer_v3 + thickness_offset
	var inner_v4 = outer_v4 + thickness_offset

	var wall_width = p1.distance_to(p2)
	var wall_height = y_top - y_bottom

	# === OUTER FACE (visible from outside) ===
	vertices.append(outer_v1)
	vertices.append(outer_v2)
	vertices.append(outer_v3)
	vertices.append(outer_v4)

	for i in range(4):
		normals.append(normal)

	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(wall_width, 0))
	uvs.append(Vector2(wall_width, wall_height))
	uvs.append(Vector2(0, wall_height))

	# Outer face triangles
	indices.append(base_index + 0)
	indices.append(base_index + 1)
	indices.append(base_index + 2)
	indices.append(base_index + 0)
	indices.append(base_index + 2)
	indices.append(base_index + 3)

	# === INNER FACE (visible from inside, reversed winding) ===
	var inner_base = base_index + 4
	vertices.append(inner_v1)
	vertices.append(inner_v2)
	vertices.append(inner_v3)
	vertices.append(inner_v4)

	var inner_normal = -normal  # Flip normal for inner face
	for i in range(4):
		normals.append(inner_normal)

	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(wall_width, 0))
	uvs.append(Vector2(wall_width, wall_height))
	uvs.append(Vector2(0, wall_height))

	# Inner face triangles (reversed winding)
	indices.append(inner_base + 0)
	indices.append(inner_base + 3)
	indices.append(inner_base + 2)
	indices.append(inner_base + 0)
	indices.append(inner_base + 2)
	indices.append(inner_base + 1)

	# === TOP EDGE (connecting outer top to inner top) ===
	var top_base = base_index + 8
	vertices.append(outer_v4)  # Outer left top
	vertices.append(outer_v3)  # Outer right top
	vertices.append(inner_v3)  # Inner right top
	vertices.append(inner_v4)  # Inner left top

	var top_normal = Vector3.UP
	for i in range(4):
		normals.append(top_normal)

	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(wall_width, 0))
	uvs.append(Vector2(wall_width, wall_thickness))
	uvs.append(Vector2(0, wall_thickness))

	indices.append(top_base + 0)
	indices.append(top_base + 1)
	indices.append(top_base + 2)
	indices.append(top_base + 0)
	indices.append(top_base + 2)
	indices.append(top_base + 3)

	# === BOTTOM EDGE (connecting outer bottom to inner bottom) ===
	var bottom_base = base_index + 12
	vertices.append(outer_v1)  # Outer left bottom
	vertices.append(outer_v2)  # Outer right bottom
	vertices.append(inner_v2)  # Inner right bottom
	vertices.append(inner_v1)  # Inner left bottom

	var bottom_normal = Vector3.DOWN
	for i in range(4):
		normals.append(bottom_normal)

	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(wall_width, 0))
	uvs.append(Vector2(wall_width, wall_thickness))
	uvs.append(Vector2(0, wall_thickness))

	# Reversed winding for bottom (facing down)
	indices.append(bottom_base + 0)
	indices.append(bottom_base + 3)
	indices.append(bottom_base + 2)
	indices.append(bottom_base + 0)
	indices.append(bottom_base + 2)
	indices.append(bottom_base + 1)

	# === LEFT EDGE (connecting outer left to inner left) ===
	var left_base = base_index + 16
	var left_dir = (p2 - p1).normalized()
	var left_normal = Vector3(-left_dir.x, 0, left_dir.y)  # Perpendicular to wall, pointing left

	vertices.append(outer_v1)  # Outer bottom
	vertices.append(outer_v4)  # Outer top
	vertices.append(inner_v4)  # Inner top
	vertices.append(inner_v1)  # Inner bottom

	for i in range(4):
		normals.append(left_normal)

	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(0, wall_height))
	uvs.append(Vector2(wall_thickness, wall_height))
	uvs.append(Vector2(wall_thickness, 0))

	indices.append(left_base + 0)
	indices.append(left_base + 3)
	indices.append(left_base + 2)
	indices.append(left_base + 0)
	indices.append(left_base + 2)
	indices.append(left_base + 1)

	# === RIGHT EDGE (connecting outer right to inner right) ===
	var right_base = base_index + 20
	var right_normal = -left_normal  # Opposite of left normal

	vertices.append(outer_v2)  # Outer bottom
	vertices.append(outer_v3)  # Outer top
	vertices.append(inner_v3)  # Inner top
	vertices.append(inner_v2)  # Inner bottom

	for i in range(4):
		normals.append(right_normal)

	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(0, wall_height))
	uvs.append(Vector2(wall_thickness, wall_height))
	uvs.append(Vector2(wall_thickness, 0))

	indices.append(right_base + 0)
	indices.append(right_base + 1)
	indices.append(right_base + 2)
	indices.append(right_base + 0)
	indices.append(right_base + 2)
	indices.append(right_base + 3)

	# Total: 24 vertices (4 outer + 4 inner + 4 top + 4 bottom + 4 left + 4 right)
	# Total: 12 triangles (2 outer + 2 inner + 2 top + 2 bottom + 2 left + 2 right)

## Add window reveal (wall edges around window opening showing wall thickness)
static func _add_window_reveal(p1: Vector2, p2: Vector2, t1: float, t2: float, y_bottom: float, y_top: float, normal: Vector3, vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, recess_depth: float = 0.15):
	var window_p1 = p1.lerp(p2, t1)
	var window_p2 = p1.lerp(p2, t2)
	var window_width = window_p1.distance_to(window_p2)
	var window_height = y_top - y_bottom

	# Outer edge (at wall outer face)
	var outer_offset = Vector3(0, 0, 0)  # At wall surface
	# Inner edge (recessed into wall)
	var inner_offset = Vector3(normal.x * -recess_depth, 0, normal.z * -recess_depth)

	# Outer corners
	var outer_bl = Vector3(window_p1.x, y_bottom, -window_p1.y) + outer_offset
	var outer_br = Vector3(window_p2.x, y_bottom, -window_p2.y) + outer_offset
	var outer_tr = Vector3(window_p2.x, y_top, -window_p2.y) + outer_offset
	var outer_tl = Vector3(window_p1.x, y_top, -window_p1.y) + outer_offset

	# Inner corners (recessed)
	var inner_bl = Vector3(window_p1.x, y_bottom, -window_p1.y) + inner_offset
	var inner_br = Vector3(window_p2.x, y_bottom, -window_p2.y) + inner_offset
	var inner_tr = Vector3(window_p2.x, y_top, -window_p2.y) + inner_offset
	var inner_tl = Vector3(window_p1.x, y_top, -window_p1.y) + inner_offset

	# Calculate perpendicular direction for left/right normals
	var wall_dir = (window_p2 - window_p1).normalized()
	var left_normal = Vector3(-wall_dir.x, 0, wall_dir.y)
	var right_normal = -left_normal

	# === TOP REVEAL (horizontal surface at top of window) ===
	var top_base = vertices.size()
	vertices.append(outer_tl)
	vertices.append(outer_tr)
	vertices.append(inner_tr)
	vertices.append(inner_tl)

	var top_normal = Vector3(0, 1, 0)  # Facing up (but slightly angled down into recess)
	for i in range(4):
		normals.append(top_normal)

	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(window_width, 0))
	uvs.append(Vector2(window_width, recess_depth))
	uvs.append(Vector2(0, recess_depth))

	indices.append(top_base + 0)
	indices.append(top_base + 3)
	indices.append(top_base + 2)
	indices.append(top_base + 0)
	indices.append(top_base + 2)
	indices.append(top_base + 1)

	# === BOTTOM REVEAL (horizontal surface at bottom of window) ===
	var bottom_base = vertices.size()
	vertices.append(outer_bl)
	vertices.append(outer_br)
	vertices.append(inner_br)
	vertices.append(inner_bl)

	var bottom_normal = Vector3(0, -1, 0)  # Facing down
	for i in range(4):
		normals.append(bottom_normal)

	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(window_width, 0))
	uvs.append(Vector2(window_width, recess_depth))
	uvs.append(Vector2(0, recess_depth))

	indices.append(bottom_base + 0)
	indices.append(bottom_base + 1)
	indices.append(bottom_base + 2)
	indices.append(bottom_base + 0)
	indices.append(bottom_base + 2)
	indices.append(bottom_base + 3)

	# === LEFT REVEAL (vertical surface on left side) ===
	var left_base = vertices.size()
	vertices.append(outer_bl)
	vertices.append(outer_tl)
	vertices.append(inner_tl)
	vertices.append(inner_bl)

	for i in range(4):
		normals.append(left_normal)

	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(0, window_height))
	uvs.append(Vector2(recess_depth, window_height))
	uvs.append(Vector2(recess_depth, 0))

	indices.append(left_base + 0)
	indices.append(left_base + 3)
	indices.append(left_base + 2)
	indices.append(left_base + 0)
	indices.append(left_base + 2)
	indices.append(left_base + 1)

	# === RIGHT REVEAL (vertical surface on right side) ===
	var right_base = vertices.size()
	vertices.append(outer_br)
	vertices.append(outer_tr)
	vertices.append(inner_tr)
	vertices.append(inner_br)

	for i in range(4):
		normals.append(right_normal)

	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(0, window_height))
	uvs.append(Vector2(recess_depth, window_height))
	uvs.append(Vector2(recess_depth, 0))

	indices.append(right_base + 0)
	indices.append(right_base + 1)
	indices.append(right_base + 2)
	indices.append(right_base + 0)
	indices.append(right_base + 2)
	indices.append(right_base + 3)

	# Total: 16 vertices (4 per reveal quad)
	# Total: 8 triangles (2 per reveal quad)

## Add window glass quad (multi-surface version)
static func _add_window_glass_multi(p1: Vector2, p2: Vector2, t1: float, t2: float, y_bottom: float, y_top: float, normal: Vector3, vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array, base_index: int, emission_color: Color = Color.BLACK, recess_depth: float = 0.15):
	var window_p1 = p1.lerp(p2, t1)
	var window_p2 = p1.lerp(p2, t2)

	# Recess window glass into wall (negative offset = inward)
	var offset = Vector3(normal.x * -recess_depth, 0, normal.z * -recess_depth)

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
		colors.append(emission_color)  # Vertex color encodes emission

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
	var colors = PackedColorArray()  # Unused in old version
	_add_window_glass_multi(p1, p2, t1, t2, y_bottom, y_top, normal, vertices, normals, uvs, colors, indices, base_index, Color.BLACK)

## Add window frame around window opening (multi-surface version)
static func _add_window_frame_multi(p1: Vector2, p2: Vector2, t1: float, t2: float, y_bottom: float, y_top: float, normal: Vector3, vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, recess_depth: float = 0.15):
	var window_p1 = p1.lerp(p2, t1)
	var window_p2 = p1.lerp(p2, t2)
	var window_width = window_p1.distance_to(window_p2)

	var frame_thickness = 0.08  # 8cm frame thickness
	var frame_depth = recess_depth  # Frame at window recess depth

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

	# Place roof slightly above cornice to avoid z-fighting
	var roof_y = building_height + 0.05  # 5cm above building top/cornice
	var base_index = vertices.size()

	# Convert footprint to local coordinates
	var local_polygon = []
	for point in footprint:
		local_polygon.append(point - center)

	# Use Godot's built-in triangulation (handles concave footprints correctly)
	var roof_indices_raw = PolygonTriangulator.triangulate(local_polygon)

	# REVERSE indices for correct winding order (normals facing UP)
	var roof_indices_reversed = PackedInt32Array()
	for i in range(0, roof_indices_raw.size(), 3):
		roof_indices_reversed.append(roof_indices_raw[i + 2])
		roof_indices_reversed.append(roof_indices_raw[i + 1])
		roof_indices_reversed.append(roof_indices_raw[i])

	# Add roof vertices
	for point in local_polygon:
		vertices.append(Vector3(point.x, roof_y, -point.y))
		normals.append(Vector3.UP)
		uvs.append(Vector2(point.x, point.y))

	# Add triangulated indices (offset by base_index)
	for idx in roof_indices_reversed:
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

		# Triangle (reversed winding for correct normals)
		indices.append(face_base + 0)
		indices.append(face_base + 2)
		indices.append(face_base + 1)

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

		# First triangle (reversed winding)
		indices.append(face_base + 0)
		indices.append(face_base + 2)
		indices.append(face_base + 1)

		# Second triangle (reversed winding)
		indices.append(face_base + 0)
		indices.append(face_base + 3)
		indices.append(face_base + 2)

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

		# Reversed winding for correct normals
		indices.append(face_base + 0)
		indices.append(face_base + 2)
		indices.append(face_base + 1)

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

## Generate building foundation (darker base at ground level)
static func _generate_building_foundation(footprint: Array, center: Vector2, vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array):
	if footprint.size() < 3:
		return

	var foundation_height = 1.0  # 1m tall darker base
	var foundation_protrusion = 0.05  # 5cm slight protrusion

	# Generate foundation band around building perimeter at ground level
	for i in range(footprint.size()):
		var p1 = footprint[i] - center
		var p2 = footprint[(i + 1) % footprint.size()] - center

		# Calculate wall normal (outward direction)
		var wall_dir = (p2 - p1).normalized()
		var wall_normal = Vector3(-wall_dir.y, 0, wall_dir.x)

		# Offset for slight protrusion
		var protrusion_offset = Vector3(wall_normal.x * foundation_protrusion, 0, wall_normal.z * foundation_protrusion)

		# Base (at wall surface)
		var base_bl = Vector3(p1.x, 0, -p1.y)
		var base_br = Vector3(p2.x, 0, -p2.y)
		var base_tl = Vector3(p1.x, foundation_height, -p1.y)
		var base_tr = Vector3(p2.x, foundation_height, -p2.y)

		# Protruding edge
		var prot_bl = base_bl + protrusion_offset
		var prot_br = base_br + protrusion_offset
		var prot_tl = base_tl + protrusion_offset
		var prot_tr = base_tr + protrusion_offset

		var base_index = vertices.size()

		# === OUTER FACE (protruding front - darker material) ===
		vertices.append(prot_bl)
		vertices.append(prot_br)
		vertices.append(prot_tr)
		vertices.append(prot_tl)

		for j in range(4):
			normals.append(wall_normal)

		var segment_width = p1.distance_to(p2)
		uvs.append(Vector2(0, 0))
		uvs.append(Vector2(segment_width, 0))
		uvs.append(Vector2(segment_width, foundation_height))
		uvs.append(Vector2(0, foundation_height))

		indices.append(base_index + 0)
		indices.append(base_index + 1)
		indices.append(base_index + 2)
		indices.append(base_index + 0)
		indices.append(base_index + 2)
		indices.append(base_index + 3)

		# === TOP FACE (top of foundation) ===
		var top_base = vertices.size()
		vertices.append(base_tl)
		vertices.append(base_tr)
		vertices.append(prot_tr)
		vertices.append(prot_tl)

		for j in range(4):
			normals.append(Vector3.UP)

		uvs.append(Vector2(0, 0))
		uvs.append(Vector2(segment_width, 0))
		uvs.append(Vector2(segment_width, foundation_protrusion))
		uvs.append(Vector2(0, foundation_protrusion))

		indices.append(top_base + 0)
		indices.append(top_base + 1)
		indices.append(top_base + 2)
		indices.append(top_base + 0)
		indices.append(top_base + 2)
		indices.append(top_base + 3)

## Generate cornice (decorative protruding band at top of building)
static func _generate_cornice(footprint: Array, center: Vector2, building_height: float, vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array):
	if footprint.size() < 3:
		return

	var cornice_height = 0.5  # 50cm tall cornice
	var cornice_protrusion = 0.35  # 35cm protrusion from wall
	var cornice_bottom = building_height - cornice_height
	var cornice_top = building_height

	# Generate cornice around building perimeter
	for i in range(footprint.size()):
		var p1 = footprint[i] - center
		var p2 = footprint[(i + 1) % footprint.size()] - center

		# Calculate wall normal (outward direction)
		var wall_dir = (p2 - p1).normalized()
		var wall_normal = Vector3(-wall_dir.y, 0, wall_dir.x)

		# Offset for protrusion
		var protrusion_offset = Vector3(wall_normal.x * cornice_protrusion, 0, wall_normal.z * cornice_protrusion)

		# Base (at wall surface)
		var base_bl = Vector3(p1.x, cornice_bottom, -p1.y)
		var base_br = Vector3(p2.x, cornice_bottom, -p2.y)
		var base_tl = Vector3(p1.x, cornice_top, -p1.y)
		var base_tr = Vector3(p2.x, cornice_top, -p2.y)

		# Protruding edge
		var prot_bl = base_bl + protrusion_offset
		var prot_br = base_br + protrusion_offset
		var prot_tl = base_tl + protrusion_offset
		var prot_tr = base_tr + protrusion_offset

		var base_index = vertices.size()

		# === OUTER FACE (protruding front) ===
		vertices.append(prot_bl)
		vertices.append(prot_br)
		vertices.append(prot_tr)
		vertices.append(prot_tl)

		for j in range(4):
			normals.append(wall_normal)

		var segment_width = p1.distance_to(p2)
		uvs.append(Vector2(0, 0))
		uvs.append(Vector2(segment_width, 0))
		uvs.append(Vector2(segment_width, cornice_height))
		uvs.append(Vector2(0, cornice_height))

		indices.append(base_index + 0)
		indices.append(base_index + 1)
		indices.append(base_index + 2)
		indices.append(base_index + 0)
		indices.append(base_index + 2)
		indices.append(base_index + 3)

		# === BOTTOM FACE (underside of protrusion) ===
		var bottom_base = vertices.size()
		vertices.append(base_bl)
		vertices.append(base_br)
		vertices.append(prot_br)
		vertices.append(prot_bl)

		for j in range(4):
			normals.append(Vector3.DOWN)

		uvs.append(Vector2(0, 0))
		uvs.append(Vector2(segment_width, 0))
		uvs.append(Vector2(segment_width, cornice_protrusion))
		uvs.append(Vector2(0, cornice_protrusion))

		# Reversed winding for downward face
		indices.append(bottom_base + 0)
		indices.append(bottom_base + 3)
		indices.append(bottom_base + 2)
		indices.append(bottom_base + 0)
		indices.append(bottom_base + 2)
		indices.append(bottom_base + 1)

		# === TOP FACE (top of cornice) ===
		var top_base = vertices.size()
		vertices.append(base_tl)
		vertices.append(base_tr)
		vertices.append(prot_tr)
		vertices.append(prot_tl)

		for j in range(4):
			normals.append(Vector3.UP)

		uvs.append(Vector2(0, 0))
		uvs.append(Vector2(segment_width, 0))
		uvs.append(Vector2(segment_width, cornice_protrusion))
		uvs.append(Vector2(0, cornice_protrusion))

		indices.append(top_base + 0)
		indices.append(top_base + 1)
		indices.append(top_base + 2)
		indices.append(top_base + 0)
		indices.append(top_base + 2)
		indices.append(top_base + 3)

## Generate floor slabs (horizontal concrete floors at each level)
static func _generate_floor_slabs(footprint: Array, center: Vector2, height: float, levels: int, vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array):
	if footprint.size() < 3 or levels < 2:
		return

	var floor_height = height / float(levels)
	var slab_thickness = 0.25  # 25cm thick concrete slab

	# Generate floor slabs at each level (skip ground floor, include all upper floors)
	for floor_num in range(1, levels):  # Start from floor 1 (first floor above ground)
		var slab_bottom_y = floor_num * floor_height
		var slab_top_y = slab_bottom_y + slab_thickness

		# Convert footprint to local coordinates
		var local_polygon = []
		for point in footprint:
			local_polygon.append(point - center)

		# Triangulate the floor footprint
		var floor_indices_raw = PolygonTriangulator.triangulate(local_polygon)

		# REVERSE indices for correct winding order (top face visible from above)
		var floor_indices_reversed = PackedInt32Array()
		for i in range(0, floor_indices_raw.size(), 3):
			floor_indices_reversed.append(floor_indices_raw[i + 2])
			floor_indices_reversed.append(floor_indices_raw[i + 1])
			floor_indices_reversed.append(floor_indices_raw[i])

		# === TOP FACE (visible from above) ===
		var top_base_index = vertices.size()
		for point in local_polygon:
			vertices.append(Vector3(point.x, slab_top_y, -point.y))
			normals.append(Vector3.UP)
			uvs.append(Vector2(point.x, point.y))

		for idx in floor_indices_reversed:
			indices.append(top_base_index + idx)

		# === BOTTOM FACE (visible from below) ===
		var bottom_base_index = vertices.size()
		for point in local_polygon:
			vertices.append(Vector3(point.x, slab_bottom_y, -point.y))
			normals.append(Vector3.DOWN)
			uvs.append(Vector2(point.x, point.y))

		# Use non-reversed indices for bottom (facing down)
		for idx in floor_indices_raw:
			indices.append(bottom_base_index + idx)

## Generate floor ledges (horizontal bands between floors)
static func _generate_floor_ledges(footprint: Array, center: Vector2, height: float, levels: int, vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array):
	if footprint.size() < 3 or levels < 2:
		return

	var floor_height = height / float(levels)
	var ledge_height = 0.25  # 25cm tall ledge (more visible)
	var ledge_protrusion = 0.20  # 20cm protrusion from wall (more prominent)

	# Generate ledges at each floor division (not at top or bottom)
	for floor_num in range(1, levels):  # Skip floor 0 (ground) and top floor (has cornice)
		var ledge_y = floor_num * floor_height

		# Generate ledge around building perimeter
		for i in range(footprint.size()):
			var p1 = footprint[i] - center
			var p2 = footprint[(i + 1) % footprint.size()] - center

			# Calculate wall normal (outward direction)
			var wall_dir = (p2 - p1).normalized()
			var wall_normal = Vector3(-wall_dir.y, 0, wall_dir.x)

			# Offset for protrusion
			var protrusion_offset = Vector3(wall_normal.x * ledge_protrusion, 0, wall_normal.z * ledge_protrusion)

			# Base (at wall surface)
			var base_b = Vector3(p1.x, ledge_y, -p1.y)
			var base_br = Vector3(p2.x, ledge_y, -p2.y)
			var base_t = Vector3(p1.x, ledge_y + ledge_height, -p1.y)
			var base_tr = Vector3(p2.x, ledge_y + ledge_height, -p2.y)

			# Protruding edge
			var prot_b = base_b + protrusion_offset
			var prot_br = base_br + protrusion_offset
			var prot_t = base_t + protrusion_offset
			var prot_tr = base_tr + protrusion_offset

			var base_index = vertices.size()

			# === OUTER FACE (protruding front) ===
			vertices.append(prot_b)
			vertices.append(prot_br)
			vertices.append(prot_tr)
			vertices.append(prot_t)

			for j in range(4):
				normals.append(wall_normal)

			var segment_width = p1.distance_to(p2)
			uvs.append(Vector2(0, 0))
			uvs.append(Vector2(segment_width, 0))
			uvs.append(Vector2(segment_width, ledge_height))
			uvs.append(Vector2(0, ledge_height))

			indices.append(base_index + 0)
			indices.append(base_index + 1)
			indices.append(base_index + 2)
			indices.append(base_index + 0)
			indices.append(base_index + 2)
			indices.append(base_index + 3)

			# === BOTTOM FACE (underside of ledge) ===
			var bottom_base = vertices.size()
			vertices.append(base_b)
			vertices.append(base_br)
			vertices.append(prot_br)
			vertices.append(prot_b)

			for j in range(4):
				normals.append(Vector3.DOWN)

			uvs.append(Vector2(0, 0))
			uvs.append(Vector2(segment_width, 0))
			uvs.append(Vector2(segment_width, ledge_protrusion))
			uvs.append(Vector2(0, ledge_protrusion))

			# Reversed winding for downward face
			indices.append(bottom_base + 0)
			indices.append(bottom_base + 3)
			indices.append(bottom_base + 2)
			indices.append(bottom_base + 0)
			indices.append(bottom_base + 2)
			indices.append(bottom_base + 1)

			# === TOP FACE (top of ledge) ===
			var top_base = vertices.size()
			vertices.append(base_t)
			vertices.append(base_tr)
			vertices.append(prot_tr)
			vertices.append(prot_t)

			for j in range(4):
				normals.append(Vector3.UP)

			uvs.append(Vector2(0, 0))
			uvs.append(Vector2(segment_width, 0))
			uvs.append(Vector2(segment_width, ledge_protrusion))
			uvs.append(Vector2(0, ledge_protrusion))

			indices.append(top_base + 0)
			indices.append(top_base + 1)
			indices.append(top_base + 2)
			indices.append(top_base + 0)
			indices.append(top_base + 2)
			indices.append(top_base + 3)

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

## Create building material with PBR shading
static func _create_building_material(osm_data: Dictionary, material_lib = null) -> StandardMaterial3D:
	# Use MaterialLibrary if available
	if material_lib:
		var material_name = material_lib.get_material_by_osm_tags(osm_data, "wall")
		return material_lib.get_material(material_name, true)  # Apply variation

	# Fallback: create material manually (old way)
	var material = StandardMaterial3D.new()

	# Try to get building color from OSM data
	var building_color_str = osm_data.get("building:colour", "")
	var building_material_str = osm_data.get("building:material", "")
	var building_type = osm_data.get("building_type", "")
	var building_id = int(osm_data.get("id", 0))
	var wall_color = Color.TRANSPARENT

	# Priority 1: Explicit OSM building color
	if building_color_str != "":
		wall_color = _parse_osm_color(building_color_str)

	# Priority 2: Building material type
	if wall_color == Color.TRANSPARENT and building_material_str != "":
		match building_material_str.to_lower():
			"brick":
				wall_color = Color.html("#B85C4D")  # Red brick
			"concrete":
				wall_color = Color.html("#C0C0C0")  # Gray concrete
			"wood":
				wall_color = Color.html("#D2B48C")  # Light wood/tan
			"stone":
				wall_color = Color.html("#A8A8A8")  # Gray stone
			"plaster", "stucco":
				wall_color = Color.html("#F5E6D3")  # Off-white/cream
			"glass":
				wall_color = Color.html("#E0F2F7")  # Light blue-tinted

	# Priority 3: Realistic variety based on building type
	if wall_color == Color.TRANSPARENT:
		match building_type:
			"house", "residential":
				# Residential: warm, varied colors
				var colors = [
					Color.html("#F5DEB3"),  # Wheat/tan
					Color.html("#E8D4C0"),  # Beige
					Color.html("#D2B48C"),  # Light tan
					Color.html("#C9B8A0"),  # Warm gray
					Color.html("#B85C4D"),  # Red brick
					Color.html("#8B7355"),  # Brown
					Color.html("#FFFACD"),  # Light yellow
					Color.html("#E6E6E6"),  # Light gray
				]
				wall_color = colors[building_id % colors.size()]
			"commercial", "office", "retail":
				# Commercial: grays, whites, modern
				var colors = [
					Color.html("#E0E0E0"),  # Light gray
					Color.html("#F5F5F5"),  # Off-white
					Color.html("#C0C0C0"),  # Gray
					Color.html("#B0B0B0"),  # Medium gray
					Color.html("#D3D3D3"),  # Light steel
				]
				wall_color = colors[building_id % colors.size()]
			"industrial", "warehouse":
				# Industrial: utilitarian colors
				var colors = [
					Color.html("#A0A0A0"),  # Gray
					Color.html("#8B7355"),  # Brown
					Color.html("#B0B0B0"),  # Light gray metal
					Color.html("#696969"),  # Dim gray
				]
				wall_color = colors[building_id % colors.size()]
			_:
				# Default: neutral palette
				var colors = [
					Color.html("#F5F5DC"),  # Beige
					Color.html("#E8E8E8"),  # Light gray
					Color.html("#D2B48C"),  # Tan
					Color.html("#C0C0C0"),  # Gray
				]
				wall_color = colors[building_id % colors.size()]

	material.albedo_color = wall_color

	# PBR properties for realistic lighting
	material.roughness = 0.8  # Slightly rough surface for buildings
	material.metallic = 0.0   # Non-metallic
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

## Create roof material with PBR shading
static func _create_roof_material(osm_data: Dictionary, material_lib = null) -> StandardMaterial3D:
	# Use MaterialLibrary if available
	if material_lib:
		var roof_material_name = material_lib.get_roof_material(osm_data)
		return material_lib.get_material(roof_material_name)

	# Fallback: create material manually (old way)
	var material = StandardMaterial3D.new()

	# Try to get roof color from OSM data
	var roof_color_str = osm_data.get("roof:colour", "")
	var roof_material_str = osm_data.get("roof:material", "")
	var building_type = osm_data.get("building_type", "")
	var building_id = int(osm_data.get("id", 0))
	var roof_color = Color.TRANSPARENT

	# Priority 1: Explicit OSM roof color
	if roof_color_str != "":
		roof_color = _parse_osm_color(roof_color_str)

	# Priority 2: Roof material type
	if roof_color == Color.TRANSPARENT and roof_material_str != "":
		match roof_material_str.to_lower():
			"tile", "tiles", "clay":
				roof_color = Color.html("#A0522D")  # Terracotta red-brown
			"slate":
				roof_color = Color.html("#708090")  # Slate gray
			"metal", "steel":
				roof_color = Color.html("#B0B0B0")  # Light gray metal
			"concrete":
				roof_color = Color.html("#9E9E9E")  # Concrete gray
			"wood", "shingles":
				roof_color = Color.html("#654321")  # Dark brown
			"tar", "asphalt":
				roof_color = Color.html("#2F2F2F")  # Very dark gray
			"gravel":
				roof_color = Color.html("#A9A9A9")  # Gray

	# Priority 3: Realistic roof colors (based on Google Maps observation - mostly white/grey)
	if roof_color == Color.TRANSPARENT:
		# Most modern roofs are white, light grey, or dark grey (reflective/TPO/tar)
		var realistic_roof_colors = [
			Color.html("#FFFFFF"),  # White (TPO/reflective)
			Color.html("#F5F5F5"),  # Off-white
			Color.html("#E8E8E8"),  # Very light grey
			Color.html("#D3D3D3"),  # Light grey
			Color.html("#C0C0C0"),  # Medium light grey
			Color.html("#A9A9A9"),  # Medium grey
			Color.html("#808080"),  # Grey
			Color.html("#696969"),  # Dark grey
			Color.html("#505050"),  # Darker grey
			Color.html("#3C3C3C"),  # Very dark grey (tar)
		]
		roof_color = realistic_roof_colors[building_id % realistic_roof_colors.size()]

	material.albedo_color = roof_color

	# PBR properties for realistic lighting
	material.roughness = 0.9  # Very rough for roofing materials
	material.metallic = 0.0   # Non-metallic

	return material

## Create window glass material with transparency and reflections
static func _create_window_material(osm_data: Dictionary, material_lib = null) -> ShaderMaterial:
	# Create shader material with per-vertex emission control
	var shader = load("res://shaders/window_glass.gdshader")
	var material = ShaderMaterial.new()
	material.shader = shader

	# Set base glass appearance (light blue, transparent)
	material.set_shader_parameter("albedo_color", Color(0.64, 0.71, 0.96, 0.8))
	material.set_shader_parameter("roughness", 0.1)
	material.set_shader_parameter("metallic", 0.2)

	# Set emission parameters (per-window control via vertex colors)
	var building_type = osm_data.get("building_type", "residential")
	var base_emission: Color

	# Emission color varies by building type
	match building_type:
		"residential", "house", "apartments":
			base_emission = Color(1.0, 0.85, 0.6)  # Warm orange
		"commercial", "office", "retail":
			base_emission = Color(0.85, 0.95, 1.0)  # Cool blue-white
		"industrial", "warehouse":
			base_emission = Color(1.0, 1.0, 0.95)  # Bright neutral
		_:
			base_emission = Color(1.0, 0.9, 0.75)  # Warm neutral

	material.set_shader_parameter("base_emission_color", base_emission)
	material.set_shader_parameter("emission_energy", 0.6)

	# Enable transparency and disable culling (see both sides)
	material.render_priority = 1  # Render after opaque geometry

	return material

## Create floor slab material (concrete)
static func _create_floor_material(material_lib = null) -> StandardMaterial3D:
	# Use MaterialLibrary if available
	if material_lib:
		return material_lib.get_material("concrete_gray")

	# Fallback: create material manually (old way)
	var material = StandardMaterial3D.new()

	# Concrete grey color
	material.albedo_color = Color.html("#A0A0A0")  # Medium grey concrete

	# PBR properties for concrete
	material.roughness = 0.7  # Somewhat rough
	material.metallic = 0.0   # Non-metallic

	return material

## Create window frame material with PBR shading
static func _create_frame_material(material_lib = null) -> StandardMaterial3D:
	# Use MaterialLibrary if available
	if material_lib:
		return material_lib.get_material("metal_aluminum")

	# Fallback: create material manually (old way)
	var material = StandardMaterial3D.new()

	# Dark frames for contrast
	material.albedo_color = Color.html("#424242")  # Dark gray

	# PBR properties for frame material
	material.roughness = 0.7  # Moderate roughness
	material.metallic = 0.1   # Slight metallic

	return material

## Add name label to building
static func _add_name_label(building: Node3D, building_name: String, height: float, base_elevation: float):
	var label = Label3D.new()
	label.name = "BuildingLabel"  # Name it so we can find it later for culling
	label.text = building_name
	label.position = Vector3(0, height + base_elevation + 10, 0)  # 10m above building
	label.font_size = 128  # Smaller, more readable size
	label.outline_size = 32  # Extra thick outline creates background effect
	label.modulate = Color(0.9, 0.9, 0.9)  # Light gray, easy to read
	label.outline_modulate = Color(0, 0, 0, 0.7)  # Semi-transparent black outline (background effect)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true  # Always visible through objects

	# Add slight transparency to the whole label for subtlety
	label.alpha_cut = 0  # Ensure alpha is respected
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	building.add_child(label)
