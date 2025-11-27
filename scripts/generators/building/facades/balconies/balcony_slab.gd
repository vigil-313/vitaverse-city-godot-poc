extends Node
class_name BalconySlab

## Balcony slab generator
## Creates the floor slab that protrudes from the building

## Main entry point - generates balcony floor slab
static func generate(
	left_pos: Vector2, right_pos: Vector2,
	floor_y: float,
	depth: float,
	thickness: float,
	wall_normal: Vector3,
	wall_surface
) -> void:
	# Outward offset for front edge
	var outward = Vector3(wall_normal.x * depth, 0, wall_normal.z * depth)

	# Slab corners - back edge (against wall)
	var back_bl = Vector3(left_pos.x, floor_y, -left_pos.y)
	var back_br = Vector3(right_pos.x, floor_y, -right_pos.y)
	var back_tl = Vector3(left_pos.x, floor_y + thickness, -left_pos.y)
	var back_tr = Vector3(right_pos.x, floor_y + thickness, -right_pos.y)

	# Front edge (projected outward)
	var front_bl = back_bl + outward
	var front_br = back_br + outward
	var front_tl = back_tl + outward
	var front_tr = back_tr + outward

	# Calculate side normals
	var wall_dir = (Vector2(right_pos.x, right_pos.y) - Vector2(left_pos.x, left_pos.y)).normalized()
	var left_normal = Vector3(-wall_dir.x, 0, wall_dir.y)
	var right_normal = Vector3(wall_dir.x, 0, -wall_dir.y)

	# Generate all faces
	_add_quad(front_tl, front_tr, back_tr, back_tl, Vector3.UP, wall_surface)      # Top (floor surface)
	_add_quad(front_bl, front_br, front_tr, front_tl, wall_normal, wall_surface)   # Front
	_add_quad(back_bl, back_br, front_br, front_bl, Vector3.DOWN, wall_surface)    # Bottom
	_add_quad(back_bl, back_tl, front_tl, front_bl, left_normal, wall_surface)     # Left
	_add_quad(front_br, front_tr, back_tr, back_br, right_normal, wall_surface)    # Right

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
