extends Node
class_name ShutterGenerator

## Window shutter generator
## Creates decorative shutters on either side of windows

## Shutter dimensions
const SHUTTER_WIDTH = 0.25     # 25cm wide shutters
const SHUTTER_THICKNESS = 0.04 # 4cm thick
const SHUTTER_GAP = 0.02       # 2cm gap from window edge

## Shutter colors (traditional colors)
const SHUTTER_COLORS = [
	Color(0.15, 0.25, 0.15),  # Dark green
	Color(0.2, 0.2, 0.3),     # Dark blue-gray
	Color(0.35, 0.2, 0.15),   # Brown
	Color(0.25, 0.25, 0.25),  # Charcoal
	Color(0.5, 0.15, 0.15),   # Burgundy
]

## Main entry point - generates shutters on both sides of window
static func generate(
	p1: Vector2, p2: Vector2,
	window_left_t: float, window_right_t: float,
	window_bottom: float, window_top: float,
	wall_normal: Vector3,
	wall_surface
) -> void:
	var left_pos = p1.lerp(p2, window_left_t)
	var right_pos = p1.lerp(p2, window_right_t)
	var window_width = left_pos.distance_to(right_pos)

	# Wall direction for positioning shutters
	var wall_dir = (p2 - p1).normalized()

	# Shutter positions (outside window edges)
	var shutter_offset = SHUTTER_GAP + SHUTTER_WIDTH / 2.0

	# Left shutter position
	var left_shutter_center = Vector2(
		left_pos.x - wall_dir.x * shutter_offset,
		left_pos.y - wall_dir.y * shutter_offset
	)

	# Right shutter position
	var right_shutter_center = Vector2(
		right_pos.x + wall_dir.x * shutter_offset,
		right_pos.y + wall_dir.y * shutter_offset
	)

	# Generate both shutters
	_generate_shutter(left_shutter_center, window_bottom, window_top, wall_normal, wall_dir, wall_surface)
	_generate_shutter(right_shutter_center, window_bottom, window_top, wall_normal, wall_dir, wall_surface)

## Generate a single shutter panel
static func _generate_shutter(
	center: Vector2,
	bottom_y: float, top_y: float,
	wall_normal: Vector3,
	wall_dir: Vector2,
	wall_surface
) -> void:
	# Slight offset from wall surface
	var outward = Vector3(wall_normal.x * SHUTTER_THICKNESS, 0, wall_normal.z * SHUTTER_THICKNESS)

	# Half width in wall direction
	var half_width = SHUTTER_WIDTH / 2.0
	var width_offset = Vector2(wall_dir.x * half_width, wall_dir.y * half_width)

	# Shutter corners
	var left_2d = Vector2(center.x - width_offset.x, center.y - width_offset.y)
	var right_2d = Vector2(center.x + width_offset.x, center.y + width_offset.y)

	var bl = Vector3(left_2d.x, bottom_y, -left_2d.y) + outward
	var br = Vector3(right_2d.x, bottom_y, -right_2d.y) + outward
	var tl = Vector3(left_2d.x, top_y, -left_2d.y) + outward
	var tr = Vector3(right_2d.x, top_y, -right_2d.y) + outward

	# Front face of shutter
	_add_quad(bl, br, tr, tl, wall_normal, wall_surface)

	# Add horizontal slat lines for visual detail (3 slats)
	var slat_height = 0.03
	var slat_spacing = (top_y - bottom_y) / 4.0

	for i in range(1, 4):
		var slat_y = bottom_y + slat_spacing * i
		var slat_bottom = slat_y - slat_height / 2.0
		var slat_top = slat_y + slat_height / 2.0

		var slat_outward = outward + Vector3(wall_normal.x * 0.01, 0, wall_normal.z * 0.01)

		var s_bl = Vector3(left_2d.x, slat_bottom, -left_2d.y) + slat_outward
		var s_br = Vector3(right_2d.x, slat_bottom, -right_2d.y) + slat_outward
		var s_tl = Vector3(left_2d.x, slat_top, -left_2d.y) + slat_outward
		var s_tr = Vector3(right_2d.x, slat_top, -right_2d.y) + slat_outward

		_add_quad(s_bl, s_br, s_tr, s_tl, wall_normal, wall_surface)

## Helper: Add a quad
static func _add_quad(
	v1: Vector3, v2: Vector3, v3: Vector3, v4: Vector3,
	normal: Vector3,
	surface
) -> void:
	var base_index = surface.vertices.size()

	surface.vertices.append(v1)
	surface.vertices.append(v2)
	surface.vertices.append(v3)
	surface.vertices.append(v4)

	for i in range(4):
		surface.normals.append(normal)

	surface.uvs.append(Vector2(0, 0))
	surface.uvs.append(Vector2(1, 0))
	surface.uvs.append(Vector2(1, 1))
	surface.uvs.append(Vector2(0, 1))

	surface.indices.append(base_index + 0)
	surface.indices.append(base_index + 1)
	surface.indices.append(base_index + 2)
	surface.indices.append(base_index + 0)
	surface.indices.append(base_index + 2)
	surface.indices.append(base_index + 3)
