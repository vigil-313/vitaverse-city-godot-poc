extends Node
class_name FloorLedgeGenerator

## Generates horizontal decorative ledges between floors

const LEDGE_HEIGHT = 0.25  # 25cm decorative band
const LEDGE_PROTRUSION = 0.20  # 20cm protrusion

## Generate floor ledges at each level boundary
static func generate(
	footprint: Array,
	center: Vector2,
	floor_height: float,
	levels: int,
	wall_surface
) -> void:
	if footprint.size() < 3 or levels < 2:
		return

	# Generate ledge at each floor level (skip ground and top)
	for level in range(1, levels):
		var ledge_y = level * floor_height
		var ledge_bottom = ledge_y - (LEDGE_HEIGHT / 2.0)
		var ledge_top = ledge_y + (LEDGE_HEIGHT / 2.0)

		# Generate ledge band around building perimeter
		for i in range(footprint.size()):
			var p1 = footprint[i] - center
			var p2 = footprint[(i + 1) % footprint.size()] - center

			# Calculate wall normal (outward direction)
			var wall_dir = (p2 - p1).normalized()
			var wall_normal = Vector3(-wall_dir.y, 0, wall_dir.x)

			# Offset for protrusion
			var protrusion_offset = Vector3(wall_normal.x * LEDGE_PROTRUSION, 0, wall_normal.z * LEDGE_PROTRUSION)

			# Base (at wall surface)
			var base_bl = Vector3(p1.x, ledge_bottom, -p1.y)
			var base_br = Vector3(p2.x, ledge_bottom, -p2.y)
			var base_tl = Vector3(p1.x, ledge_top, -p1.y)
			var base_tr = Vector3(p2.x, ledge_top, -p2.y)

			# Protruding edge
			var prot_bl = base_bl + protrusion_offset
			var prot_br = base_br + protrusion_offset
			var prot_tl = base_tl + protrusion_offset
			var prot_tr = base_tr + protrusion_offset

			var segment_width = p1.distance_to(p2)

			# === OUTER FACE (protruding front) ===
			var outer_base = wall_surface.vertices.size()
			wall_surface.vertices.append(prot_bl)
			wall_surface.vertices.append(prot_br)
			wall_surface.vertices.append(prot_tr)
			wall_surface.vertices.append(prot_tl)

			for j in range(4):
				wall_surface.normals.append(wall_normal)

			wall_surface.uvs.append(Vector2(0, 0))
			wall_surface.uvs.append(Vector2(segment_width, 0))
			wall_surface.uvs.append(Vector2(segment_width, LEDGE_HEIGHT))
			wall_surface.uvs.append(Vector2(0, LEDGE_HEIGHT))

			wall_surface.indices.append(outer_base + 0)
			wall_surface.indices.append(outer_base + 1)
			wall_surface.indices.append(outer_base + 2)
			wall_surface.indices.append(outer_base + 0)
			wall_surface.indices.append(outer_base + 2)
			wall_surface.indices.append(outer_base + 3)

			# === BOTTOM FACE (underside of ledge) ===
			var bottom_base = wall_surface.vertices.size()
			wall_surface.vertices.append(base_bl)
			wall_surface.vertices.append(base_br)
			wall_surface.vertices.append(prot_br)
			wall_surface.vertices.append(prot_bl)

			for j in range(4):
				wall_surface.normals.append(Vector3.DOWN)

			wall_surface.uvs.append(Vector2(0, 0))
			wall_surface.uvs.append(Vector2(segment_width, 0))
			wall_surface.uvs.append(Vector2(segment_width, LEDGE_PROTRUSION))
			wall_surface.uvs.append(Vector2(0, LEDGE_PROTRUSION))

			wall_surface.indices.append(bottom_base + 0)
			wall_surface.indices.append(bottom_base + 1)
			wall_surface.indices.append(bottom_base + 2)
			wall_surface.indices.append(bottom_base + 0)
			wall_surface.indices.append(bottom_base + 2)
			wall_surface.indices.append(bottom_base + 3)

			# === TOP FACE (top of ledge) ===
			var top_base = wall_surface.vertices.size()
			wall_surface.vertices.append(base_tl)
			wall_surface.vertices.append(base_tr)
			wall_surface.vertices.append(prot_tr)
			wall_surface.vertices.append(prot_tl)

			for j in range(4):
				wall_surface.normals.append(Vector3.UP)

			wall_surface.uvs.append(Vector2(0, 0))
			wall_surface.uvs.append(Vector2(segment_width, 0))
			wall_surface.uvs.append(Vector2(segment_width, LEDGE_PROTRUSION))
			wall_surface.uvs.append(Vector2(0, LEDGE_PROTRUSION))

			wall_surface.indices.append(top_base + 0)
			wall_surface.indices.append(top_base + 1)
			wall_surface.indices.append(top_base + 2)
			wall_surface.indices.append(top_base + 0)
			wall_surface.indices.append(top_base + 2)
			wall_surface.indices.append(top_base + 3)
