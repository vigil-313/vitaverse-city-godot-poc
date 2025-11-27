extends Node
class_name RailingGenerator

## Railing generator for balconies
## Creates classic metal railings with vertical bars

## Railing dimensions
const TOP_RAIL_SIZE = 0.05     # 5cm top rail
const BOTTOM_RAIL_SIZE = 0.03  # 3cm bottom rail
const BAR_SIZE = 0.02          # 2cm vertical bars
const BAR_SPACING = 0.12       # 12cm between bars
const BOTTOM_RAIL_HEIGHT = 0.1 # 10cm above floor

## Main entry point - generates railings on three sides of balcony
static func generate(
	left_pos: Vector2, right_pos: Vector2,
	floor_y: float,
	depth: float,
	railing_height: float,
	wall_normal: Vector3,
	frame_surface
) -> void:
	# Outward offset for front edge
	var outward = Vector3(wall_normal.x * depth, 0, wall_normal.z * depth)

	# Calculate corner positions
	var back_left = Vector3(left_pos.x, floor_y, -left_pos.y)
	var back_right = Vector3(right_pos.x, floor_y, -right_pos.y)
	var front_left = back_left + outward
	var front_right = back_right + outward

	# Generate railings on three sides (front, left, right - not back against wall)
	_generate_railing_section(front_left, front_right, floor_y, railing_height, wall_normal, frame_surface)

	# Side railings
	var wall_dir = (Vector2(right_pos.x, right_pos.y) - Vector2(left_pos.x, left_pos.y)).normalized()
	var left_normal = Vector3(-wall_dir.x, 0, wall_dir.y)
	var right_normal = Vector3(wall_dir.x, 0, -wall_dir.y)

	_generate_railing_section(back_left, front_left, floor_y, railing_height, left_normal, frame_surface)
	_generate_railing_section(front_right, back_right, floor_y, railing_height, right_normal, frame_surface)

## Generate a single railing section with top rail, bottom rail, and vertical bars
static func _generate_railing_section(
	start_pos: Vector3, end_pos: Vector3,
	floor_y: float,
	railing_height: float,
	normal: Vector3,
	frame_surface
) -> void:
	var section_length = start_pos.distance_to(end_pos)
	if section_length < 0.1:
		return

	var direction = (end_pos - start_pos).normalized()

	# Top rail position
	var top_rail_y = floor_y + railing_height
	var top_start = Vector3(start_pos.x, top_rail_y, start_pos.z)
	var top_end = Vector3(end_pos.x, top_rail_y, end_pos.z)

	# Bottom rail position
	var bottom_rail_y = floor_y + BOTTOM_RAIL_HEIGHT
	var bottom_start = Vector3(start_pos.x, bottom_rail_y, start_pos.z)
	var bottom_end = Vector3(end_pos.x, bottom_rail_y, end_pos.z)

	# Generate top rail
	_add_rail(top_start, top_end, TOP_RAIL_SIZE, normal, frame_surface)

	# Generate bottom rail
	_add_rail(bottom_start, bottom_end, BOTTOM_RAIL_SIZE, normal, frame_surface)

	# Generate vertical bars
	var num_bars = max(2, int(section_length / BAR_SPACING))
	for i in range(num_bars + 1):
		var t = float(i) / float(num_bars)
		var bar_pos = start_pos.lerp(end_pos, t)
		bar_pos.y = floor_y
		_add_vertical_bar(bar_pos, bottom_rail_y, top_rail_y, normal, frame_surface)

## Add a horizontal rail
static func _add_rail(
	start: Vector3, end: Vector3,
	size: float,
	normal: Vector3,
	frame_surface
) -> void:
	var half_size = size / 2.0
	var up_offset = Vector3(0, half_size, 0)
	var out_offset = normal * half_size

	# Front face
	var v1 = start - up_offset + out_offset
	var v2 = end - up_offset + out_offset
	var v3 = end + up_offset + out_offset
	var v4 = start + up_offset + out_offset

	_add_quad(v1, v2, v3, v4, normal, frame_surface)

	# Top face
	var t1 = start + up_offset - out_offset
	var t2 = end + up_offset - out_offset
	var t3 = end + up_offset + out_offset
	var t4 = start + up_offset + out_offset

	_add_quad(t4, t3, t2, t1, Vector3.UP, frame_surface)

## Add a vertical bar
static func _add_vertical_bar(
	pos: Vector3,
	bottom_y: float, top_y: float,
	normal: Vector3,
	frame_surface
) -> void:
	var half_size = BAR_SIZE / 2.0
	var out_offset = normal * half_size

	# Calculate perpendicular direction for bar sides
	var perp = Vector3(-normal.z, 0, normal.x) * half_size

	# Front face of bar
	var v1 = Vector3(pos.x, bottom_y, pos.z) + out_offset - perp
	var v2 = Vector3(pos.x, bottom_y, pos.z) + out_offset + perp
	var v3 = Vector3(pos.x, top_y, pos.z) + out_offset + perp
	var v4 = Vector3(pos.x, top_y, pos.z) + out_offset - perp

	_add_quad(v1, v2, v3, v4, normal, frame_surface)

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
