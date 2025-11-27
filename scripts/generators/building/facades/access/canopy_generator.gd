extends Node
class_name CanopyGenerator

## Canopy generator for building entrances
## Creates small awnings/canopies above commercial doors

const GeometryUtils = preload("res://scripts/generators/building/core/geometry_utils.gd")

## Canopy dimensions
const CANOPY_DEPTH = 0.8       # 80cm projection from wall
const CANOPY_HEIGHT = 0.15     # 15cm thick canopy
const CANOPY_SIDE_MARGIN = 0.2 # 20cm wider than door on each side

## Main entry point - generates entrance canopy
static func generate(
	p1: Vector2, p2: Vector2,
	door_left_t: float, door_right_t: float,
	canopy_bottom_y: float,
	wall_normal: Vector3,
	wall_surface
) -> void:
	# Calculate canopy width (door width + margins)
	var left_pos = p1.lerp(p2, door_left_t)
	var right_pos = p1.lerp(p2, door_right_t)

	# Wall direction for calculating canopy extent
	var wall_dir = (p2 - p1).normalized()
	var margin_offset = wall_dir * CANOPY_SIDE_MARGIN

	# Widen the canopy
	var canopy_left = Vector2(left_pos.x - margin_offset.x, left_pos.y - margin_offset.y)
	var canopy_right = Vector2(right_pos.x + margin_offset.x, right_pos.y + margin_offset.y)

	# Outward offset for front edge
	var outward = Vector3(wall_normal.x * CANOPY_DEPTH, 0, wall_normal.z * CANOPY_DEPTH)

	# Canopy vertices
	# Back edge (against wall)
	var back_bl = Vector3(canopy_left.x, canopy_bottom_y, -canopy_left.y)
	var back_br = Vector3(canopy_right.x, canopy_bottom_y, -canopy_right.y)
	var back_tl = Vector3(canopy_left.x, canopy_bottom_y + CANOPY_HEIGHT, -canopy_left.y)
	var back_tr = Vector3(canopy_right.x, canopy_bottom_y + CANOPY_HEIGHT, -canopy_right.y)

	# Front edge (projected outward)
	var front_bl = back_bl + outward
	var front_br = back_br + outward
	var front_tl = back_tl + outward
	var front_tr = back_tr + outward

	# Side normals
	var left_normal = Vector3(-wall_dir.x, 0, wall_dir.y)
	var right_normal = Vector3(wall_dir.x, 0, -wall_dir.y)

	# Generate all faces
	_add_quad(front_tl, front_tr, back_tr, back_tl, Vector3.UP, wall_surface)     # Top
	_add_quad(front_bl, front_br, front_tr, front_tl, wall_normal, wall_surface)  # Front
	_add_quad(back_bl, back_br, front_br, front_bl, Vector3.DOWN, wall_surface)   # Bottom
	_add_quad(back_bl, back_tl, front_tl, front_bl, left_normal, wall_surface)    # Left
	_add_quad(front_br, front_tr, back_tr, back_br, right_normal, wall_surface)   # Right

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
