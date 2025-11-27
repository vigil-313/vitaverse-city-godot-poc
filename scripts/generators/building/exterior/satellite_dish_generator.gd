extends Node
class_name SatelliteDishGenerator

## Satellite Dish Generator
## Creates small satellite dishes mounted on building walls

## Dish dimensions
const DISH_DIAMETER = 0.5       # 50cm dish
const DISH_DEPTH = 0.1          # 10cm deep curve
const ARM_LENGTH = 0.2          # 20cm arm to LNB
const MOUNT_SIZE = 0.08         # 8cm mounting bracket
const WALL_OFFSET = 0.15        # 15cm from wall
const SEGMENTS = 8              # Octagonal approximation

## Main entry point
static func generate(
	pos_2d: Vector2,
	height: float,
	wall_normal: Vector3,
	surface
) -> void:
	# Dish center position
	var outward = Vector2(wall_normal.x, -wall_normal.z) * WALL_OFFSET
	var dish_center_2d = pos_2d + outward
	var dish_center = Vector3(dish_center_2d.x, height, -dish_center_2d.y)

	# Generate dish (simplified as cone-like shape)
	_add_dish(dish_center, wall_normal, surface)

	# Add mounting arm
	_add_mount(pos_2d, height, wall_normal, surface)

	# Add LNB (receiver) on arm
	_add_lnb(dish_center, wall_normal, surface)

## Generate the dish shape
static func _add_dish(
	center: Vector3,
	wall_normal: Vector3,
	surface
) -> void:
	var radius = DISH_DIAMETER / 2.0

	# Dish faces wall_normal direction (tilted up slightly)
	var dish_normal = Vector3(wall_normal.x * 0.9, 0.4, wall_normal.z * 0.9).normalized()

	# Generate dish as segments radiating from center
	var back_center = center - dish_normal * DISH_DEPTH

	for i in range(SEGMENTS):
		var angle1 = TAU * i / SEGMENTS
		var angle2 = TAU * (i + 1) / SEGMENTS

		# Calculate rim positions perpendicular to dish_normal
		var right = wall_normal.cross(Vector3.UP).normalized()
		var up = right.cross(Vector3(wall_normal.x, 0, wall_normal.z)).normalized()

		var rim1 = center + (right * cos(angle1) + up * sin(angle1)) * radius
		var rim2 = center + (right * cos(angle2) + up * sin(angle2)) * radius

		# Triangle from back_center to rim
		_add_triangle(back_center, rim1, rim2, dish_normal, surface)

	# Rim edge (outer ring)
	for i in range(SEGMENTS):
		var angle1 = TAU * i / SEGMENTS
		var angle2 = TAU * (i + 1) / SEGMENTS

		var right = wall_normal.cross(Vector3.UP).normalized()
		var up = right.cross(Vector3(wall_normal.x, 0, wall_normal.z)).normalized()

		var rim1_front = center + (right * cos(angle1) + up * sin(angle1)) * radius
		var rim2_front = center + (right * cos(angle2) + up * sin(angle2)) * radius
		var rim1_back = rim1_front - dish_normal * 0.02
		var rim2_back = rim2_front - dish_normal * 0.02

		var edge_normal = (right * cos((angle1 + angle2) / 2) + up * sin((angle1 + angle2) / 2)).normalized()
		_add_quad(rim1_back, rim2_back, rim2_front, rim1_front, edge_normal, surface)

## Add wall mount
static func _add_mount(
	wall_pos_2d: Vector2,
	height: float,
	wall_normal: Vector3,
	surface
) -> void:
	var half_size = MOUNT_SIZE / 2.0
	var outward = Vector2(wall_normal.x, -wall_normal.z)

	# Mount plate on wall
	var plate_center = Vector3(wall_pos_2d.x, height, -wall_pos_2d.y)

	# Perpendicular for width
	var perp = Vector2(-wall_normal.z, -wall_normal.x)

	var v1 = plate_center + Vector3(-perp.x * half_size, -half_size, perp.y * half_size)
	var v2 = plate_center + Vector3(perp.x * half_size, -half_size, -perp.y * half_size)
	var v3 = plate_center + Vector3(perp.x * half_size, half_size, -perp.y * half_size)
	var v4 = plate_center + Vector3(-perp.x * half_size, half_size, perp.y * half_size)

	_add_quad(v1, v2, v3, v4, wall_normal, surface)

	# Arm extending outward
	var arm_end_2d = wall_pos_2d + outward * WALL_OFFSET
	var arm_end = Vector3(arm_end_2d.x, height, -arm_end_2d.y)

	var arm_width = 0.02
	_add_quad(
		plate_center + Vector3(0, -arm_width, 0),
		arm_end + Vector3(0, -arm_width, 0),
		arm_end + Vector3(0, arm_width, 0),
		plate_center + Vector3(0, arm_width, 0),
		Vector3(perp.x, 0, -perp.y), surface
	)

## Add LNB (the receiver at end of arm)
static func _add_lnb(
	dish_center: Vector3,
	wall_normal: Vector3,
	surface
) -> void:
	var lnb_pos = dish_center + Vector3(wall_normal.x * ARM_LENGTH, 0.05, wall_normal.z * ARM_LENGTH)
	var lnb_radius = 0.03
	var lnb_length = 0.08

	# Simplified as small box
	var half = Vector3(lnb_radius, lnb_radius, lnb_length / 2)

	# Front face
	_add_quad(
		lnb_pos + Vector3(-half.x, -half.y, half.z),
		lnb_pos + Vector3(half.x, -half.y, half.z),
		lnb_pos + Vector3(half.x, half.y, half.z),
		lnb_pos + Vector3(-half.x, half.y, half.z),
		-wall_normal, surface
	)

## Add triangle
static func _add_triangle(
	v1: Vector3, v2: Vector3, v3: Vector3,
	normal: Vector3,
	surface
) -> void:
	var base_idx = surface.vertices.size()

	surface.vertices.append(v1)
	surface.vertices.append(v2)
	surface.vertices.append(v3)

	for i in range(3):
		surface.normals.append(normal)

	surface.uvs.append(Vector2(0.5, 0))
	surface.uvs.append(Vector2(0, 1))
	surface.uvs.append(Vector2(1, 1))

	surface.indices.append(base_idx + 0)
	surface.indices.append(base_idx + 1)
	surface.indices.append(base_idx + 2)

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
