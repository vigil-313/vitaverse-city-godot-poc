extends Node
class_name AntennaGenerator

## TV Antenna Generator
## Creates old-style TV antennas on rooftops

## Antenna dimensions
const MAST_HEIGHT = 1.5         # 1.5m tall mast
const MAST_RADIUS = 0.02        # 2cm radius mast
const CROSSBAR_LENGTH = 0.8     # 80cm main crossbar
const ELEMENT_SPACING = 0.15    # 15cm between elements
const ELEMENT_LENGTH_MAX = 0.5  # 50cm longest element
const NUM_ELEMENTS = 5          # Number of horizontal elements
const SEGMENTS = 4              # Square mast

## Main entry point
static func generate(
	position: Vector3,
	surface,
	rng: RandomNumberGenerator
) -> void:
	# Mast (vertical pole)
	_add_mast(position, surface)

	# Crossbar at top
	var crossbar_y = position.y + MAST_HEIGHT * 0.9
	_add_crossbar(Vector3(position.x, crossbar_y, position.z), surface)

	# Elements (horizontal dipoles)
	_add_elements(Vector3(position.x, crossbar_y, position.z), surface)

## Add vertical mast
static func _add_mast(pos: Vector3, surface) -> void:
	var half_r = MAST_RADIUS

	# Four corners of square mast
	var corners = [
		Vector2(-half_r, -half_r),
		Vector2(half_r, -half_r),
		Vector2(half_r, half_r),
		Vector2(-half_r, half_r),
	]

	var face_normals = [
		Vector3(0, 0, -1),
		Vector3(1, 0, 0),
		Vector3(0, 0, 1),
		Vector3(-1, 0, 0),
	]

	var bottom_y = pos.y
	var top_y = pos.y + MAST_HEIGHT

	for i in range(4):
		var next = (i + 1) % 4
		var c1 = corners[i]
		var c2 = corners[next]

		var v_bl = Vector3(pos.x + c1.x, bottom_y, pos.z + c1.y)
		var v_br = Vector3(pos.x + c2.x, bottom_y, pos.z + c2.y)
		var v_tl = Vector3(pos.x + c1.x, top_y, pos.z + c1.y)
		var v_tr = Vector3(pos.x + c2.x, top_y, pos.z + c2.y)

		_add_quad(v_bl, v_br, v_tr, v_tl, face_normals[i], surface)

## Add horizontal crossbar (boom)
static func _add_crossbar(pos: Vector3, surface) -> void:
	var half_length = CROSSBAR_LENGTH / 2.0
	var bar_size = 0.015  # 1.5cm square bar

	# Crossbar along Z axis
	var v1 = pos + Vector3(-bar_size, -bar_size, -half_length)
	var v2 = pos + Vector3(bar_size, -bar_size, -half_length)
	var v3 = pos + Vector3(bar_size, bar_size, -half_length)
	var v4 = pos + Vector3(-bar_size, bar_size, -half_length)

	var v5 = pos + Vector3(-bar_size, -bar_size, half_length)
	var v6 = pos + Vector3(bar_size, -bar_size, half_length)
	var v7 = pos + Vector3(bar_size, bar_size, half_length)
	var v8 = pos + Vector3(-bar_size, bar_size, half_length)

	# Top
	_add_quad(v4, v3, v7, v8, Vector3.UP, surface)
	# Front
	_add_quad(v1, v2, v6, v5, Vector3.DOWN, surface)
	# Sides
	_add_quad(v1, v5, v8, v4, Vector3(-1, 0, 0), surface)
	_add_quad(v2, v3, v7, v6, Vector3(1, 0, 0), surface)

## Add dipole elements
static func _add_elements(pos: Vector3, surface) -> void:
	var half_crossbar = CROSSBAR_LENGTH / 2.0
	var element_size = 0.01  # 1cm square elements

	for i in range(NUM_ELEMENTS):
		# Position along crossbar
		var t = float(i) / float(NUM_ELEMENTS - 1) if NUM_ELEMENTS > 1 else 0.5
		var z_pos = pos.z - half_crossbar + CROSSBAR_LENGTH * t

		# Element length varies (longer in middle for Yagi pattern)
		var center_factor = 1.0 - abs(t - 0.5) * 2.0
		var element_half_length = ELEMENT_LENGTH_MAX * (0.4 + 0.6 * center_factor) / 2.0

		var element_pos = Vector3(pos.x, pos.y, z_pos)

		# Horizontal element along X axis
		var e1 = element_pos + Vector3(-element_half_length, -element_size, -element_size)
		var e2 = element_pos + Vector3(element_half_length, -element_size, -element_size)
		var e3 = element_pos + Vector3(element_half_length, element_size, -element_size)
		var e4 = element_pos + Vector3(-element_half_length, element_size, -element_size)

		var e5 = element_pos + Vector3(-element_half_length, -element_size, element_size)
		var e6 = element_pos + Vector3(element_half_length, -element_size, element_size)
		var e7 = element_pos + Vector3(element_half_length, element_size, element_size)
		var e8 = element_pos + Vector3(-element_half_length, element_size, element_size)

		# Top and front faces
		_add_quad(e4, e3, e7, e8, Vector3.UP, surface)
		_add_quad(e5, e6, e7, e8, Vector3(0, 0, 1), surface)

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
