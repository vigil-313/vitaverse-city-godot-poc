extends Node
class_name FireEscapeStairs

## Fire Escape Stair Generator
## Creates diagonal stairs between landings

## Stair dimensions
const STAIR_WIDTH = 0.7         # 70cm wide stairs
const STRINGER_WIDTH = 0.05     # 5cm wide stringers (side rails)
const STEP_DEPTH = 0.25         # 25cm deep steps
const STEP_THICKNESS = 0.03     # 3cm thick steps
const WALL_OFFSET = 0.05        # 5cm from wall
const LANDING_DEPTH = 1.0       # Match landing depth

## Main entry point
static func generate(
	center_2d: Vector2,
	bottom_y: float,
	top_y: float,
	wall_normal: Vector3,
	wall_dir: Vector2,
	surface
) -> void:
	var height_diff = top_y - bottom_y
	var num_steps = int(height_diff / 0.2)  # ~20cm per step
	if num_steps < 2:
		return

	var step_rise = height_diff / float(num_steps)

	# Stairs offset to side of landing (zigzag pattern)
	var stair_offset = STAIR_WIDTH * 0.7

	# Depth from wall
	var depth_offset_2d = Vector2(wall_normal.x, -wall_normal.z) * (LANDING_DEPTH * 0.5 + WALL_OFFSET)

	# Stair position (offset from center)
	var stair_center_2d = center_2d + depth_offset_2d

	# Width direction
	var half_width = STAIR_WIDTH / 2.0
	var width_offset = Vector2(wall_dir.x * half_width, wall_dir.y * half_width)

	# Left and right stringer positions
	var left_2d = stair_center_2d - width_offset
	var right_2d = stair_center_2d + width_offset

	# Generate steps
	for i in range(num_steps):
		var step_y = bottom_y + step_rise * i
		var next_y = bottom_y + step_rise * (i + 1)

		# Step tread (horizontal surface)
		_add_step(left_2d, right_2d, step_y, STEP_DEPTH, surface)

	# Generate stringers (side rails)
	_add_stringer(left_2d, bottom_y, top_y, wall_dir, -1, surface)
	_add_stringer(right_2d, bottom_y, top_y, wall_dir, 1, surface)

## Add a single step
static func _add_step(
	left_2d: Vector2,
	right_2d: Vector2,
	step_y: float,
	depth: float,
	surface
) -> void:
	var step_dir = (right_2d - left_2d).normalized()
	var step_normal = Vector2(-step_dir.y, step_dir.x)
	var depth_offset = step_normal * (depth / 2.0)

	var front_left = left_2d - depth_offset
	var front_right = right_2d - depth_offset
	var back_left = left_2d + depth_offset
	var back_right = right_2d + depth_offset

	# Top surface
	var v_fl = Vector3(front_left.x, step_y, -front_left.y)
	var v_fr = Vector3(front_right.x, step_y, -front_right.y)
	var v_bl = Vector3(back_left.x, step_y, -back_left.y)
	var v_br = Vector3(back_right.x, step_y, -back_right.y)

	_add_quad(v_fl, v_fr, v_br, v_bl, Vector3.UP, surface)

	# Front edge
	var v_fl_b = Vector3(front_left.x, step_y - STEP_THICKNESS, -front_left.y)
	var v_fr_b = Vector3(front_right.x, step_y - STEP_THICKNESS, -front_right.y)

	var front_normal = Vector3(-step_normal.x, 0, step_normal.y)
	_add_quad(v_fl_b, v_fr_b, v_fr, v_fl, front_normal, surface)

## Add stringer (diagonal side rail)
static func _add_stringer(
	pos_2d: Vector2,
	bottom_y: float,
	top_y: float,
	wall_dir: Vector2,
	side: int,
	surface
) -> void:
	var half_w = STRINGER_WIDTH / 2.0
	var w_offset = Vector2(wall_dir.x * half_w * side, wall_dir.y * half_w * side)

	var inner = pos_2d
	var outer = pos_2d + w_offset * 2

	# Four corners
	var v_inner_bottom = Vector3(inner.x, bottom_y, -inner.y)
	var v_inner_top = Vector3(inner.x, top_y, -inner.y)
	var v_outer_bottom = Vector3(outer.x, bottom_y, -outer.y)
	var v_outer_top = Vector3(outer.x, top_y, -outer.y)

	# Outer face
	var outer_normal = Vector3(wall_dir.x * side, 0, -wall_dir.y * side)
	_add_quad(v_outer_bottom, v_outer_top, v_inner_top, v_inner_bottom, outer_normal, surface)

	# Top edge
	_add_quad(v_inner_top, v_outer_top, v_outer_top + Vector3(0, STRINGER_WIDTH, 0), v_inner_top + Vector3(0, STRINGER_WIDTH, 0), Vector3.UP, surface)

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
