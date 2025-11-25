extends Node
class_name RevealGenerator

## Generates window reveals (wall edges around window openings showing wall thickness)

const RECESS_DEPTH = 0.15  # 15cm window recess

## Add window reveal (4 quads: top, bottom, left, right)
static func add_window_reveal(
	p1: Vector2, p2: Vector2,
	t1: float, t2: float,
	y_bottom: float, y_top: float,
	normal: Vector3,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array
) -> void:
	var window_p1 = p1.lerp(p2, t1)
	var window_p2 = p1.lerp(p2, t2)
	var window_width = window_p1.distance_to(window_p2)
	var window_height = y_top - y_bottom

	# Outer edge (at wall outer face)
	var outer_offset = Vector3(0, 0, 0)  # At wall surface
	# Inner edge (recessed into wall)
	var inner_offset = Vector3(normal.x * -RECESS_DEPTH, 0, normal.z * -RECESS_DEPTH)

	# Outer corners
	var outer_bl = Vector3(window_p1.x, y_bottom, -window_p1.y) + outer_offset
	var outer_br = Vector3(window_p2.x, y_bottom, -window_p2.y) + outer_offset
	var outer_tr = Vector3(window_p2.x, y_top, -window_p2.y) + outer_offset
	var outer_tl = Vector3(window_p1.x, y_top, -window_p1.y) + outer_offset

	# Inner corners (recessed)
	var inner_bl = Vector3(window_p1.x, y_bottom, -window_p1.y) + inner_offset
	var inner_br = Vector3(window_p2.x, y_bottom, -window_p2.y) + inner_offset
	var inner_tr = Vector3(window_p2.x, y_top, -window_p2.y) + inner_offset
	var inner_tl = Vector3(window_p1.x, y_top, -window_p1.y) + inner_offset

	# Calculate perpendicular direction for left/right normals
	var wall_dir = (window_p2 - window_p1).normalized()
	var left_normal = Vector3(-wall_dir.x, 0, wall_dir.y)
	var right_normal = -left_normal

	# === TOP REVEAL (horizontal surface at top of window) ===
	var top_base = vertices.size()
	vertices.append(outer_tl)
	vertices.append(outer_tr)
	vertices.append(inner_tr)
	vertices.append(inner_tl)

	var top_normal = Vector3(0, 1, 0)
	for i in range(4):
		normals.append(top_normal)

	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(window_width, 0))
	uvs.append(Vector2(window_width, RECESS_DEPTH))
	uvs.append(Vector2(0, RECESS_DEPTH))

	indices.append(top_base + 0)
	indices.append(top_base + 3)
	indices.append(top_base + 2)
	indices.append(top_base + 0)
	indices.append(top_base + 2)
	indices.append(top_base + 1)

	# === BOTTOM REVEAL (horizontal surface at bottom of window) ===
	var bottom_base = vertices.size()
	vertices.append(outer_bl)
	vertices.append(outer_br)
	vertices.append(inner_br)
	vertices.append(inner_bl)

	var bottom_normal = Vector3(0, -1, 0)
	for i in range(4):
		normals.append(bottom_normal)

	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(window_width, 0))
	uvs.append(Vector2(window_width, RECESS_DEPTH))
	uvs.append(Vector2(0, RECESS_DEPTH))

	indices.append(bottom_base + 0)
	indices.append(bottom_base + 1)
	indices.append(bottom_base + 2)
	indices.append(bottom_base + 0)
	indices.append(bottom_base + 2)
	indices.append(bottom_base + 3)

	# === LEFT REVEAL (vertical surface on left side) ===
	var left_base = vertices.size()
	vertices.append(outer_bl)
	vertices.append(outer_tl)
	vertices.append(inner_tl)
	vertices.append(inner_bl)

	for i in range(4):
		normals.append(left_normal)

	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(0, window_height))
	uvs.append(Vector2(RECESS_DEPTH, window_height))
	uvs.append(Vector2(RECESS_DEPTH, 0))

	indices.append(left_base + 0)
	indices.append(left_base + 3)
	indices.append(left_base + 2)
	indices.append(left_base + 0)
	indices.append(left_base + 2)
	indices.append(left_base + 1)

	# === RIGHT REVEAL (vertical surface on right side) ===
	var right_base = vertices.size()
	vertices.append(outer_br)
	vertices.append(outer_tr)
	vertices.append(inner_tr)
	vertices.append(inner_br)

	for i in range(4):
		normals.append(right_normal)

	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(0, window_height))
	uvs.append(Vector2(RECESS_DEPTH, window_height))
	uvs.append(Vector2(RECESS_DEPTH, 0))

	indices.append(right_base + 0)
	indices.append(right_base + 1)
	indices.append(right_base + 2)
	indices.append(right_base + 0)
	indices.append(right_base + 2)
	indices.append(right_base + 3)

	# Total: 16 vertices (4 per reveal quad)
	# Total: 8 triangles (2 per reveal quad)
