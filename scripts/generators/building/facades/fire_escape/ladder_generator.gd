extends Node
class_name FireEscapeLadder

## Fire Escape Ladder Generator
## Creates the drop-down ladder at the bottom of fire escapes

## Ladder dimensions
const LADDER_WIDTH = 0.5        # 50cm wide
const RUNG_SPACING = 0.3        # 30cm between rungs
const RAIL_WIDTH = 0.04         # 4cm rail width
const RUNG_DIAMETER = 0.025     # 2.5cm rung diameter
const LADDER_DROP = 2.0         # 2m ladder extends down

## Main entry point
static func generate(
	center_2d: Vector2,
	top_y: float,
	wall_normal: Vector3,
	wall_dir: Vector2,
	surface
) -> void:
	var bottom_y = max(0.1, top_y - LADDER_DROP)
	var ladder_height = top_y - bottom_y

	# Ladder positioned slightly away from wall
	var depth_offset = Vector2(wall_normal.x, -wall_normal.z) * 0.3
	var ladder_center = center_2d + depth_offset

	# Width offset
	var half_width = LADDER_WIDTH / 2.0
	var width_offset = Vector2(wall_dir.x * half_width, wall_dir.y * half_width)

	var left_2d = ladder_center - width_offset
	var right_2d = ladder_center + width_offset

	# Side rails
	_add_rail(left_2d, bottom_y, top_y, wall_dir, -1, surface)
	_add_rail(right_2d, bottom_y, top_y, wall_dir, 1, surface)

	# Rungs
	var num_rungs = int(ladder_height / RUNG_SPACING)
	for i in range(num_rungs):
		var rung_y = bottom_y + RUNG_SPACING * (i + 0.5)
		_add_rung(left_2d, right_2d, rung_y, wall_normal, surface)

## Add vertical side rail
static func _add_rail(
	pos_2d: Vector2,
	bottom_y: float,
	top_y: float,
	wall_dir: Vector2,
	side: int,
	surface
) -> void:
	var half_w = RAIL_WIDTH / 2.0

	# Rail cross-section corners
	var w_offset = Vector2(wall_dir.x * half_w, wall_dir.y * half_w)
	var d_offset = Vector2(-wall_dir.y * half_w, wall_dir.x * half_w)

	var corners_2d = [
		pos_2d - w_offset - d_offset,
		pos_2d + w_offset - d_offset,
		pos_2d + w_offset + d_offset,
		pos_2d - w_offset + d_offset,
	]

	var face_normals = [
		Vector3(wall_dir.y, 0, wall_dir.x),     # Back
		Vector3(wall_dir.x, 0, -wall_dir.y),    # Right
		Vector3(-wall_dir.y, 0, -wall_dir.x),   # Front
		Vector3(-wall_dir.x, 0, wall_dir.y),    # Left
	]

	# Four side faces
	for i in range(4):
		var next = (i + 1) % 4
		var c1 = corners_2d[i]
		var c2 = corners_2d[next]

		var v_bl = Vector3(c1.x, bottom_y, -c1.y)
		var v_br = Vector3(c2.x, bottom_y, -c2.y)
		var v_tl = Vector3(c1.x, top_y, -c1.y)
		var v_tr = Vector3(c2.x, top_y, -c2.y)

		_add_quad(v_bl, v_br, v_tr, v_tl, face_normals[i], surface)

## Add horizontal rung
static func _add_rung(
	left_2d: Vector2,
	right_2d: Vector2,
	rung_y: float,
	wall_normal: Vector3,
	surface
) -> void:
	var half_d = RUNG_DIAMETER / 2.0

	# Rung as a simple box
	var left_3d = Vector3(left_2d.x, rung_y, -left_2d.y)
	var right_3d = Vector3(right_2d.x, rung_y, -right_2d.y)

	var direction = (right_3d - left_3d).normalized()
	var up_offset = Vector3(0, half_d, 0)
	var forward_offset = Vector3(wall_normal.x * half_d, 0, wall_normal.z * half_d)

	# Top face
	var t_fl = left_3d + up_offset - forward_offset
	var t_fr = right_3d + up_offset - forward_offset
	var t_bl = left_3d + up_offset + forward_offset
	var t_br = right_3d + up_offset + forward_offset

	_add_quad(t_fl, t_fr, t_br, t_bl, Vector3.UP, surface)

	# Front face
	var f_bl = left_3d - up_offset + forward_offset
	var f_br = right_3d - up_offset + forward_offset
	var f_tl = left_3d + up_offset + forward_offset
	var f_tr = right_3d + up_offset + forward_offset

	_add_quad(f_bl, f_br, f_tr, f_tl, wall_normal, surface)

	# Bottom face
	var b_fl = left_3d - up_offset - forward_offset
	var b_fr = right_3d - up_offset - forward_offset
	var b_bl = left_3d - up_offset + forward_offset
	var b_br = right_3d - up_offset + forward_offset

	_add_quad(b_bl, b_br, b_fr, b_fl, Vector3.DOWN, surface)

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
