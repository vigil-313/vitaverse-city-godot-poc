extends Node
class_name EscapeRailing

## Fire Escape Railing Generator
## Creates safety railings around landings

## Railing dimensions
const RAILING_HEIGHT = 1.0      # 1m tall railing
const POST_WIDTH = 0.04         # 4cm square posts
const RAIL_WIDTH = 0.03         # 3cm rail diameter
const POST_SPACING = 0.4        # 40cm between posts

## Landing dimensions (must match landing_generator.gd)
const LANDING_WIDTH = 1.2
const LANDING_DEPTH = 1.0
const WALL_OFFSET = 0.05

## Main entry point - generate railings around a landing
static func generate_for_landing(
	center_2d: Vector2,
	floor_y: float,
	wall_normal: Vector3,
	wall_dir: Vector2,
	surface
) -> void:
	var half_width = LANDING_WIDTH / 2.0

	# Width direction offset
	var width_offset = Vector2(wall_dir.x * half_width, wall_dir.y * half_width)

	# Depth offset
	var depth_offset_2d = Vector2(wall_normal.x, -wall_normal.z) * (LANDING_DEPTH + WALL_OFFSET)

	# Corner positions
	var inner_left = center_2d - width_offset
	var inner_right = center_2d + width_offset
	var outer_left = inner_left + depth_offset_2d
	var outer_right = inner_right + depth_offset_2d

	# Generate railings on three sides (not against wall)
	# Front railing
	_add_railing_segment(outer_left, outer_right, floor_y, wall_normal, surface)

	# Left railing
	var left_normal = Vector3(-wall_dir.x, 0, wall_dir.y)
	_add_railing_segment(inner_left, outer_left, floor_y, left_normal, surface)

	# Right railing
	var right_normal = Vector3(wall_dir.x, 0, -wall_dir.y)
	_add_railing_segment(outer_right, inner_right, floor_y, right_normal, surface)

## Add a railing segment between two points
static func _add_railing_segment(
	start_2d: Vector2,
	end_2d: Vector2,
	floor_y: float,
	normal: Vector3,
	surface
) -> void:
	var segment_length = start_2d.distance_to(end_2d)
	var num_posts = max(2, int(segment_length / POST_SPACING) + 1)

	# Add posts
	for i in range(num_posts):
		var t = float(i) / float(num_posts - 1) if num_posts > 1 else 0.5
		var post_2d = start_2d.lerp(end_2d, t)
		_add_post(post_2d, floor_y, surface)

	# Add top rail
	var start_3d = Vector3(start_2d.x, floor_y + RAILING_HEIGHT, -start_2d.y)
	var end_3d = Vector3(end_2d.x, floor_y + RAILING_HEIGHT, -end_2d.y)
	_add_rail(start_3d, end_3d, normal, surface)

	# Add middle rail
	var mid_height = floor_y + RAILING_HEIGHT * 0.5
	var start_mid = Vector3(start_2d.x, mid_height, -start_2d.y)
	var end_mid = Vector3(end_2d.x, mid_height, -end_2d.y)
	_add_rail(start_mid, end_mid, normal, surface)

## Add a vertical post
static func _add_post(pos_2d: Vector2, floor_y: float, surface) -> void:
	var half_w = POST_WIDTH / 2.0

	var corners = [
		Vector2(pos_2d.x - half_w, pos_2d.y - half_w),
		Vector2(pos_2d.x + half_w, pos_2d.y - half_w),
		Vector2(pos_2d.x + half_w, pos_2d.y + half_w),
		Vector2(pos_2d.x - half_w, pos_2d.y + half_w),
	]

	var bottom_y = floor_y
	var top_y = floor_y + RAILING_HEIGHT

	# Four sides
	var face_normals = [
		Vector3(0, 0, 1),
		Vector3(1, 0, 0),
		Vector3(0, 0, -1),
		Vector3(-1, 0, 0),
	]

	for i in range(4):
		var next = (i + 1) % 4
		var c1 = corners[i]
		var c2 = corners[next]

		var v_bl = Vector3(c1.x, bottom_y, -c1.y)
		var v_br = Vector3(c2.x, bottom_y, -c2.y)
		var v_tl = Vector3(c1.x, top_y, -c1.y)
		var v_tr = Vector3(c2.x, top_y, -c2.y)

		_add_quad(v_bl, v_br, v_tr, v_tl, face_normals[i], surface)

	# Top cap
	var base_idx = surface.vertices.size()
	for c in corners:
		surface.vertices.append(Vector3(c.x, top_y, -c.y))
		surface.normals.append(Vector3.UP)

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

## Add a horizontal rail
static func _add_rail(start: Vector3, end: Vector3, normal: Vector3, surface) -> void:
	var direction = (end - start).normalized()
	var half_w = RAIL_WIDTH / 2.0

	# Perpendicular to direction (horizontal)
	var right = direction.cross(Vector3.UP).normalized() * half_w

	# Four corners at start
	var s_bl = start - right + Vector3(0, -half_w, 0)
	var s_br = start + right + Vector3(0, -half_w, 0)
	var s_tl = start - right + Vector3(0, half_w, 0)
	var s_tr = start + right + Vector3(0, half_w, 0)

	# Four corners at end
	var e_bl = end - right + Vector3(0, -half_w, 0)
	var e_br = end + right + Vector3(0, half_w, 0)
	var e_tl = end - right + Vector3(0, half_w, 0)
	var e_tr = end + right + Vector3(0, half_w, 0)

	# Top face
	_add_quad(s_tl, s_tr, e_tr, e_tl, Vector3.UP, surface)

	# Front face (facing normal direction)
	_add_quad(s_tr, s_br, e_br, e_tr, normal, surface)

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
