extends Node
class_name StepsGenerator

## Steps generator for building entrances
## Creates entrance steps leading up to doors

const GeometryUtils = preload("res://scripts/generators/building/core/geometry_utils.gd")

## Step dimensions
const STEP_HEIGHT = 0.15     # 15cm riser height
const STEP_DEPTH = 0.30      # 30cm tread depth
const STEP_SIDE_MARGIN = 0.15 # 15cm wider than door on each side

## Main entry point - generates entrance steps
static func generate(
	p1: Vector2, p2: Vector2,
	door_left_t: float, door_right_t: float,
	total_height: float,
	wall_normal: Vector3,
	wall_surface
) -> void:
	if total_height < 0.05:  # Skip if negligible height
		return

	# Calculate number of steps needed
	var num_steps = max(1, int(ceil(total_height / STEP_HEIGHT)))
	var actual_step_height = total_height / float(num_steps)

	# Calculate step width (door width + margins)
	var left_pos = p1.lerp(p2, door_left_t)
	var right_pos = p1.lerp(p2, door_right_t)
	var door_width = left_pos.distance_to(right_pos)

	# Wall direction for calculating step positions
	var wall_dir = (p2 - p1).normalized()
	var step_margin_offset = wall_dir * STEP_SIDE_MARGIN

	# Widen the steps
	var step_left = Vector2(left_pos.x - step_margin_offset.x, left_pos.y - step_margin_offset.y)
	var step_right = Vector2(right_pos.x + step_margin_offset.x, right_pos.y + step_margin_offset.y)

	# Generate each step
	for step_num in range(num_steps):
		var step_bottom = step_num * actual_step_height
		var step_top = (step_num + 1) * actual_step_height

		# Steps project outward from wall, lower steps are further out
		var step_depth_offset = (num_steps - step_num) * STEP_DEPTH
		var prev_depth_offset = (num_steps - step_num - 1) * STEP_DEPTH if step_num < num_steps - 1 else 0.0

		_add_step(
			step_left, step_right,
			step_bottom, step_top,
			step_depth_offset, prev_depth_offset,
			wall_normal,
			wall_surface
		)

## Add a single step (box with top, front, and sides)
static func _add_step(
	left_pos: Vector2, right_pos: Vector2,
	step_bottom: float, step_top: float,
	depth_offset: float, prev_depth_offset: float,
	wall_normal: Vector3,
	surface
) -> void:
	# Calculate outward offset from wall
	var outward = Vector3(wall_normal.x * depth_offset, 0, wall_normal.z * depth_offset)
	var prev_outward = Vector3(wall_normal.x * prev_depth_offset, 0, wall_normal.z * prev_depth_offset)

	# Step corners
	# Back edge (against wall or previous step)
	var back_bl = Vector3(left_pos.x, step_bottom, -left_pos.y) + prev_outward
	var back_br = Vector3(right_pos.x, step_bottom, -right_pos.y) + prev_outward
	var back_tl = Vector3(left_pos.x, step_top, -left_pos.y) + prev_outward
	var back_tr = Vector3(right_pos.x, step_top, -right_pos.y) + prev_outward

	# Front edge (furthest from wall)
	var front_bl = Vector3(left_pos.x, step_bottom, -left_pos.y) + outward
	var front_br = Vector3(right_pos.x, step_bottom, -right_pos.y) + outward
	var front_tl = Vector3(left_pos.x, step_top, -left_pos.y) + outward
	var front_tr = Vector3(right_pos.x, step_top, -right_pos.y) + outward

	# Calculate side normals
	var wall_dir = (Vector2(right_pos.x, right_pos.y) - Vector2(left_pos.x, left_pos.y)).normalized()
	var left_normal = Vector3(-wall_dir.x, 0, wall_dir.y)
	var right_normal = Vector3(wall_dir.x, 0, -wall_dir.y)

	# Top face (tread)
	_add_quad(front_tl, front_tr, back_tr, back_tl, Vector3.UP, surface)

	# Front face (riser)
	_add_quad(front_bl, front_br, front_tr, front_tl, wall_normal, surface)

	# Left side
	_add_quad(back_bl, back_tl, front_tl, front_bl, left_normal, surface)

	# Right side
	_add_quad(front_br, front_tr, back_tr, back_br, right_normal, surface)

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
