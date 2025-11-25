extends Node
class_name FrameGenerator

## Generates window frames (4 pieces: left, right, top, bottom)

const RECESS_DEPTH = 0.15  # 15cm window recess
const FRAME_THICKNESS = 0.08  # 8cm frame thickness

## Add window frame (4 pieces)
static func add_window_frame(
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

	var frame_depth = RECESS_DEPTH  # Frame at window recess depth

	# Get tangent vector along wall
	var wall_tangent = (window_p2 - window_p1).normalized()
	var tangent_3d = Vector3(wall_tangent.x, 0, -wall_tangent.y)

	# Left frame (vertical)
	_add_frame_piece(window_p1, window_p1, y_bottom, y_top, FRAME_THICKNESS, frame_depth, normal, tangent_3d, true, vertices, normals, uvs, indices)

	# Right frame (vertical)
	var right_offset = wall_tangent * (window_width - FRAME_THICKNESS)
	var right_p1 = window_p1 + right_offset
	_add_frame_piece(right_p1, right_p1, y_bottom, y_top, FRAME_THICKNESS, frame_depth, normal, tangent_3d, true, vertices, normals, uvs, indices)

	# Top frame (horizontal)
	_add_frame_piece(window_p1, window_p2, y_top - FRAME_THICKNESS, y_top, window_width, frame_depth, normal, tangent_3d, false, vertices, normals, uvs, indices)

	# Bottom frame (horizontal)
	_add_frame_piece(window_p1, window_p2, y_bottom, y_bottom + FRAME_THICKNESS, window_width, frame_depth, normal, tangent_3d, false, vertices, normals, uvs, indices)

## Add a single piece of window frame
static func _add_frame_piece(
	p1: Vector2, p2: Vector2,
	y_bottom: float, y_top: float,
	width: float, _depth: float,
	normal: Vector3, tangent: Vector3,
	is_vertical: bool,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array
) -> void:
	# Simple frame quad at wall surface level
	var offset = Vector3(normal.x * 0.02, 0, normal.z * 0.02)  # Slightly recessed

	var base_index = vertices.size()
	var v1 = Vector3(p1.x, y_bottom, -p1.y) + offset
	var v2: Vector3
	if is_vertical:
		v2 = Vector3(p1.x, y_bottom, -p1.y) + offset + tangent * width
	else:
		v2 = Vector3(p2.x, y_bottom, -p2.y) + offset
	var v3 = v2 + Vector3(0, y_top - y_bottom, 0)
	var v4 = v1 + Vector3(0, y_top - y_bottom, 0)

	vertices.append(v1)
	vertices.append(v2)
	vertices.append(v3)
	vertices.append(v4)

	for i in range(4):
		normals.append(normal)

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
