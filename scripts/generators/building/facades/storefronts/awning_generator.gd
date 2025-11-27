extends Node
class_name AwningGenerator

## Awning generator for commercial storefronts
## Creates triangular profile awnings that project from the wall

const GeometryUtils = preload("res://scripts/generators/building/core/geometry_utils.gd")

## Awning dimensions
const AWNING_DEPTH = 0.9       # 90cm projection from wall
const AWNING_HEIGHT = 0.35     # 35cm vertical drop
const AWNING_THICKNESS = 0.03  # 3cm material thickness

## Awning colors (fabric-like)
const AWNING_COLORS = [
	Color(0.7, 0.15, 0.15),  # Deep red
	Color(0.15, 0.45, 0.2),  # Forest green
	Color(0.15, 0.25, 0.5),  # Navy blue
	Color(0.8, 0.45, 0.1),   # Orange/rust
	Color(0.5, 0.3, 0.15),   # Brown
	Color(0.2, 0.2, 0.2),    # Dark gray
]

## Main entry point - generates an awning above a window
static func generate(
	p1: Vector2, p2: Vector2,
	awning_left_t: float, awning_right_t: float,
	awning_bottom_y: float,
	wall_normal: Vector3,
	wall_surface
) -> void:
	# Calculate awning positions
	var left_pos = p1.lerp(p2, awning_left_t)
	var right_pos = p1.lerp(p2, awning_right_t)
	var width = left_pos.distance_to(right_pos)

	# Wall attachment point (top of awning, against wall)
	var attach_y = awning_bottom_y + AWNING_HEIGHT

	# Outward offset for front edge
	var outward_offset = Vector3(wall_normal.x * AWNING_DEPTH, 0, wall_normal.z * AWNING_DEPTH)

	# Vertices at wall (back edge)
	var back_left_top = Vector3(left_pos.x, attach_y, -left_pos.y)
	var back_right_top = Vector3(right_pos.x, attach_y, -right_pos.y)
	var back_left_bottom = Vector3(left_pos.x, attach_y - AWNING_THICKNESS, -left_pos.y)
	var back_right_bottom = Vector3(right_pos.x, attach_y - AWNING_THICKNESS, -right_pos.y)

	# Vertices at front edge (projected outward and down)
	var front_left_top = back_left_top + outward_offset + Vector3(0, -AWNING_HEIGHT + AWNING_THICKNESS, 0)
	var front_right_top = back_right_top + outward_offset + Vector3(0, -AWNING_HEIGHT + AWNING_THICKNESS, 0)
	var front_left_bottom = front_left_top + Vector3(0, -AWNING_THICKNESS, 0)
	var front_right_bottom = front_right_top + Vector3(0, -AWNING_THICKNESS, 0)

	# Pick a random awning color (seeded by position for consistency)
	var color_seed = int(abs(left_pos.x * 100 + left_pos.y * 1000)) % AWNING_COLORS.size()
	var awning_color = AWNING_COLORS[color_seed]

	# Generate all faces
	_add_top_face(back_left_top, back_right_top, front_right_top, front_left_top, wall_surface)
	_add_bottom_face(back_left_bottom, back_right_bottom, front_right_bottom, front_left_bottom, wall_surface)
	_add_front_face(front_left_top, front_right_top, front_right_bottom, front_left_bottom, wall_normal, wall_surface)
	_add_left_end_cap(back_left_top, back_left_bottom, front_left_top, front_left_bottom, p1, p2, wall_surface)
	_add_right_end_cap(back_right_top, back_right_bottom, front_right_top, front_right_bottom, p1, p2, wall_surface)

## Add top face (angled roof of awning)
static func _add_top_face(
	back_left: Vector3, back_right: Vector3,
	front_right: Vector3, front_left: Vector3,
	surface
) -> void:
	# Calculate normal for angled top surface
	var edge1 = front_left - back_left
	var edge2 = back_right - back_left
	var normal = edge1.cross(edge2).normalized()

	var base_index = surface.vertices.size()

	surface.vertices.append(back_left)
	surface.vertices.append(back_right)
	surface.vertices.append(front_right)
	surface.vertices.append(front_left)

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

## Add bottom face (underside of awning)
static func _add_bottom_face(
	back_left: Vector3, back_right: Vector3,
	front_right: Vector3, front_left: Vector3,
	surface
) -> void:
	# Calculate normal for angled bottom surface (flipped)
	var edge1 = front_left - back_left
	var edge2 = back_right - back_left
	var normal = -edge1.cross(edge2).normalized()

	var base_index = surface.vertices.size()

	# Reverse winding for bottom face
	surface.vertices.append(back_left)
	surface.vertices.append(front_left)
	surface.vertices.append(front_right)
	surface.vertices.append(back_right)

	for i in range(4):
		surface.normals.append(normal)

	surface.uvs.append(Vector2(0, 0))
	surface.uvs.append(Vector2(0, 1))
	surface.uvs.append(Vector2(1, 1))
	surface.uvs.append(Vector2(1, 0))

	surface.indices.append(base_index + 0)
	surface.indices.append(base_index + 1)
	surface.indices.append(base_index + 2)
	surface.indices.append(base_index + 0)
	surface.indices.append(base_index + 2)
	surface.indices.append(base_index + 3)

## Add front face (vertical front edge)
static func _add_front_face(
	top_left: Vector3, top_right: Vector3,
	bottom_right: Vector3, bottom_left: Vector3,
	wall_normal: Vector3,
	surface
) -> void:
	var base_index = surface.vertices.size()

	surface.vertices.append(bottom_left)
	surface.vertices.append(bottom_right)
	surface.vertices.append(top_right)
	surface.vertices.append(top_left)

	for i in range(4):
		surface.normals.append(wall_normal)

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

## Add left end cap (triangular-ish side)
static func _add_left_end_cap(
	back_top: Vector3, back_bottom: Vector3,
	front_top: Vector3, front_bottom: Vector3,
	p1: Vector2, p2: Vector2,
	surface
) -> void:
	var wall_dir = (p2 - p1).normalized()
	var normal = Vector3(-wall_dir.x, 0, wall_dir.y)  # Pointing left

	var base_index = surface.vertices.size()

	# Quadrilateral side (simplified from true triangular profile)
	surface.vertices.append(back_bottom)
	surface.vertices.append(back_top)
	surface.vertices.append(front_top)
	surface.vertices.append(front_bottom)

	for i in range(4):
		surface.normals.append(normal)

	surface.uvs.append(Vector2(0, 0))
	surface.uvs.append(Vector2(0, 1))
	surface.uvs.append(Vector2(1, 1))
	surface.uvs.append(Vector2(1, 0))

	surface.indices.append(base_index + 0)
	surface.indices.append(base_index + 1)
	surface.indices.append(base_index + 2)
	surface.indices.append(base_index + 0)
	surface.indices.append(base_index + 2)
	surface.indices.append(base_index + 3)

## Add right end cap
static func _add_right_end_cap(
	back_top: Vector3, back_bottom: Vector3,
	front_top: Vector3, front_bottom: Vector3,
	p1: Vector2, p2: Vector2,
	surface
) -> void:
	var wall_dir = (p2 - p1).normalized()
	var normal = Vector3(wall_dir.x, 0, -wall_dir.y)  # Pointing right

	var base_index = surface.vertices.size()

	# Reverse winding for right side
	surface.vertices.append(back_bottom)
	surface.vertices.append(front_bottom)
	surface.vertices.append(front_top)
	surface.vertices.append(back_top)

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
