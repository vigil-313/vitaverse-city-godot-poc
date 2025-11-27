extends Node
class_name GutterGenerator

## Gutter Generator
## Creates rain gutters along roof edges

## Gutter dimensions
const GUTTER_WIDTH = 0.12       # 12cm wide
const GUTTER_HEIGHT = 0.08      # 8cm tall
const GUTTER_OFFSET = 0.02      # 2cm below roof edge
const WALL_OFFSET = 0.01        # 1cm from wall

## Main entry point - generate gutter along a wall edge
static func generate(
	p1: Vector2,
	p2: Vector2,
	roof_height: float,
	wall_normal: Vector3,
	surface
) -> void:
	var wall_length = p1.distance_to(p2)
	if wall_length < 0.5:
		return

	var wall_dir = (p2 - p1).normalized()

	# Gutter position (slightly in front of wall, below roof)
	var gutter_y = roof_height - GUTTER_OFFSET
	var outward_2d = Vector2(wall_normal.x, -wall_normal.z) * (GUTTER_WIDTH / 2.0 + WALL_OFFSET)

	# Gutter outer edge positions
	var outer_p1 = p1 + outward_2d
	var outer_p2 = p2 + outward_2d

	# Inner edge (against wall)
	var inner_p1 = p1 + Vector2(wall_normal.x, -wall_normal.z) * WALL_OFFSET
	var inner_p2 = p2 + Vector2(wall_normal.x, -wall_normal.z) * WALL_OFFSET

	# Convert to 3D
	var v_inner_1_top = Vector3(inner_p1.x, gutter_y, -inner_p1.y)
	var v_inner_2_top = Vector3(inner_p2.x, gutter_y, -inner_p2.y)
	var v_outer_1_top = Vector3(outer_p1.x, gutter_y, -outer_p1.y)
	var v_outer_2_top = Vector3(outer_p2.x, gutter_y, -outer_p2.y)

	var v_outer_1_bottom = Vector3(outer_p1.x, gutter_y - GUTTER_HEIGHT, -outer_p1.y)
	var v_outer_2_bottom = Vector3(outer_p2.x, gutter_y - GUTTER_HEIGHT, -outer_p2.y)

	# Front face (outer)
	_add_quad(v_outer_1_bottom, v_outer_2_bottom, v_outer_2_top, v_outer_1_top, wall_normal, surface)

	# Top face
	_add_quad(v_inner_1_top, v_inner_2_top, v_outer_2_top, v_outer_1_top, Vector3.UP, surface)

	# Bottom face
	_add_quad(v_outer_1_bottom, v_outer_2_bottom, v_inner_2_top + Vector3(0, -GUTTER_HEIGHT, 0), v_inner_1_top + Vector3(0, -GUTTER_HEIGHT, 0), Vector3.DOWN, surface)

	# End caps
	var left_normal = Vector3(-wall_dir.x, 0, wall_dir.y)
	var right_normal = Vector3(wall_dir.x, 0, -wall_dir.y)

	_add_quad(
		v_inner_1_top + Vector3(0, -GUTTER_HEIGHT, 0),
		v_outer_1_bottom,
		v_outer_1_top,
		v_inner_1_top,
		left_normal, surface
	)

	_add_quad(
		v_inner_2_top,
		v_outer_2_top,
		v_outer_2_bottom,
		v_inner_2_top + Vector3(0, -GUTTER_HEIGHT, 0),
		right_normal, surface
	)

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
