extends Node
class_name VolumetricWallBuilder

## Creates 6-faced volumetric wall geometry
## Each wall segment has: outer face, inner face, top edge, bottom edge, left edge, right edge

## Wall thickness constant (25cm realistic walls)
const WALL_THICKNESS = 0.25

## Add a volumetric wall quad with thickness (creates 6 faces)
static func add_volumetric_wall_quad(
	p1: Vector2, p2: Vector2,
	y_bottom: float, y_top: float,
	normal: Vector3,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	base_index: int,
	wall_thickness: float = WALL_THICKNESS
) -> void:
	# Calculate inward offset for inner wall face
	var thickness_offset = Vector3(normal.x * -wall_thickness, 0, normal.z * -wall_thickness)

	# Outer face vertices (visible from outside)
	var outer_v1 = Vector3(p1.x, y_bottom, -p1.y)
	var outer_v2 = Vector3(p2.x, y_bottom, -p2.y)
	var outer_v3 = Vector3(p2.x, y_top, -p2.y)
	var outer_v4 = Vector3(p1.x, y_top, -p1.y)

	# Inner face vertices (offset inward)
	var inner_v1 = outer_v1 + thickness_offset
	var inner_v2 = outer_v2 + thickness_offset
	var inner_v3 = outer_v3 + thickness_offset
	var inner_v4 = outer_v4 + thickness_offset

	var wall_width = p1.distance_to(p2)
	var wall_height = y_top - y_bottom

	# === OUTER FACE (visible from outside) ===
	vertices.append(outer_v1)
	vertices.append(outer_v2)
	vertices.append(outer_v3)
	vertices.append(outer_v4)

	for i in range(4):
		normals.append(normal)

	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(wall_width, 0))
	uvs.append(Vector2(wall_width, wall_height))
	uvs.append(Vector2(0, wall_height))

	# Outer face triangles
	indices.append(base_index + 0)
	indices.append(base_index + 1)
	indices.append(base_index + 2)
	indices.append(base_index + 0)
	indices.append(base_index + 2)
	indices.append(base_index + 3)

	# === INNER FACE (visible from inside, reversed winding) ===
	var inner_base = base_index + 4
	vertices.append(inner_v1)
	vertices.append(inner_v2)
	vertices.append(inner_v3)
	vertices.append(inner_v4)

	var inner_normal = -normal  # Flip normal for inner face
	for i in range(4):
		normals.append(inner_normal)

	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(wall_width, 0))
	uvs.append(Vector2(wall_width, wall_height))
	uvs.append(Vector2(0, wall_height))

	# Inner face triangles (reversed winding)
	indices.append(inner_base + 0)
	indices.append(inner_base + 3)
	indices.append(inner_base + 2)
	indices.append(inner_base + 0)
	indices.append(inner_base + 2)
	indices.append(inner_base + 1)

	# === TOP EDGE (connecting outer top to inner top) ===
	var top_base = base_index + 8
	vertices.append(outer_v4)  # Outer left top
	vertices.append(outer_v3)  # Outer right top
	vertices.append(inner_v3)  # Inner right top
	vertices.append(inner_v4)  # Inner left top

	var top_normal = Vector3.UP
	for i in range(4):
		normals.append(top_normal)

	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(wall_width, 0))
	uvs.append(Vector2(wall_width, wall_thickness))
	uvs.append(Vector2(0, wall_thickness))

	indices.append(top_base + 0)
	indices.append(top_base + 1)
	indices.append(top_base + 2)
	indices.append(top_base + 0)
	indices.append(top_base + 2)
	indices.append(top_base + 3)

	# === BOTTOM EDGE (connecting outer bottom to inner bottom) ===
	var bottom_base = base_index + 12
	vertices.append(outer_v1)  # Outer left bottom
	vertices.append(outer_v2)  # Outer right bottom
	vertices.append(inner_v2)  # Inner right bottom
	vertices.append(inner_v1)  # Inner left bottom

	var bottom_normal = Vector3.DOWN
	for i in range(4):
		normals.append(bottom_normal)

	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(wall_width, 0))
	uvs.append(Vector2(wall_width, wall_thickness))
	uvs.append(Vector2(0, wall_thickness))

	# Reversed winding for bottom (facing down)
	indices.append(bottom_base + 0)
	indices.append(bottom_base + 3)
	indices.append(bottom_base + 2)
	indices.append(bottom_base + 0)
	indices.append(bottom_base + 2)
	indices.append(bottom_base + 1)

	# === LEFT EDGE (connecting outer left to inner left) ===
	var left_base = base_index + 16
	var left_dir = (p2 - p1).normalized()
	var left_normal = Vector3(-left_dir.x, 0, left_dir.y)  # Perpendicular to wall, pointing left

	vertices.append(outer_v1)  # Outer bottom
	vertices.append(outer_v4)  # Outer top
	vertices.append(inner_v4)  # Inner top
	vertices.append(inner_v1)  # Inner bottom

	for i in range(4):
		normals.append(left_normal)

	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(0, wall_height))
	uvs.append(Vector2(wall_thickness, wall_height))
	uvs.append(Vector2(wall_thickness, 0))

	indices.append(left_base + 0)
	indices.append(left_base + 3)
	indices.append(left_base + 2)
	indices.append(left_base + 0)
	indices.append(left_base + 2)
	indices.append(left_base + 1)

	# === RIGHT EDGE (connecting outer right to inner right) ===
	var right_base = base_index + 20
	var right_normal = -left_normal  # Opposite of left normal

	vertices.append(outer_v2)  # Outer bottom
	vertices.append(outer_v3)  # Outer top
	vertices.append(inner_v3)  # Inner top
	vertices.append(inner_v2)  # Inner bottom

	for i in range(4):
		normals.append(right_normal)

	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(0, wall_height))
	uvs.append(Vector2(wall_thickness, wall_height))
	uvs.append(Vector2(wall_thickness, 0))

	indices.append(right_base + 0)
	indices.append(right_base + 1)
	indices.append(right_base + 2)
	indices.append(right_base + 0)
	indices.append(right_base + 2)
	indices.append(right_base + 3)

	# Total: 24 vertices (4 outer + 4 inner + 4 top + 4 bottom + 4 left + 4 right)
	# Total: 12 triangles (2 outer + 2 inner + 2 top + 2 bottom + 2 left + 2 right)
