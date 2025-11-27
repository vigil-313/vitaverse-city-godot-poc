extends Node
class_name FlowerBoxGenerator

## Flower box generator for windows
## Creates decorative planters below window sills

## Flower box dimensions
const BOX_HEIGHT = 0.2       # 20cm tall box
const BOX_DEPTH = 0.2        # 20cm deep
const BOX_MARGIN = 0.05      # 5cm margin from window edges
const SOIL_INSET = 0.03      # 3cm inset for soil/plants surface

## Main entry point - generates flower box below window
static func generate(
	p1: Vector2, p2: Vector2,
	window_left_t: float, window_right_t: float,
	window_bottom: float,
	wall_normal: Vector3,
	wall_surface
) -> void:
	var left_pos = p1.lerp(p2, window_left_t)
	var right_pos = p1.lerp(p2, window_right_t)

	# Wall direction for width adjustment
	var wall_dir = (p2 - p1).normalized()
	var margin_offset = Vector2(wall_dir.x * BOX_MARGIN, wall_dir.y * BOX_MARGIN)

	# Inset the box slightly from window edges
	var box_left = Vector2(left_pos.x + margin_offset.x, left_pos.y + margin_offset.y)
	var box_right = Vector2(right_pos.x - margin_offset.x, right_pos.y - margin_offset.y)

	# Box position (hanging below window sill)
	var box_top = window_bottom - 0.02  # Small gap below sill
	var box_bottom = box_top - BOX_HEIGHT

	# Outward offset
	var outward = Vector3(wall_normal.x * BOX_DEPTH, 0, wall_normal.z * BOX_DEPTH)

	# Box vertices - back (against wall)
	var back_bl = Vector3(box_left.x, box_bottom, -box_left.y)
	var back_br = Vector3(box_right.x, box_bottom, -box_right.y)
	var back_tl = Vector3(box_left.x, box_top, -box_left.y)
	var back_tr = Vector3(box_right.x, box_top, -box_right.y)

	# Front vertices
	var front_bl = back_bl + outward
	var front_br = back_br + outward
	var front_tl = back_tl + outward
	var front_tr = back_tr + outward

	# Side normals
	var left_normal = Vector3(-wall_dir.x, 0, wall_dir.y)
	var right_normal = Vector3(wall_dir.x, 0, -wall_dir.y)

	# Generate box faces
	_add_quad(front_bl, front_br, front_tr, front_tl, wall_normal, wall_surface)     # Front
	_add_quad(front_bl, front_br, back_br, back_bl, Vector3.DOWN, wall_surface)      # Bottom
	_add_quad(back_bl, back_tl, front_tl, front_bl, left_normal, wall_surface)       # Left
	_add_quad(front_br, front_tr, back_tr, back_br, right_normal, wall_surface)      # Right

	# Top surface (soil/plants) - slightly inset
	var soil_inset = Vector3(wall_normal.x * -SOIL_INSET, 0, wall_normal.z * -SOIL_INSET)
	var soil_tl = front_tl + soil_inset + Vector3(0, -0.02, 0)
	var soil_tr = front_tr + soil_inset + Vector3(0, -0.02, 0)
	var soil_bl = back_tl + Vector3(0, -0.02, 0)
	var soil_br = back_tr + Vector3(0, -0.02, 0)

	_add_quad(soil_tl, soil_tr, soil_br, soil_bl, Vector3.UP, wall_surface)

	# Add simple plant geometry (small green bumps)
	_add_plants(box_left, box_right, box_top, wall_normal, wall_dir, wall_surface)

## Add simplified plant geometry
static func _add_plants(
	box_left: Vector2, box_right: Vector2,
	box_top: float,
	wall_normal: Vector3,
	wall_dir: Vector2,
	wall_surface
) -> void:
	var plant_height = 0.12
	var plant_width = 0.08
	var box_width = box_left.distance_to(box_right)

	# Add 2-4 plant clusters
	var num_plants = max(2, int(box_width / 0.15))

	for i in range(num_plants):
		var t = (float(i) + 0.5) / float(num_plants)
		var plant_center_2d = box_left.lerp(box_right, t)

		# Offset outward from wall
		var plant_offset = BOX_DEPTH * 0.5
		var plant_pos = Vector3(
			plant_center_2d.x + wall_normal.x * plant_offset,
			box_top,
			-plant_center_2d.y + wall_normal.z * plant_offset
		)

		_add_plant_cluster(plant_pos, plant_height, plant_width, wall_normal, wall_surface)

## Add a single plant cluster (simplified as a small box)
static func _add_plant_cluster(
	pos: Vector3,
	height: float,
	width: float,
	normal: Vector3,
	wall_surface
) -> void:
	var half_w = width / 2.0

	# Simple quad facing outward (plant foliage)
	var v1 = pos + Vector3(-half_w, 0, 0)
	var v2 = pos + Vector3(half_w, 0, 0)
	var v3 = pos + Vector3(half_w, height, 0)
	var v4 = pos + Vector3(-half_w, height, 0)

	# Rotate to face outward
	var angle = atan2(normal.x, normal.z)
	v1 = _rotate_around_y(v1, pos, angle)
	v2 = _rotate_around_y(v2, pos, angle)
	v3 = _rotate_around_y(v3, pos, angle)
	v4 = _rotate_around_y(v4, pos, angle)

	_add_quad(v1, v2, v3, v4, normal, wall_surface)

## Rotate point around Y axis
static func _rotate_around_y(point: Vector3, center: Vector3, angle: float) -> Vector3:
	var offset = point - center
	var rotated = Vector3(
		offset.x * cos(angle) - offset.z * sin(angle),
		offset.y,
		offset.x * sin(angle) + offset.z * cos(angle)
	)
	return center + rotated

## Helper: Add a quad
static func _add_quad(
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
