extends Node
class_name BracketGenerator

## Bracket generator for balconies
## Creates triangular support brackets underneath balcony slabs

## Bracket dimensions
const BRACKET_SIZE = 0.3       # 30cm bracket size
const BRACKET_THICKNESS = 0.08 # 8cm thick
const BRACKET_INSET = 0.15     # 15cm inset from balcony edges

## Main entry point - generates support brackets under balcony
static func generate(
	left_pos: Vector2, right_pos: Vector2,
	floor_y: float,
	depth: float,
	wall_normal: Vector3,
	wall_surface
) -> void:
	# Calculate bracket positions (one on each side)
	var wall_dir = (Vector2(right_pos.x, right_pos.y) - Vector2(left_pos.x, left_pos.y)).normalized()
	var inset_offset = Vector2(wall_dir.x * BRACKET_INSET, wall_dir.y * BRACKET_INSET)

	# Left bracket position
	var left_bracket_pos = Vector2(left_pos.x + inset_offset.x, left_pos.y + inset_offset.y)

	# Right bracket position
	var right_bracket_pos = Vector2(right_pos.x - inset_offset.x, right_pos.y - inset_offset.y)

	# Generate both brackets
	_generate_bracket(left_bracket_pos, floor_y, depth, wall_normal, wall_dir, wall_surface)
	_generate_bracket(right_bracket_pos, floor_y, depth, wall_normal, wall_dir, wall_surface)

## Generate a single triangular bracket
static func _generate_bracket(
	pos: Vector2,
	floor_y: float,
	depth: float,
	wall_normal: Vector3,
	wall_dir: Vector2,
	wall_surface
) -> void:
	# Bracket sits under the balcony slab
	# Triangle shape: against wall at top, projects outward at bottom

	var bracket_top_y = floor_y
	var bracket_bottom_y = floor_y - BRACKET_SIZE

	# Outward offset (bracket extends less than full depth)
	var bracket_depth = min(BRACKET_SIZE, depth * 0.6)
	var outward = Vector3(wall_normal.x * bracket_depth, 0, wall_normal.z * bracket_depth)

	# Thickness offset perpendicular to wall
	var thickness_offset = Vector3(wall_dir.x * BRACKET_THICKNESS / 2.0, 0, -wall_dir.y * BRACKET_THICKNESS / 2.0)

	# Triangle vertices
	# Top back (against wall)
	var top_back = Vector3(pos.x, bracket_top_y, -pos.y)
	# Top front (projected out)
	var top_front = top_back + outward
	# Bottom back (against wall, below)
	var bottom_back = Vector3(pos.x, bracket_bottom_y, -pos.y)

	# Generate both sides of the bracket (with thickness)
	_add_bracket_side(top_back - thickness_offset, top_front - thickness_offset, bottom_back - thickness_offset,
		Vector3(-wall_dir.x, 0, wall_dir.y), wall_surface)
	_add_bracket_side(top_back + thickness_offset, top_front + thickness_offset, bottom_back + thickness_offset,
		Vector3(wall_dir.x, 0, -wall_dir.y), wall_surface)

	# Front face (angled)
	_add_bracket_front(
		top_front - thickness_offset, top_front + thickness_offset,
		bottom_back - thickness_offset, bottom_back + thickness_offset,
		wall_normal, wall_surface
	)

	# Bottom face
	_add_bracket_bottom(
		bottom_back - thickness_offset, bottom_back + thickness_offset,
		top_back - thickness_offset, top_back + thickness_offset,
		wall_surface
	)

## Add triangular bracket side
static func _add_bracket_side(
	top_back: Vector3, top_front: Vector3, bottom_back: Vector3,
	normal: Vector3,
	surface
) -> void:
	var base_index = surface.vertices.size()

	surface.vertices.append(bottom_back)
	surface.vertices.append(top_back)
	surface.vertices.append(top_front)

	for i in range(3):
		surface.normals.append(normal)

	surface.uvs.append(Vector2(0, 0))
	surface.uvs.append(Vector2(0, 1))
	surface.uvs.append(Vector2(1, 1))

	surface.indices.append(base_index + 0)
	surface.indices.append(base_index + 1)
	surface.indices.append(base_index + 2)

## Add front face of bracket (quad connecting front edges)
static func _add_bracket_front(
	top_left: Vector3, top_right: Vector3,
	bottom_left: Vector3, bottom_right: Vector3,
	normal: Vector3,
	surface
) -> void:
	var base_index = surface.vertices.size()

	surface.vertices.append(bottom_left)
	surface.vertices.append(bottom_right)
	surface.vertices.append(top_right)
	surface.vertices.append(top_left)

	# Calculate actual normal for angled face
	var edge1 = top_left - bottom_left
	var edge2 = bottom_right - bottom_left
	var face_normal = edge1.cross(edge2).normalized()

	for i in range(4):
		surface.normals.append(face_normal)

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

## Add bottom face of bracket
static func _add_bracket_bottom(
	front_left: Vector3, front_right: Vector3,
	back_left: Vector3, back_right: Vector3,
	surface
) -> void:
	var base_index = surface.vertices.size()

	surface.vertices.append(front_left)
	surface.vertices.append(front_right)
	surface.vertices.append(back_right)
	surface.vertices.append(back_left)

	for i in range(4):
		surface.normals.append(Vector3.DOWN)

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
