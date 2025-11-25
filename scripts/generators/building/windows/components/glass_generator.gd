extends Node
class_name GlassGenerator

## Generates window glass panes with emission colors

const RECESS_DEPTH = 0.15  # 15cm window recess

## Add window glass quad
static func add_window_glass(
	p1: Vector2, p2: Vector2,
	t1: float, t2: float,
	y_bottom: float, y_top: float,
	normal: Vector3,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	emission_color: Color
) -> void:
	var window_p1 = p1.lerp(p2, t1)
	var window_p2 = p1.lerp(p2, t2)

	# Recess window glass into wall (negative offset = inward)
	var offset = Vector3(normal.x * -RECESS_DEPTH, 0, normal.z * -RECESS_DEPTH)

	var v1 = Vector3(window_p1.x, y_bottom, -window_p1.y) + offset
	var v2 = Vector3(window_p2.x, y_bottom, -window_p2.y) + offset
	var v3 = Vector3(window_p2.x, y_top, -window_p2.y) + offset
	var v4 = Vector3(window_p1.x, y_top, -window_p1.y) + offset

	var base_index = vertices.size()

	vertices.append(v1)
	vertices.append(v2)
	vertices.append(v3)
	vertices.append(v4)

	for i in range(4):
		normals.append(normal)
		colors.append(emission_color)  # Vertex color encodes emission

	# Simple UVs for glass
	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(1, 0))
	uvs.append(Vector2(1, 1))
	uvs.append(Vector2(0, 1))

	indices.append(base_index + 0)
	indices.append(base_index + 1)
	indices.append(base_index + 2)

	indices.append(base_index + 0)
	indices.append(base_index + 2)
	indices.append(base_index + 3)
