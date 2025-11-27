extends Node
class_name DisplayWindow

## Display window generator for commercial storefronts
## Creates large floor-to-ceiling windows with thinner frames

const GeometryUtils = preload("res://scripts/generators/building/core/geometry_utils.gd")
const EmissionController = preload("res://scripts/generators/building/windows/features/emission_controller.gd")

## Display window frame dimensions (thinner than standard windows)
const FRAME_THICKNESS = 0.04  # 4cm frame (vs 8cm for standard windows)
const GLASS_RECESS = 0.10     # 10cm recess from wall surface
const REVEAL_DEPTH = 0.20     # 20cm reveal depth

## Main entry point - generates a large display window
static func generate(
	p1: Vector2, p2: Vector2,
	window_left_t: float, window_right_t: float,
	window_bottom: float, window_top: float,
	wall_normal: Vector3,
	wall_surface,
	glass_surface,
	frame_surface
) -> Color:
	# Generate window reveal (wall thickness visible around window)
	_add_display_reveal(
		p1, p2,
		window_left_t, window_right_t,
		window_bottom, window_top,
		wall_normal,
		wall_surface
	)

	# Generate emission color for display window (usually well-lit)
	var emission_color = _generate_display_emission()

	# Generate glass pane
	_add_display_glass(
		p1, p2,
		window_left_t, window_right_t,
		window_bottom, window_top,
		wall_normal,
		glass_surface,
		emission_color
	)

	# Generate thin frame around glass
	_add_display_frame(
		p1, p2,
		window_left_t, window_right_t,
		window_bottom, window_top,
		wall_normal,
		frame_surface
	)

	return emission_color

## Generate emission color for display windows (brighter than residential)
static func _generate_display_emission() -> Color:
	# Display windows are usually well-lit stores
	var lit_chance = 0.85  # 85% chance to be lit (vs 40% for residential)

	if randf() > lit_chance:
		return Color(0, 0, 0, 0)  # Unlit

	# Warmer, brighter light for retail displays
	var colors = [
		Color(1.0, 0.95, 0.85, 1.0),  # Bright warm white (60%)
		Color(1.0, 1.0, 1.0, 1.0),    # Pure white (25%)
		Color(1.0, 0.9, 0.7, 1.0),    # Golden warm (15%)
	]

	var weights = [0.6, 0.25, 0.15]
	var roll = randf()
	var cumulative = 0.0

	for i in range(colors.size()):
		cumulative += weights[i]
		if roll < cumulative:
			var emission = colors[i]
			emission.a = randf_range(0.7, 1.0)  # Higher brightness
			return emission

	return colors[0]

## Add window reveal (shows wall thickness)
static func _add_display_reveal(
	p1: Vector2, p2: Vector2,
	window_left_t: float, window_right_t: float,
	window_bottom: float, window_top: float,
	wall_normal: Vector3,
	wall_surface
) -> void:
	var reveal_offset = Vector3(wall_normal.x * -REVEAL_DEPTH, 0, wall_normal.z * -REVEAL_DEPTH)

	# Calculate window corner positions
	var left_pos = p1.lerp(p2, window_left_t)
	var right_pos = p1.lerp(p2, window_right_t)

	var outer_bl = Vector3(left_pos.x, window_bottom, -left_pos.y)
	var outer_br = Vector3(right_pos.x, window_bottom, -right_pos.y)
	var outer_tl = Vector3(left_pos.x, window_top, -left_pos.y)
	var outer_tr = Vector3(right_pos.x, window_top, -right_pos.y)

	var inner_bl = outer_bl + reveal_offset
	var inner_br = outer_br + reveal_offset
	var inner_tl = outer_tl + reveal_offset
	var inner_tr = outer_tr + reveal_offset

	# Calculate tangent direction
	var wall_dir = (p2 - p1).normalized()
	var tangent = Vector3(wall_dir.x, 0, -wall_dir.y)

	# Top reveal
	_add_reveal_quad(
		outer_tl, outer_tr, inner_tr, inner_tl,
		Vector3.DOWN,
		wall_surface
	)

	# Bottom reveal
	_add_reveal_quad(
		outer_bl, outer_br, inner_br, inner_bl,
		Vector3.UP,
		wall_surface
	)

	# Left reveal
	_add_reveal_quad(
		outer_bl, outer_tl, inner_tl, inner_bl,
		tangent,
		wall_surface
	)

	# Right reveal
	_add_reveal_quad(
		outer_br, outer_tr, inner_tr, inner_br,
		-tangent,
		wall_surface
	)

## Add a single reveal quad
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

	# Two triangles
	surface.indices.append(base_index + 0)
	surface.indices.append(base_index + 1)
	surface.indices.append(base_index + 2)
	surface.indices.append(base_index + 0)
	surface.indices.append(base_index + 2)
	surface.indices.append(base_index + 3)

## Add glass pane with emission
static func _add_display_glass(
	p1: Vector2, p2: Vector2,
	window_left_t: float, window_right_t: float,
	window_bottom: float, window_top: float,
	wall_normal: Vector3,
	glass_surface,
	emission_color: Color
) -> void:
	var glass_offset = Vector3(wall_normal.x * -GLASS_RECESS, 0, wall_normal.z * -GLASS_RECESS)

	var left_pos = p1.lerp(p2, window_left_t)
	var right_pos = p1.lerp(p2, window_right_t)

	var v1 = Vector3(left_pos.x, window_bottom, -left_pos.y) + glass_offset
	var v2 = Vector3(right_pos.x, window_bottom, -right_pos.y) + glass_offset
	var v3 = Vector3(right_pos.x, window_top, -right_pos.y) + glass_offset
	var v4 = Vector3(left_pos.x, window_top, -left_pos.y) + glass_offset

	var base_index = glass_surface.vertices.size()

	glass_surface.vertices.append(v1)
	glass_surface.vertices.append(v2)
	glass_surface.vertices.append(v3)
	glass_surface.vertices.append(v4)

	for i in range(4):
		glass_surface.normals.append(wall_normal)
		glass_surface.colors.append(emission_color)

	var width = left_pos.distance_to(right_pos)
	var height = window_top - window_bottom

	glass_surface.uvs.append(Vector2(0, 0))
	glass_surface.uvs.append(Vector2(width, 0))
	glass_surface.uvs.append(Vector2(width, height))
	glass_surface.uvs.append(Vector2(0, height))

	glass_surface.indices.append(base_index + 0)
	glass_surface.indices.append(base_index + 1)
	glass_surface.indices.append(base_index + 2)
	glass_surface.indices.append(base_index + 0)
	glass_surface.indices.append(base_index + 2)
	glass_surface.indices.append(base_index + 3)

## Add thin frame around glass
static func _add_display_frame(
	p1: Vector2, p2: Vector2,
	window_left_t: float, window_right_t: float,
	window_bottom: float, window_top: float,
	wall_normal: Vector3,
	frame_surface
) -> void:
	var frame_offset = Vector3(wall_normal.x * -(GLASS_RECESS - 0.01), 0, wall_normal.z * -(GLASS_RECESS - 0.01))

	var left_pos = p1.lerp(p2, window_left_t)
	var right_pos = p1.lerp(p2, window_right_t)
	var width = left_pos.distance_to(right_pos)
	var height = window_top - window_bottom

	# Frame corner positions (slightly in front of glass)
	var bl = Vector3(left_pos.x, window_bottom, -left_pos.y) + frame_offset
	var br = Vector3(right_pos.x, window_bottom, -right_pos.y) + frame_offset
	var tl = Vector3(left_pos.x, window_top, -left_pos.y) + frame_offset
	var tr = Vector3(right_pos.x, window_top, -right_pos.y) + frame_offset

	var wall_dir = (p2 - p1).normalized()
	var tangent = Vector3(wall_dir.x, 0, -wall_dir.y)

	# Bottom frame
	_add_frame_segment(bl, br, FRAME_THICKNESS, tangent, wall_normal, frame_surface)

	# Top frame
	_add_frame_segment(tl, tr, FRAME_THICKNESS, tangent, wall_normal, frame_surface)

	# Left frame
	_add_frame_segment(bl, tl, FRAME_THICKNESS, Vector3.UP, wall_normal, frame_surface)

	# Right frame
	_add_frame_segment(br, tr, FRAME_THICKNESS, Vector3.UP, wall_normal, frame_surface)

## Add a single frame segment (thin box)
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

	# Front face (visible)
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
