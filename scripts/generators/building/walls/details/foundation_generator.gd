extends Node
class_name FoundationGenerator

## Generates building foundation (darker base at ground level)

const FOUNDATION_HEIGHT = 1.0  # 1m tall darker base
const FOUNDATION_PROTRUSION = 0.05  # 5cm slight protrusion

## Generate foundation band around building perimeter
static func generate(
	footprint: Array,
	center: Vector2,
	wall_surface
) -> void:
	if footprint.size() < 3:
		return

	# Generate foundation band around building perimeter at ground level
	for i in range(footprint.size()):
		var p1 = footprint[i] - center
		var p2 = footprint[(i + 1) % footprint.size()] - center

		# Calculate wall normal (outward direction)
		var wall_dir = (p2 - p1).normalized()
		var wall_normal = Vector3(-wall_dir.y, 0, wall_dir.x)

		# Offset for slight protrusion
		var protrusion_offset = Vector3(wall_normal.x * FOUNDATION_PROTRUSION, 0, wall_normal.z * FOUNDATION_PROTRUSION)

		# Base (at wall surface)
		var base_bl = Vector3(p1.x, 0, -p1.y)
		var base_br = Vector3(p2.x, 0, -p2.y)
		var base_tl = Vector3(p1.x, FOUNDATION_HEIGHT, -p1.y)
		var base_tr = Vector3(p2.x, FOUNDATION_HEIGHT, -p2.y)

		# Protruding edge
		var prot_bl = base_bl + protrusion_offset
		var prot_br = base_br + protrusion_offset
		var prot_tl = base_tl + protrusion_offset
		var prot_tr = base_tr + protrusion_offset

		var base_index = wall_surface.vertices.size()

		# === OUTER FACE (protruding front - darker material) ===
		wall_surface.vertices.append(prot_bl)
		wall_surface.vertices.append(prot_br)
		wall_surface.vertices.append(prot_tr)
		wall_surface.vertices.append(prot_tl)

		for j in range(4):
			wall_surface.normals.append(wall_normal)

		var segment_width = p1.distance_to(p2)
		wall_surface.uvs.append(Vector2(0, 0))
		wall_surface.uvs.append(Vector2(segment_width, 0))
		wall_surface.uvs.append(Vector2(segment_width, FOUNDATION_HEIGHT))
		wall_surface.uvs.append(Vector2(0, FOUNDATION_HEIGHT))

		wall_surface.indices.append(base_index + 0)
		wall_surface.indices.append(base_index + 1)
		wall_surface.indices.append(base_index + 2)
		wall_surface.indices.append(base_index + 0)
		wall_surface.indices.append(base_index + 2)
		wall_surface.indices.append(base_index + 3)

		# === TOP FACE (top of foundation) ===
		var top_base = wall_surface.vertices.size()
		wall_surface.vertices.append(base_tl)
		wall_surface.vertices.append(base_tr)
		wall_surface.vertices.append(prot_tr)
		wall_surface.vertices.append(prot_tl)

		for j in range(4):
			wall_surface.normals.append(Vector3.UP)

		wall_surface.uvs.append(Vector2(0, 0))
		wall_surface.uvs.append(Vector2(segment_width, 0))
		wall_surface.uvs.append(Vector2(segment_width, FOUNDATION_PROTRUSION))
		wall_surface.uvs.append(Vector2(0, FOUNDATION_PROTRUSION))

		wall_surface.indices.append(top_base + 0)
		wall_surface.indices.append(top_base + 1)
		wall_surface.indices.append(top_base + 2)
		wall_surface.indices.append(top_base + 0)
		wall_surface.indices.append(top_base + 2)
		wall_surface.indices.append(top_base + 3)
