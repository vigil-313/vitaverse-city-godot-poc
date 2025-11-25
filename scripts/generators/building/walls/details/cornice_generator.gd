extends Node
class_name CorniceGenerator

## Generates building cornice (decorative protruding band at top)

const CORNICE_HEIGHT = 0.5  # 50cm decorative band
const CORNICE_PROTRUSION = 0.35  # 35cm protrusion for shadow effect

## Generate cornice band around building perimeter at top
static func generate(
	footprint: Array,
	center: Vector2,
	building_height: float,
	wall_surface
) -> void:
	if footprint.size() < 3:
		return

	var cornice_bottom = building_height - CORNICE_HEIGHT
	var cornice_top = building_height

	# Generate cornice band around building perimeter
	for i in range(footprint.size()):
		var p1 = footprint[i] - center
		var p2 = footprint[(i + 1) % footprint.size()] - center

		# Calculate wall normal (outward direction)
		var wall_dir = (p2 - p1).normalized()
		var wall_normal = Vector3(-wall_dir.y, 0, wall_dir.x)

		# Offset for protrusion
		var protrusion_offset = Vector3(wall_normal.x * CORNICE_PROTRUSION, 0, wall_normal.z * CORNICE_PROTRUSION)

		# Base (at wall surface)
		var base_bl = Vector3(p1.x, cornice_bottom, -p1.y)
		var base_br = Vector3(p2.x, cornice_bottom, -p2.y)
		var base_tl = Vector3(p1.x, cornice_top, -p1.y)
		var base_tr = Vector3(p2.x, cornice_top, -p2.y)

		# Protruding edge
		var prot_bl = base_bl + protrusion_offset
		var prot_br = base_br + protrusion_offset
		var prot_tl = base_tl + protrusion_offset
		var prot_tr = base_tr + protrusion_offset

		var segment_width = p1.distance_to(p2)

		# === OUTER FACE (protruding front - decorative material) ===
		var outer_base = wall_surface.vertices.size()
		wall_surface.vertices.append(prot_bl)
		wall_surface.vertices.append(prot_br)
		wall_surface.vertices.append(prot_tr)
		wall_surface.vertices.append(prot_tl)

		for j in range(4):
			wall_surface.normals.append(wall_normal)

		wall_surface.uvs.append(Vector2(0, 0))
		wall_surface.uvs.append(Vector2(segment_width, 0))
		wall_surface.uvs.append(Vector2(segment_width, CORNICE_HEIGHT))
		wall_surface.uvs.append(Vector2(0, CORNICE_HEIGHT))

		wall_surface.indices.append(outer_base + 0)
		wall_surface.indices.append(outer_base + 1)
		wall_surface.indices.append(outer_base + 2)
		wall_surface.indices.append(outer_base + 0)
		wall_surface.indices.append(outer_base + 2)
		wall_surface.indices.append(outer_base + 3)

		# === BOTTOM FACE (underside of protrusion - creates shadow) ===
		var bottom_base = wall_surface.vertices.size()
		wall_surface.vertices.append(base_bl)
		wall_surface.vertices.append(base_br)
		wall_surface.vertices.append(prot_br)
		wall_surface.vertices.append(prot_bl)

		for j in range(4):
			wall_surface.normals.append(Vector3.DOWN)

		wall_surface.uvs.append(Vector2(0, 0))
		wall_surface.uvs.append(Vector2(segment_width, 0))
		wall_surface.uvs.append(Vector2(segment_width, CORNICE_PROTRUSION))
		wall_surface.uvs.append(Vector2(0, CORNICE_PROTRUSION))

		wall_surface.indices.append(bottom_base + 0)
		wall_surface.indices.append(bottom_base + 1)
		wall_surface.indices.append(bottom_base + 2)
		wall_surface.indices.append(bottom_base + 0)
		wall_surface.indices.append(bottom_base + 2)
		wall_surface.indices.append(bottom_base + 3)

		# === TOP FACE (top of cornice) ===
		var top_base = wall_surface.vertices.size()
		wall_surface.vertices.append(base_tl)
		wall_surface.vertices.append(base_tr)
		wall_surface.vertices.append(prot_tr)
		wall_surface.vertices.append(prot_tl)

		for j in range(4):
			wall_surface.normals.append(Vector3.UP)

		wall_surface.uvs.append(Vector2(0, 0))
		wall_surface.uvs.append(Vector2(segment_width, 0))
		wall_surface.uvs.append(Vector2(segment_width, CORNICE_PROTRUSION))
		wall_surface.uvs.append(Vector2(0, CORNICE_PROTRUSION))

		wall_surface.indices.append(top_base + 0)
		wall_surface.indices.append(top_base + 1)
		wall_surface.indices.append(top_base + 2)
		wall_surface.indices.append(top_base + 0)
		wall_surface.indices.append(top_base + 2)
		wall_surface.indices.append(top_base + 3)
