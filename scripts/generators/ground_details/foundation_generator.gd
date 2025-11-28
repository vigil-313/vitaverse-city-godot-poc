extends Node
class_name BuildingFoundation

## Building Foundation Generator
## Creates a small foundation ledge around building bases

## Foundation dimensions
const FOUNDATION_HEIGHT = 0.15   # 15cm tall foundation
const FOUNDATION_DEPTH = 0.1     # 10cm outward projection
const FOUNDATION_INSET = 0.02    # 2cm inset for visual depth

## Main entry point - generate foundation around building
static func generate_for_building(
	footprint: Array,
	center: Vector2,
	parent: Node,
	heightmap = null
) -> void:
	if footprint.size() < 3:
		return

	var foundation_node = MeshInstance3D.new()
	foundation_node.name = "Foundation"

	var mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()

	# Get terrain elevation at building center
	var center_elevation = 0.0
	if heightmap:
		center_elevation = heightmap.get_elevation(center.x, -center.y)

	# Generate foundation segments for each wall
	for i in range(footprint.size()):
		var p1 = footprint[i]
		var p2 = footprint[(i + 1) % footprint.size()]

		_add_foundation_segment(p1, p2, center, center_elevation, vertices, normals, uvs, indices, heightmap)

	if vertices.size() == 0:
		return

	# Create mesh arrays
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	# Stone/concrete material (darker than walls)
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.45, 0.43, 0.4)  # Dark gray stone
	material.roughness = 0.85
	mesh.surface_set_material(0, material)

	foundation_node.mesh = mesh
	parent.add_child(foundation_node)

## Add foundation segment along one wall
static func _add_foundation_segment(
	p1: Vector2,
	p2: Vector2,
	center: Vector2,
	center_elevation: float,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	heightmap = null
) -> void:
	var wall_dir = (p2 - p1).normalized()
	var wall_normal = Vector2(-wall_dir.y, wall_dir.x)

	# Ensure normal points away from building center
	var wall_center = (p1 + p2) / 2.0
	if wall_normal.dot(wall_center - center) < 0:
		wall_normal = -wall_normal

	var wall_length = p1.distance_to(p2)

	# Inner edge (at building wall, slightly inset)
	var inset = wall_normal * (-FOUNDATION_INSET)
	var inner_p1 = p1 + inset
	var inner_p2 = p2 + inset

	# Outer edge (projecting outward)
	var outer_p1 = p1 + wall_normal * FOUNDATION_DEPTH
	var outer_p2 = p2 + wall_normal * FOUNDATION_DEPTH

	# Get terrain elevation at each corner
	var elev_inner_1 = center_elevation
	var elev_inner_2 = center_elevation
	var elev_outer_1 = center_elevation
	var elev_outer_2 = center_elevation
	if heightmap:
		elev_inner_1 = heightmap.get_elevation(inner_p1.x, -inner_p1.y)
		elev_inner_2 = heightmap.get_elevation(inner_p2.x, -inner_p2.y)
		elev_outer_1 = heightmap.get_elevation(outer_p1.x, -outer_p1.y)
		elev_outer_2 = heightmap.get_elevation(outer_p2.x, -outer_p2.y)

	# Convert to 3D with terrain elevation
	var v_inner_1_top = Vector3(inner_p1.x, elev_inner_1 + FOUNDATION_HEIGHT, -inner_p1.y)
	var v_inner_2_top = Vector3(inner_p2.x, elev_inner_2 + FOUNDATION_HEIGHT, -inner_p2.y)
	var v_outer_1_top = Vector3(outer_p1.x, elev_outer_1 + FOUNDATION_HEIGHT, -outer_p1.y)
	var v_outer_2_top = Vector3(outer_p2.x, elev_outer_2 + FOUNDATION_HEIGHT, -outer_p2.y)
	var v_outer_1_bottom = Vector3(outer_p1.x, elev_outer_1, -outer_p1.y)
	var v_outer_2_bottom = Vector3(outer_p2.x, elev_outer_2, -outer_p2.y)

	# Top surface (horizontal ledge)
	var base_idx = vertices.size()

	vertices.append(v_inner_1_top)
	vertices.append(v_inner_2_top)
	vertices.append(v_outer_2_top)
	vertices.append(v_outer_1_top)

	for j in range(4):
		normals.append(Vector3.UP)

	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(wall_length, 0))
	uvs.append(Vector2(wall_length, 1))
	uvs.append(Vector2(0, 1))

	indices.append(base_idx + 0)
	indices.append(base_idx + 1)
	indices.append(base_idx + 2)
	indices.append(base_idx + 0)
	indices.append(base_idx + 2)
	indices.append(base_idx + 3)

	# Front face (vertical)
	base_idx = vertices.size()

	vertices.append(v_outer_1_bottom)
	vertices.append(v_outer_2_bottom)
	vertices.append(v_outer_2_top)
	vertices.append(v_outer_1_top)

	var front_normal = Vector3(wall_normal.x, 0, -wall_normal.y)
	for j in range(4):
		normals.append(front_normal)

	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(wall_length, 0))
	uvs.append(Vector2(wall_length, FOUNDATION_HEIGHT))
	uvs.append(Vector2(0, FOUNDATION_HEIGHT))

	indices.append(base_idx + 0)
	indices.append(base_idx + 1)
	indices.append(base_idx + 2)
	indices.append(base_idx + 0)
	indices.append(base_idx + 2)
	indices.append(base_idx + 3)
