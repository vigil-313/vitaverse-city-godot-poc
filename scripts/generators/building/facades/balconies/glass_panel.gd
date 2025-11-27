extends Node
class_name GlassPanel

## Glass panel generator for modern balconies
## Creates glass balustrade with metal frame

## Panel dimensions
const FRAME_SIZE = 0.04       # 4cm frame thickness
const GLASS_INSET = 0.02      # 2cm glass inset from frame
const BOTTOM_GAP = 0.05       # 5cm gap above floor

## Main entry point - generates glass panels on three sides of balcony
static func generate(
	left_pos: Vector2, right_pos: Vector2,
	floor_y: float,
	depth: float,
	railing_height: float,
	wall_normal: Vector3,
	glass_surface,
	frame_surface
) -> void:
	# Outward offset for front edge
	var outward = Vector3(wall_normal.x * depth, 0, wall_normal.z * depth)

	# Calculate corner positions
	var back_left = Vector3(left_pos.x, floor_y, -left_pos.y)
	var back_right = Vector3(right_pos.x, floor_y, -right_pos.y)
	var front_left = back_left + outward
	var front_right = back_right + outward

	# Generate panels on three sides
	_generate_panel_section(front_left, front_right, floor_y, railing_height, wall_normal, glass_surface, frame_surface)

	# Side panels
	var wall_dir = (Vector2(right_pos.x, right_pos.y) - Vector2(left_pos.x, left_pos.y)).normalized()
	var left_normal = Vector3(-wall_dir.x, 0, wall_dir.y)
	var right_normal = Vector3(wall_dir.x, 0, -wall_dir.y)

	_generate_panel_section(back_left, front_left, floor_y, railing_height, left_normal, glass_surface, frame_surface)
	_generate_panel_section(front_right, back_right, floor_y, railing_height, right_normal, glass_surface, frame_surface)

## Generate a single glass panel section with frame
static func _generate_panel_section(
	start_pos: Vector3, end_pos: Vector3,
	floor_y: float,
	railing_height: float,
	normal: Vector3,
	glass_surface,
	frame_surface
) -> void:
	var section_length = start_pos.distance_to(end_pos)
	if section_length < 0.2:
		return

	var panel_bottom = floor_y + BOTTOM_GAP
	var panel_top = floor_y + railing_height

	# Frame offset (slightly in front of glass)
	var frame_offset = normal * (FRAME_SIZE / 2.0)
	var glass_offset = normal * GLASS_INSET

	# Generate frame (top, bottom, sides)
	_add_frame_rail(start_pos, end_pos, panel_top, FRAME_SIZE, normal, frame_surface)
	_add_frame_rail(start_pos, end_pos, panel_bottom, FRAME_SIZE, normal, frame_surface)

	# Generate glass panel
	var glass_start = Vector3(start_pos.x, panel_bottom + FRAME_SIZE, start_pos.z) + glass_offset
	var glass_end = Vector3(end_pos.x, panel_bottom + FRAME_SIZE, end_pos.z) + glass_offset
	var glass_top = panel_top - FRAME_SIZE

	_add_glass_panel(glass_start, glass_end, glass_top, normal, glass_surface)

## Add horizontal frame rail
static func _add_frame_rail(
	start: Vector3, end: Vector3,
	y_pos: float,
	size: float,
	normal: Vector3,
	frame_surface
) -> void:
	var half_size = size / 2.0
	var out_offset = normal * half_size

	# Rail at y_pos
	var v1 = Vector3(start.x, y_pos - half_size, start.z) + out_offset
	var v2 = Vector3(end.x, y_pos - half_size, end.z) + out_offset
	var v3 = Vector3(end.x, y_pos + half_size, end.z) + out_offset
	var v4 = Vector3(start.x, y_pos + half_size, start.z) + out_offset

	_add_quad(v1, v2, v3, v4, normal, frame_surface)

## Add glass panel
static func _add_glass_panel(
	start: Vector3, end: Vector3,
	top_y: float,
	normal: Vector3,
	glass_surface
) -> void:
	var v1 = start
	var v2 = end
	var v3 = Vector3(end.x, top_y, end.z)
	var v4 = Vector3(start.x, top_y, start.z)

	var base_index = glass_surface.vertices.size()

	glass_surface.vertices.append(v1)
	glass_surface.vertices.append(v2)
	glass_surface.vertices.append(v3)
	glass_surface.vertices.append(v4)

	# Slight blue tint for glass, low emission
	var glass_color = Color(0.7, 0.8, 0.9, 0.3)
	for i in range(4):
		glass_surface.normals.append(normal)
		glass_surface.colors.append(glass_color)

	glass_surface.uvs.append(Vector2(0, 0))
	glass_surface.uvs.append(Vector2(1, 0))
	glass_surface.uvs.append(Vector2(1, 1))
	glass_surface.uvs.append(Vector2(0, 1))

	glass_surface.indices.append(base_index + 0)
	glass_surface.indices.append(base_index + 1)
	glass_surface.indices.append(base_index + 2)
	glass_surface.indices.append(base_index + 0)
	glass_surface.indices.append(base_index + 2)
	glass_surface.indices.append(base_index + 3)

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
