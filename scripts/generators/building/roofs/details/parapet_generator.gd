extends Node
class_name ParapetGenerator

## Parapet generator for flat roofs
## Creates low walls around the roof perimeter

const GeometryUtils = preload("res://scripts/generators/building/core/geometry_utils.gd")

## Parapet dimensions
const PARAPET_HEIGHT = 0.9      # 90cm tall parapet
const PARAPET_THICKNESS = 0.2   # 20cm thick wall
const CAP_THICKNESS = 0.08      # 8cm cap on top

## Main entry point - generates parapet around roof perimeter
static func generate(
	footprint: Array,
	center: Vector2,
	building_height: float,
	wall_surface
) -> void:
	if footprint.size() < 3:
		return

	# Parapet starts at building top
	var parapet_bottom = building_height
	var parapet_top = building_height + PARAPET_HEIGHT

	# Convert footprint to local coordinates
	var local_polygon = []
	for point in footprint:
		local_polygon.append(point - center)

	# Generate parapet for each edge
	for i in range(local_polygon.size()):
		var p1 = local_polygon[i]
		var p2 = local_polygon[(i + 1) % local_polygon.size()]

		_generate_parapet_segment(p1, p2, parapet_bottom, parapet_top, wall_surface)

## Generate parapet segment for one edge
static func _generate_parapet_segment(
	p1: Vector2, p2: Vector2,
	bottom_y: float, top_y: float,
	wall_surface
) -> void:
	var wall_normal = GeometryUtils.calculate_wall_normal(p1, p2)
	var inward_offset = Vector3(wall_normal.x * -PARAPET_THICKNESS, 0, wall_normal.z * -PARAPET_THICKNESS)

	# Outer face vertices
	var outer_bl = Vector3(p1.x, bottom_y, -p1.y)
	var outer_br = Vector3(p2.x, bottom_y, -p2.y)
	var outer_tl = Vector3(p1.x, top_y, -p1.y)
	var outer_tr = Vector3(p2.x, top_y, -p2.y)

	# Inner face vertices (offset inward)
	var inner_bl = outer_bl + inward_offset
	var inner_br = outer_br + inward_offset
	var inner_tl = outer_tl + inward_offset
	var inner_tr = outer_tr + inward_offset

	# Outer face (visible from outside)
	_add_quad(outer_bl, outer_br, outer_tr, outer_tl, wall_normal, wall_surface)

	# Inner face (visible from roof)
	_add_quad(inner_br, inner_bl, inner_tl, inner_tr, -wall_normal, wall_surface)

	# Top cap
	_add_quad(outer_tl, outer_tr, inner_tr, inner_tl, Vector3.UP, wall_surface)

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
