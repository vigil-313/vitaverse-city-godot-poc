extends Node
class_name FloorSlabGenerator

## Generates horizontal floor slabs at each level (structural concrete floors)

const SLAB_THICKNESS = 0.25  # 25cm thick concrete slabs

## Generate horizontal floor slabs at each level
static func generate(
	footprint: Array,
	center: Vector2,
	floor_height: float,
	levels: int,
	wall_surface
) -> void:
	if footprint.size() < 3 or levels < 2:
		return

	# Convert footprint to local coordinates
	var local_polygon = []
	for point in footprint:
		local_polygon.append(point - center)

	# Use Godot's built-in triangulation for floor shape
	var floor_indices_raw = PolygonTriangulator.triangulate(local_polygon)

	# Generate floor slabs at each level (skip ground floor at 0, skip roof)
	for level in range(1, levels):
		var slab_bottom_y = level * floor_height
		var slab_top_y = slab_bottom_y + SLAB_THICKNESS

		# === BOTTOM FACE (ceiling of below floor) ===
		var bottom_base = wall_surface.vertices.size()

		for point in local_polygon:
			wall_surface.vertices.append(Vector3(point.x, slab_bottom_y, -point.y))
			wall_surface.normals.append(Vector3.DOWN)
			wall_surface.uvs.append(Vector2(point.x, point.y))

		# Add triangulated indices with REVERSED winding (for downward normal)
		for i in range(0, floor_indices_raw.size(), 3):
			wall_surface.indices.append(bottom_base + floor_indices_raw[i + 2])
			wall_surface.indices.append(bottom_base + floor_indices_raw[i + 1])
			wall_surface.indices.append(bottom_base + floor_indices_raw[i])

		# === TOP FACE (floor of above floor) ===
		var top_base = wall_surface.vertices.size()

		for point in local_polygon:
			wall_surface.vertices.append(Vector3(point.x, slab_top_y, -point.y))
			wall_surface.normals.append(Vector3.UP)
			wall_surface.uvs.append(Vector2(point.x, point.y))

		# Add triangulated indices with NORMAL winding (for upward normal)
		for i in range(0, floor_indices_raw.size(), 3):
			wall_surface.indices.append(top_base + floor_indices_raw[i])
			wall_surface.indices.append(top_base + floor_indices_raw[i + 1])
			wall_surface.indices.append(top_base + floor_indices_raw[i + 2])

		# === EDGE FACES (sides of slab visible from exterior) ===
		for i in range(local_polygon.size()):
			var p1 = local_polygon[i]
			var p2 = local_polygon[(i + 1) % local_polygon.size()]

			# Calculate outward normal
			var edge_dir = (p2 - p1).normalized()
			var edge_normal = Vector3(-edge_dir.y, 0, edge_dir.x)

			var edge_base = wall_surface.vertices.size()

			# Edge quad vertices
			var edge_bl = Vector3(p1.x, slab_bottom_y, -p1.y)
			var edge_br = Vector3(p2.x, slab_bottom_y, -p2.y)
			var edge_tl = Vector3(p1.x, slab_top_y, -p1.y)
			var edge_tr = Vector3(p2.x, slab_top_y, -p2.y)

			wall_surface.vertices.append(edge_bl)
			wall_surface.vertices.append(edge_br)
			wall_surface.vertices.append(edge_tr)
			wall_surface.vertices.append(edge_tl)

			for j in range(4):
				wall_surface.normals.append(edge_normal)

			var edge_length = p1.distance_to(p2)
			wall_surface.uvs.append(Vector2(0, 0))
			wall_surface.uvs.append(Vector2(edge_length, 0))
			wall_surface.uvs.append(Vector2(edge_length, SLAB_THICKNESS))
			wall_surface.uvs.append(Vector2(0, SLAB_THICKNESS))

			wall_surface.indices.append(edge_base + 0)
			wall_surface.indices.append(edge_base + 1)
			wall_surface.indices.append(edge_base + 2)
			wall_surface.indices.append(edge_base + 0)
			wall_surface.indices.append(edge_base + 2)
			wall_surface.indices.append(edge_base + 3)
