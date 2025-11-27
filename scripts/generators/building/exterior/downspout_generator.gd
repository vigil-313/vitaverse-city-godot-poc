extends Node
class_name DownspoutGenerator

## Downspout Generator
## Creates vertical drain pipes from gutters to ground

## Downspout dimensions
const PIPE_WIDTH = 0.08         # 8cm wide pipe
const PIPE_DEPTH = 0.06         # 6cm deep
const WALL_OFFSET = 0.02        # 2cm from wall
const BOTTOM_OFFSET = 0.1       # 10cm above ground

## Main entry point - generate downspout from roof to ground
static func generate(
	corner_pos: Vector2,
	roof_height: float,
	wall_normal: Vector3,
	surface
) -> void:
	# Offset from wall
	var outward_2d = Vector2(wall_normal.x, -wall_normal.z) * (PIPE_DEPTH / 2.0 + WALL_OFFSET)
	var pipe_center_2d = corner_pos + outward_2d

	var half_w = PIPE_WIDTH / 2.0
	var half_d = PIPE_DEPTH / 2.0

	# Pipe runs from just below gutter to near ground
	var top_y = roof_height - 0.1
	var bottom_y = BOTTOM_OFFSET

	# Get perpendicular direction for width
	var perp = Vector2(-wall_normal.z, -wall_normal.x)

	# Corner positions
	var corners_2d = [
		pipe_center_2d + perp * half_w + Vector2(wall_normal.x, -wall_normal.z) * half_d,
		pipe_center_2d - perp * half_w + Vector2(wall_normal.x, -wall_normal.z) * half_d,
		pipe_center_2d - perp * half_w - Vector2(wall_normal.x, -wall_normal.z) * half_d,
		pipe_center_2d + perp * half_w - Vector2(wall_normal.x, -wall_normal.z) * half_d,
	]

	# Front face (facing outward)
	var v_fl_b = Vector3(corners_2d[0].x, bottom_y, -corners_2d[0].y)
	var v_fr_b = Vector3(corners_2d[1].x, bottom_y, -corners_2d[1].y)
	var v_fl_t = Vector3(corners_2d[0].x, top_y, -corners_2d[0].y)
	var v_fr_t = Vector3(corners_2d[1].x, top_y, -corners_2d[1].y)

	_add_quad(v_fl_b, v_fr_b, v_fr_t, v_fl_t, wall_normal, surface)

	# Left side
	var v_bl_b = Vector3(corners_2d[3].x, bottom_y, -corners_2d[3].y)
	var v_bl_t = Vector3(corners_2d[3].x, top_y, -corners_2d[3].y)

	var left_normal = Vector3(perp.x, 0, -perp.y)
	_add_quad(v_bl_b, v_fl_b, v_fl_t, v_bl_t, left_normal, surface)

	# Right side
	var v_br_b = Vector3(corners_2d[2].x, bottom_y, -corners_2d[2].y)
	var v_br_t = Vector3(corners_2d[2].x, top_y, -corners_2d[2].y)

	var right_normal = Vector3(-perp.x, 0, perp.y)
	_add_quad(v_fr_b, v_br_b, v_br_t, v_fr_t, right_normal, surface)

	# Add mounting brackets every ~1.5m
	var bracket_spacing = 1.5
	var num_brackets = int(roof_height / bracket_spacing)

	for i in range(num_brackets):
		var bracket_y = bottom_y + bracket_spacing * (i + 0.5)
		_add_bracket(pipe_center_2d, bracket_y, wall_normal, perp, surface)

## Add a small mounting bracket
static func _add_bracket(
	center_2d: Vector2,
	y: float,
	wall_normal: Vector3,
	perp: Vector2,
	surface
) -> void:
	var bracket_size = 0.03
	var bracket_depth = PIPE_DEPTH + WALL_OFFSET + 0.02

	# Simple horizontal bracket strip
	var inner_2d = center_2d - Vector2(wall_normal.x, -wall_normal.z) * (PIPE_DEPTH / 2.0 + WALL_OFFSET)
	var outer_2d = center_2d + Vector2(wall_normal.x, -wall_normal.z) * bracket_size

	var half_w = PIPE_WIDTH * 0.6

	var v1 = Vector3(inner_2d.x - perp.x * half_w, y, -inner_2d.y + perp.y * half_w)
	var v2 = Vector3(inner_2d.x + perp.x * half_w, y, -inner_2d.y - perp.y * half_w)
	var v3 = Vector3(outer_2d.x + perp.x * half_w, y, -outer_2d.y - perp.y * half_w)
	var v4 = Vector3(outer_2d.x - perp.x * half_w, y, -outer_2d.y + perp.y * half_w)

	_add_quad(v1, v2, v3, v4, Vector3.UP, surface)

## Helper: Add a quad
static func _add_quad(
	v1: Vector3, v2: Vector3, v3: Vector3, v4: Vector3,
	normal: Vector3,
	surface
) -> void:
	var base_idx = surface.vertices.size()

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

	surface.indices.append(base_idx + 0)
	surface.indices.append(base_idx + 1)
	surface.indices.append(base_idx + 2)
	surface.indices.append(base_idx + 0)
	surface.indices.append(base_idx + 2)
	surface.indices.append(base_idx + 3)
