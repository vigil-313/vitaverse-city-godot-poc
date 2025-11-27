extends Node
class_name DoorGenerator

## Door generator for building entrances
## Creates recessed door openings with frames and door panels

const GeometryUtils = preload("res://scripts/generators/building/core/geometry_utils.gd")

## Door dimensions
const DOOR_RECESS = 0.25      # 25cm recess into wall
const FRAME_THICKNESS = 0.08  # 8cm door frame
const DOOR_THICKNESS = 0.05   # 5cm door panel

## Door colors
const COMMERCIAL_DOOR_COLOR = Color(0.15, 0.15, 0.18)  # Dark metal
const RESIDENTIAL_DOOR_COLOR = Color(0.35, 0.22, 0.12) # Wood brown

## Main entry point - generates a door
static func generate(
	p1: Vector2, p2: Vector2,
	door_left_t: float, door_right_t: float,
	door_bottom: float, door_top: float,
	wall_normal: Vector3,
	wall_surface,
	glass_surface,
	frame_surface,
	is_commercial: bool
) -> void:
	# Generate door reveal (recessed opening)
	_add_door_reveal(
		p1, p2,
		door_left_t, door_right_t,
		door_bottom, door_top,
		wall_normal,
		wall_surface
	)

	# Generate door frame
	_add_door_frame(
		p1, p2,
		door_left_t, door_right_t,
		door_bottom, door_top,
		wall_normal,
		frame_surface
	)

	# Generate door panel (glass for commercial, solid for residential)
	if is_commercial:
		_add_glass_door(
			p1, p2,
			door_left_t, door_right_t,
			door_bottom, door_top,
			wall_normal,
			glass_surface
		)
	else:
		_add_solid_door(
			p1, p2,
			door_left_t, door_right_t,
			door_bottom, door_top,
			wall_normal,
			wall_surface
		)

## Add door reveal (recessed opening showing wall depth)
static func _add_door_reveal(
	p1: Vector2, p2: Vector2,
	door_left_t: float, door_right_t: float,
	door_bottom: float, door_top: float,
	wall_normal: Vector3,
	wall_surface
) -> void:
	var recess_offset = Vector3(wall_normal.x * -DOOR_RECESS, 0, wall_normal.z * -DOOR_RECESS)

	var left_pos = p1.lerp(p2, door_left_t)
	var right_pos = p1.lerp(p2, door_right_t)

	# Outer corners (at wall surface)
	var outer_bl = Vector3(left_pos.x, door_bottom, -left_pos.y)
	var outer_br = Vector3(right_pos.x, door_bottom, -right_pos.y)
	var outer_tl = Vector3(left_pos.x, door_top, -left_pos.y)
	var outer_tr = Vector3(right_pos.x, door_top, -right_pos.y)

	# Inner corners (recessed)
	var inner_bl = outer_bl + recess_offset
	var inner_br = outer_br + recess_offset
	var inner_tl = outer_tl + recess_offset
	var inner_tr = outer_tr + recess_offset

	# Wall direction for side normals
	var wall_dir = (p2 - p1).normalized()
	var tangent = Vector3(wall_dir.x, 0, -wall_dir.y)

	# Top reveal
	_add_reveal_quad(outer_tl, outer_tr, inner_tr, inner_tl, Vector3.DOWN, wall_surface)

	# Left reveal
	_add_reveal_quad(outer_bl, outer_tl, inner_tl, inner_bl, tangent, wall_surface)

	# Right reveal
	_add_reveal_quad(outer_br, outer_tr, inner_tr, inner_br, -tangent, wall_surface)

## Add door frame around opening
static func _add_door_frame(
	p1: Vector2, p2: Vector2,
	door_left_t: float, door_right_t: float,
	door_bottom: float, door_top: float,
	wall_normal: Vector3,
	frame_surface
) -> void:
	var frame_offset = Vector3(wall_normal.x * -(DOOR_RECESS - 0.02), 0, wall_normal.z * -(DOOR_RECESS - 0.02))

	var left_pos = p1.lerp(p2, door_left_t)
	var right_pos = p1.lerp(p2, door_right_t)

	# Frame corners
	var bl = Vector3(left_pos.x, door_bottom, -left_pos.y) + frame_offset
	var br = Vector3(right_pos.x, door_bottom, -right_pos.y) + frame_offset
	var tl = Vector3(left_pos.x, door_top, -left_pos.y) + frame_offset
	var tr = Vector3(right_pos.x, door_top, -right_pos.y) + frame_offset

	var wall_dir = (p2 - p1).normalized()
	var tangent = Vector3(wall_dir.x, 0, -wall_dir.y)

	# Top frame
	_add_frame_segment(tl, tr, FRAME_THICKNESS, tangent, wall_normal, frame_surface)

	# Left frame
	_add_frame_segment(bl, tl, FRAME_THICKNESS, Vector3.UP, wall_normal, frame_surface)

	# Right frame
	_add_frame_segment(br, tr, FRAME_THICKNESS, Vector3.UP, wall_normal, frame_surface)

## Add glass door panel (commercial)
static func _add_glass_door(
	p1: Vector2, p2: Vector2,
	door_left_t: float, door_right_t: float,
	door_bottom: float, door_top: float,
	wall_normal: Vector3,
	glass_surface
) -> void:
	var panel_offset = Vector3(wall_normal.x * -(DOOR_RECESS - DOOR_THICKNESS), 0, wall_normal.z * -(DOOR_RECESS - DOOR_THICKNESS))

	var left_pos = p1.lerp(p2, door_left_t)
	var right_pos = p1.lerp(p2, door_right_t)

	# Inset the glass slightly from the frame
	var inset = 0.05
	var glass_left = left_pos.lerp(right_pos, inset / left_pos.distance_to(right_pos))
	var glass_right = right_pos.lerp(left_pos, inset / left_pos.distance_to(right_pos))
	var glass_bottom = door_bottom + inset
	var glass_top = door_top - inset

	var v1 = Vector3(glass_left.x, glass_bottom, -glass_left.y) + panel_offset
	var v2 = Vector3(glass_right.x, glass_bottom, -glass_right.y) + panel_offset
	var v3 = Vector3(glass_right.x, glass_top, -glass_right.y) + panel_offset
	var v4 = Vector3(glass_left.x, glass_top, -glass_left.y) + panel_offset

	var base_index = glass_surface.vertices.size()

	glass_surface.vertices.append(v1)
	glass_surface.vertices.append(v2)
	glass_surface.vertices.append(v3)
	glass_surface.vertices.append(v4)

	# Well-lit interior visible through door
	var emission = Color(1.0, 0.95, 0.85, 0.9)
	for i in range(4):
		glass_surface.normals.append(wall_normal)
		glass_surface.colors.append(emission)

	glass_surface.uvs.append(Vector2(0, 0))
	glass_surface.uvs.append(Vector2(1, 0))
	glass_surface.uvs.append(Vector2(1, 1))
	glass_surface.uvs.append(Vector2(0, 1))

	glass_surface.indices.append(base_index + 0)
	glass_surface.indices.append(base_index + 1)
	glass_surface.indices.append(base_index + 2)
	glass_surface.indices.append(base_index + 0)
	glass_surface.indices.append(base_index + 2)
	glass_surface.indices.append(base_index + 3)

## Add solid door panel (residential)
static func _add_solid_door(
	p1: Vector2, p2: Vector2,
	door_left_t: float, door_right_t: float,
	door_bottom: float, door_top: float,
	wall_normal: Vector3,
	wall_surface
) -> void:
	var panel_offset = Vector3(wall_normal.x * -(DOOR_RECESS - DOOR_THICKNESS), 0, wall_normal.z * -(DOOR_RECESS - DOOR_THICKNESS))

	var left_pos = p1.lerp(p2, door_left_t)
	var right_pos = p1.lerp(p2, door_right_t)

	var v1 = Vector3(left_pos.x, door_bottom, -left_pos.y) + panel_offset
	var v2 = Vector3(right_pos.x, door_bottom, -right_pos.y) + panel_offset
	var v3 = Vector3(right_pos.x, door_top, -right_pos.y) + panel_offset
	var v4 = Vector3(left_pos.x, door_top, -left_pos.y) + panel_offset

	var base_index = wall_surface.vertices.size()

	wall_surface.vertices.append(v1)
	wall_surface.vertices.append(v2)
	wall_surface.vertices.append(v3)
	wall_surface.vertices.append(v4)

	for i in range(4):
		wall_surface.normals.append(wall_normal)

	wall_surface.uvs.append(Vector2(0, 0))
	wall_surface.uvs.append(Vector2(1, 0))
	wall_surface.uvs.append(Vector2(1, 1))
	wall_surface.uvs.append(Vector2(0, 1))

	wall_surface.indices.append(base_index + 0)
	wall_surface.indices.append(base_index + 1)
	wall_surface.indices.append(base_index + 2)
	wall_surface.indices.append(base_index + 0)
	wall_surface.indices.append(base_index + 2)
	wall_surface.indices.append(base_index + 3)

## Helper: Add a reveal quad
static func _add_reveal_quad(
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

## Helper: Add a frame segment
static func _add_frame_segment(
	start: Vector3, end: Vector3,
	thickness: float,
	up_dir: Vector3,
	normal: Vector3,
	frame_surface
) -> void:
	var half_thick = thickness / 2.0
	var offset_up = up_dir * half_thick
	var offset_out = normal * half_thick

	var v1 = start - offset_up + offset_out
	var v2 = end - offset_up + offset_out
	var v3 = end + offset_up + offset_out
	var v4 = start + offset_up + offset_out

	var base_index = frame_surface.vertices.size()

	frame_surface.vertices.append(v1)
	frame_surface.vertices.append(v2)
	frame_surface.vertices.append(v3)
	frame_surface.vertices.append(v4)

	for i in range(4):
		frame_surface.normals.append(normal)

	frame_surface.uvs.append(Vector2(0, 0))
	frame_surface.uvs.append(Vector2(1, 0))
	frame_surface.uvs.append(Vector2(1, 1))
	frame_surface.uvs.append(Vector2(0, 1))

	frame_surface.indices.append(base_index + 0)
	frame_surface.indices.append(base_index + 1)
	frame_surface.indices.append(base_index + 2)
	frame_surface.indices.append(base_index + 0)
	frame_surface.indices.append(base_index + 2)
	frame_surface.indices.append(base_index + 3)
