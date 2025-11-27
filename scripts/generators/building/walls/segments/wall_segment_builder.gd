extends Node
class_name WallSegmentBuilder

## Builds individual wall segments with window cutouts
## Handles both simple walls (no windows) and complex walls (with window openings)

const VolumetricWallBuilder = preload("res://scripts/generators/building/walls/segments/volumetric_wall_builder.gd")
const GeometryUtils = preload("res://scripts/generators/building/core/geometry_utils.gd")
const WindowSystem = preload("res://scripts/generators/building/windows/window_system.gd")

## Create a single wall segment (main entry point)
## Returns Dictionary of floor_num -> emission Color for ceiling light coordination
static func create_wall_segment(
	p1: Vector2, p2: Vector2,
	height: float,
	floor_height: float,
	levels: int,
	window_params: Dictionary,
	detailed: bool,
	wall_surface,
	glass_surface,
	frame_surface
) -> Dictionary:
	var wall_length = p1.distance_to(p2)
	var wall_normal = GeometryUtils.calculate_wall_normal(p1, p2)

	# Track floor emissions for ceiling light coordination
	var floor_emissions = {}

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
		var base_index = wall_surface.vertices.size()
		VolumetricWallBuilder.add_volumetric_wall_quad(
			p1, p2, 0.0, height, wall_normal,
			wall_surface.vertices, wall_surface.normals, wall_surface.uvs, wall_surface.indices,
			base_index
		)
	else:
		# Complex wall with window cutouts
		for floor_num in range(levels):
			var floor_bottom = floor_num * floor_height
			var floor_top = (floor_num + 1) * floor_height

			# Create wall segments around windows
			var floor_emission = _create_wall_with_windows(
				p1, p2, floor_bottom, floor_top,
				windows_per_floor, wall_normal, wall_length,
				wall_surface,
				glass_surface,
				frame_surface
			)

			# Track emission for this floor
			if floor_emission.a > 0.01:
				floor_emissions[floor_num] = floor_emission

	return floor_emissions

## Create wall quad with windows cut out
## Returns the strongest emission color from any window on this floor
static func _create_wall_with_windows(
	p1: Vector2, p2: Vector2,
	floor_bottom: float, floor_top: float,
	windows: Array,
	wall_normal: Vector3,
	wall_length: float,
	wall_surface,
	glass_surface,
	frame_surface
) -> Color:
	# Track maximum emission from any window on this floor
	var max_emission = Color.BLACK

	if windows.is_empty():
		# No windows - create full volumetric wall
		var base_index = wall_surface.vertices.size()
		VolumetricWallBuilder.add_volumetric_wall_quad(
			p1, p2, floor_bottom, floor_top, wall_normal,
			wall_surface.vertices, wall_surface.normals, wall_surface.uvs, wall_surface.indices,
			base_index
		)
		return max_emission

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

		# ALWAYS create wall segment to the left of window
		if window_left_t > prev_end_t + 0.01:
			var seg_p1 = p1.lerp(p2, prev_end_t)
			var seg_p2 = p1.lerp(p2, window_left_t)
			var base_index = wall_surface.vertices.size()
			VolumetricWallBuilder.add_volumetric_wall_quad(
				seg_p1, seg_p2, floor_bottom, floor_top, wall_normal,
				wall_surface.vertices, wall_surface.normals, wall_surface.uvs, wall_surface.indices,
				base_index
			)

		# Wall segment above window
		if window_top < floor_top - 0.01:
			var seg_p1 = p1.lerp(p2, window_left_t)
			var seg_p2 = p1.lerp(p2, window_right_t)
			var base_index = wall_surface.vertices.size()
			VolumetricWallBuilder.add_volumetric_wall_quad(
				seg_p1, seg_p2, window_top, floor_top, wall_normal,
				wall_surface.vertices, wall_surface.normals, wall_surface.uvs, wall_surface.indices,
				base_index
			)

		# Wall segment below window
		if window_bottom > floor_bottom + 0.01:
			var seg_p1 = p1.lerp(p2, window_left_t)
			var seg_p2 = p1.lerp(p2, window_right_t)
			var base_index = wall_surface.vertices.size()
			VolumetricWallBuilder.add_volumetric_wall_quad(
				seg_p1, seg_p2, floor_bottom, window_bottom, wall_normal,
				wall_surface.vertices, wall_surface.normals, wall_surface.uvs, wall_surface.indices,
				base_index
			)

		# Add complete window (reveal, glass, frame) and track emission
		var emission = WindowSystem.add_window(
			p1, p2,
			window_left_t, window_right_t,
			window_bottom, window_top,
			wall_normal,
			wall_surface,
			glass_surface,
			frame_surface
		)

		# Track maximum emission for this floor
		if emission.a > max_emission.a:
			max_emission = emission

		# Update prev_end_t for next window
		prev_end_t = window_right_t

	# ALWAYS create wall segment from last window to end of wall
	if prev_end_t < 0.99:
		var seg_p1 = p1.lerp(p2, prev_end_t)
		var seg_p2 = p2
		var base_index = wall_surface.vertices.size()
		VolumetricWallBuilder.add_volumetric_wall_quad(
			seg_p1, seg_p2, floor_bottom, floor_top, wall_normal,
			wall_surface.vertices, wall_surface.normals, wall_surface.uvs, wall_surface.indices,
			base_index
		)

	return max_emission
