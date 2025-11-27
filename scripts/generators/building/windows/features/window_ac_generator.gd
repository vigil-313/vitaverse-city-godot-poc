extends Node
class_name WindowACGenerator

## Window AC unit generator
## Creates air conditioning units protruding from windows

## AC unit dimensions
const AC_WIDTH = 0.6         # 60cm wide
const AC_HEIGHT = 0.4        # 40cm tall
const AC_DEPTH = 0.5         # 50cm deep (protrusion from wall)
const VENT_DEPTH = 0.02      # 2cm vent slat depth

## Main entry point - generates window AC unit
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

	# Center the AC unit in the window
	var center_t = (window_left_t + window_right_t) / 2.0
	var center_pos = p1.lerp(p2, center_t)

	# AC positioned in lower half of window
	var ac_center_y = window_bottom + (window_top - window_bottom) * 0.3

	# Wall direction for width
	var wall_dir = (p2 - p1).normalized()

	# Generate the AC unit box
	_generate_ac_box(center_pos, ac_center_y, wall_normal, wall_dir, wall_surface)

## Generate AC unit box with vent details
static func _generate_ac_box(
	center: Vector2,
	center_y: float,
	wall_normal: Vector3,
	wall_dir: Vector2,
	wall_surface
) -> void:
	var half_width = AC_WIDTH / 2.0
	var half_height = AC_HEIGHT / 2.0

	# Width offset in wall direction
	var width_offset = Vector2(wall_dir.x * half_width, wall_dir.y * half_width)

	# Corner positions (2D)
	var left_2d = Vector2(center.x - width_offset.x, center.y - width_offset.y)
	var right_2d = Vector2(center.x + width_offset.x, center.y + width_offset.y)

	# Y positions
	var bottom_y = center_y - half_height
	var top_y = center_y + half_height

	# Outward offset for front face
	var outward = Vector3(wall_normal.x * AC_DEPTH, 0, wall_normal.z * AC_DEPTH)

	# Back vertices (at wall surface, slightly in front)
	var wall_offset = Vector3(wall_normal.x * 0.02, 0, wall_normal.z * 0.02)
	var back_bl = Vector3(left_2d.x, bottom_y, -left_2d.y) + wall_offset
	var back_br = Vector3(right_2d.x, bottom_y, -right_2d.y) + wall_offset
	var back_tl = Vector3(left_2d.x, top_y, -left_2d.y) + wall_offset
	var back_tr = Vector3(right_2d.x, top_y, -right_2d.y) + wall_offset

	# Front vertices
	var front_bl = back_bl + outward
	var front_br = back_br + outward
	var front_tl = back_tl + outward
	var front_tr = back_tr + outward

	# Side normals
	var left_normal = Vector3(-wall_dir.x, 0, wall_dir.y)
	var right_normal = Vector3(wall_dir.x, 0, -wall_dir.y)

	# Generate main box faces
	_add_quad(front_bl, front_br, front_tr, front_tl, wall_normal, wall_surface)     # Front
	_add_quad(front_tl, front_tr, back_tr, back_tl, Vector3.UP, wall_surface)        # Top
	_add_quad(front_bl, front_br, back_br, back_bl, Vector3.DOWN, wall_surface)      # Bottom
	_add_quad(back_bl, back_tl, front_tl, front_bl, left_normal, wall_surface)       # Left
	_add_quad(front_br, front_tr, back_tr, back_br, right_normal, wall_surface)      # Right

	# Add vent slats on front face (horizontal lines)
	_add_vent_slats(front_bl, front_br, front_tl, front_tr, wall_normal, wall_surface)

## Add horizontal vent slats for visual detail
static func _add_vent_slats(
	bl: Vector3, br: Vector3, tl: Vector3, tr: Vector3,
	normal: Vector3,
	wall_surface
) -> void:
	var height = tl.y - bl.y
	var slat_count = 5
	var slat_height = 0.02
	var slat_offset = Vector3(normal.x * VENT_DEPTH, 0, normal.z * VENT_DEPTH)

	for i in range(1, slat_count):
		var t = float(i) / float(slat_count)
		var slat_y = bl.y + height * t

		var s_bl = Vector3(bl.x, slat_y - slat_height/2, bl.z) + slat_offset
		var s_br = Vector3(br.x, slat_y - slat_height/2, br.z) + slat_offset
		var s_tl = Vector3(bl.x, slat_y + slat_height/2, bl.z) + slat_offset
		var s_tr = Vector3(br.x, slat_y + slat_height/2, br.z) + slat_offset

		_add_quad(s_bl, s_br, s_tr, s_tl, normal, wall_surface)

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
