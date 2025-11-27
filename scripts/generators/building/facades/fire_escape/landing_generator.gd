extends Node
class_name FireEscapeLanding

## Fire Escape Landing Generator
## Creates horizontal platforms at each floor level

## Landing dimensions
const LANDING_WIDTH = 1.2       # 1.2m wide
const LANDING_DEPTH = 1.0       # 1.0m from wall
const PLATFORM_THICKNESS = 0.05 # 5cm thick grating
const WALL_OFFSET = 0.05        # 5cm from wall

## Main entry point
static func generate(
	center_2d: Vector2,
	floor_y: float,
	wall_normal: Vector3,
	wall_dir: Vector2,
	surface
) -> void:
	var half_width = LANDING_WIDTH / 2.0

	# Wall direction offset
	var width_offset = Vector2(wall_dir.x * half_width, wall_dir.y * half_width)

	# Depth offset (away from wall)
	var depth_offset_2d = Vector2(wall_normal.x, -wall_normal.z) * (LANDING_DEPTH + WALL_OFFSET)

	# Corner positions (2D)
	var inner_left = center_2d - width_offset
	var inner_right = center_2d + width_offset
	var outer_left = inner_left + depth_offset_2d
	var outer_right = inner_right + depth_offset_2d

	# Convert to 3D at floor height
	var v_inner_left = Vector3(inner_left.x, floor_y, -inner_left.y)
	var v_inner_right = Vector3(inner_right.x, floor_y, -inner_right.y)
	var v_outer_left = Vector3(outer_left.x, floor_y, -outer_left.y)
	var v_outer_right = Vector3(outer_right.x, floor_y, -outer_right.y)

	# Platform top surface
	_add_quad(
		v_inner_left, v_inner_right, v_outer_right, v_outer_left,
		Vector3.UP, surface
	)

	# Platform bottom surface
	var bottom_y = floor_y - PLATFORM_THICKNESS
	var v_inner_left_b = Vector3(inner_left.x, bottom_y, -inner_left.y)
	var v_inner_right_b = Vector3(inner_right.x, bottom_y, -inner_right.y)
	var v_outer_left_b = Vector3(outer_left.x, bottom_y, -outer_left.y)
	var v_outer_right_b = Vector3(outer_right.x, bottom_y, -outer_right.y)

	_add_quad(
		v_inner_left_b, v_outer_left_b, v_outer_right_b, v_inner_right_b,
		Vector3.DOWN, surface
	)

	# Front edge
	_add_quad(
		v_outer_left_b, v_outer_left, v_outer_right, v_outer_right_b,
		wall_normal, surface
	)

	# Side edges
	var left_normal = Vector3(-wall_dir.x, 0, wall_dir.y)
	var right_normal = Vector3(wall_dir.x, 0, -wall_dir.y)

	_add_quad(
		v_inner_left_b, v_inner_left, v_outer_left, v_outer_left_b,
		left_normal, surface
	)

	_add_quad(
		v_outer_right_b, v_outer_right, v_inner_right, v_inner_right_b,
		right_normal, surface
	)

	# Support brackets (two diagonal supports)
	_add_support_bracket(center_2d, floor_y, wall_normal, wall_dir, -0.4, surface)
	_add_support_bracket(center_2d, floor_y, wall_normal, wall_dir, 0.4, surface)

## Add diagonal support bracket
static func _add_support_bracket(
	center_2d: Vector2,
	floor_y: float,
	wall_normal: Vector3,
	wall_dir: Vector2,
	side_offset: float,
	surface
) -> void:
	var bracket_width = 0.05
	var bracket_drop = 0.4  # How far down the bracket goes

	# Position along wall
	var pos_2d = center_2d + Vector2(wall_dir.x * side_offset, wall_dir.y * side_offset)

	# Outward position
	var outward_2d = Vector2(wall_normal.x, -wall_normal.z) * (LANDING_DEPTH * 0.8 + WALL_OFFSET)

	# Vertices
	var wall_top = Vector3(pos_2d.x, floor_y - PLATFORM_THICKNESS, -pos_2d.y)
	var wall_bottom = Vector3(pos_2d.x, floor_y - PLATFORM_THICKNESS - bracket_drop, -pos_2d.y)
	var outer_pos_2d = pos_2d + outward_2d
	var outer_top = Vector3(outer_pos_2d.x, floor_y - PLATFORM_THICKNESS, -outer_pos_2d.y)

	# Triangle bracket (simplified as thin quad)
	_add_bracket_face(wall_top, wall_bottom, outer_top, wall_normal, wall_dir, bracket_width, surface)

## Add bracket face
static func _add_bracket_face(
	wall_top: Vector3,
	wall_bottom: Vector3,
	outer_top: Vector3,
	wall_normal: Vector3,
	wall_dir: Vector2,
	width: float,
	surface
) -> void:
	var half_w = width / 2.0
	var w_offset = Vector3(wall_dir.x * half_w, 0, -wall_dir.y * half_w)

	# Front face
	var base_idx = surface.vertices.size()

	surface.vertices.append(wall_bottom - w_offset)
	surface.vertices.append(wall_bottom + w_offset)
	surface.vertices.append(wall_top + w_offset)
	surface.vertices.append(outer_top + w_offset)

	for i in range(4):
		surface.normals.append(wall_normal)

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
