extends Node
class_name SignagePanel

## Signage panel generator for commercial storefronts
## Creates flat panels above storefronts for store signs (geometry only, no text)

const GeometryUtils = preload("res://scripts/generators/building/core/geometry_utils.gd")

## Signage dimensions
const SIGNAGE_HEIGHT = 0.5     # 50cm tall
const SIGNAGE_OFFSET = 0.08    # 8cm protrusion from wall
const SIGNAGE_THICKNESS = 0.04 # 4cm panel thickness

## Signage panel colors (neutral backgrounds for signs)
const SIGNAGE_COLORS = [
	Color(0.9, 0.9, 0.85),   # Off-white
	Color(0.15, 0.15, 0.2),  # Dark charcoal
	Color(0.85, 0.8, 0.7),   # Cream
	Color(0.2, 0.25, 0.3),   # Dark blue-gray
	Color(0.7, 0.65, 0.6),   # Warm gray
]

## Main entry point - generates a signage panel
static func generate(
	p1: Vector2, p2: Vector2,
	panel_left_t: float, panel_right_t: float,
	panel_bottom: float, panel_top: float,
	wall_normal: Vector3,
	wall_surface
) -> void:
	# Calculate panel positions
	var left_pos = p1.lerp(p2, panel_left_t)
	var right_pos = p1.lerp(p2, panel_right_t)

	# Outward offset for panel
	var outward_offset = Vector3(wall_normal.x * SIGNAGE_OFFSET, 0, wall_normal.z * SIGNAGE_OFFSET)
	var thickness_offset = Vector3(wall_normal.x * SIGNAGE_THICKNESS, 0, wall_normal.z * SIGNAGE_THICKNESS)

	# Back face vertices (against wall)
	var back_bl = Vector3(left_pos.x, panel_bottom, -left_pos.y) + outward_offset
	var back_br = Vector3(right_pos.x, panel_bottom, -right_pos.y) + outward_offset
	var back_tl = Vector3(left_pos.x, panel_top, -left_pos.y) + outward_offset
	var back_tr = Vector3(right_pos.x, panel_top, -right_pos.y) + outward_offset

	# Front face vertices
	var front_bl = back_bl + thickness_offset
	var front_br = back_br + thickness_offset
	var front_tl = back_tl + thickness_offset
	var front_tr = back_tr + thickness_offset

	# Wall direction for side normals
	var wall_dir = (p2 - p1).normalized()
	var left_normal = Vector3(-wall_dir.x, 0, wall_dir.y)
	var right_normal = Vector3(wall_dir.x, 0, -wall_dir.y)

	# Generate all faces
	_add_panel_face(front_bl, front_br, front_tr, front_tl, wall_normal, wall_surface)  # Front
	_add_panel_face(back_br, back_bl, back_tl, back_tr, -wall_normal, wall_surface)     # Back
	_add_panel_face(front_tl, front_tr, back_tr, back_tl, Vector3.UP, wall_surface)     # Top
	_add_panel_face(front_br, front_bl, back_bl, back_br, Vector3.DOWN, wall_surface)   # Bottom
	_add_panel_face(front_bl, front_tl, back_tl, back_bl, left_normal, wall_surface)    # Left
	_add_panel_face(front_tr, front_br, back_br, back_tr, right_normal, wall_surface)   # Right

## Add a single panel face
static func _add_panel_face(
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
