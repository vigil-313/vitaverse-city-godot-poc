extends Node
class_name SidewalkGenerator

## Sidewalk Generator
## Creates concrete sidewalk strips around building perimeters

## Sidewalk dimensions
const SIDEWALK_WIDTH = 2.5    # 2.5m wide sidewalk
const SIDEWALK_HEIGHT = 0.08  # 8cm raised from ground
const TEXTURE_SCALE = 2.0     # UV tiling

## Main entry point - generate sidewalk around building
static func generate_around_building(
	footprint: Array,
	center: Vector2,
	parent: Node
) -> void:
	if footprint.size() < 3:
		return

	var sidewalk_node = MeshInstance3D.new()
	sidewalk_node.name = "Sidewalk"

	var mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()

	# Generate sidewalk segments for each wall
	for i in range(footprint.size()):
		var p1 = footprint[i]
		var p2 = footprint[(i + 1) % footprint.size()]

		_add_sidewalk_segment(p1, p2, center, vertices, normals, uvs, indices)

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

	# Concrete material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.75, 0.73, 0.7)  # Light gray concrete
	material.roughness = 0.9
	mesh.surface_set_material(0, material)

	sidewalk_node.mesh = mesh
	parent.add_child(sidewalk_node)

## Add a sidewalk segment along one wall
static func _add_sidewalk_segment(
	p1: Vector2,
	p2: Vector2,
	center: Vector2,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array
) -> void:
	var wall_dir = (p2 - p1).normalized()
	var wall_normal = Vector2(-wall_dir.y, wall_dir.x)

	# Ensure normal points away from building center
	var wall_center = (p1 + p2) / 2.0
	if wall_normal.dot(wall_center - center) < 0:
		wall_normal = -wall_normal

	var wall_length = p1.distance_to(p2)

	# Inner edge (at building wall)
	var inner_p1 = p1
	var inner_p2 = p2

	# Outer edge (away from building)
	var outer_p1 = p1 + wall_normal * SIDEWALK_WIDTH
	var outer_p2 = p2 + wall_normal * SIDEWALK_WIDTH

	# Convert to 3D
	var v_inner_1 = Vector3(inner_p1.x, SIDEWALK_HEIGHT, -inner_p1.y)
	var v_inner_2 = Vector3(inner_p2.x, SIDEWALK_HEIGHT, -inner_p2.y)
	var v_outer_1 = Vector3(outer_p1.x, SIDEWALK_HEIGHT, -outer_p1.y)
	var v_outer_2 = Vector3(outer_p2.x, SIDEWALK_HEIGHT, -outer_p2.y)

	# Top surface quad
	var base_idx = vertices.size()

	vertices.append(v_inner_1)
	vertices.append(v_inner_2)
	vertices.append(v_outer_2)
	vertices.append(v_outer_1)

	for j in range(4):
		normals.append(Vector3.UP)

	# UV based on world position for seamless tiling
	uvs.append(Vector2(inner_p1.x / TEXTURE_SCALE, inner_p1.y / TEXTURE_SCALE))
	uvs.append(Vector2(inner_p2.x / TEXTURE_SCALE, inner_p2.y / TEXTURE_SCALE))
	uvs.append(Vector2(outer_p2.x / TEXTURE_SCALE, outer_p2.y / TEXTURE_SCALE))
	uvs.append(Vector2(outer_p1.x / TEXTURE_SCALE, outer_p1.y / TEXTURE_SCALE))

	indices.append(base_idx + 0)
	indices.append(base_idx + 1)
	indices.append(base_idx + 2)
	indices.append(base_idx + 0)
	indices.append(base_idx + 2)
	indices.append(base_idx + 3)

	# Outer edge (vertical face)
	var v_outer_1_bottom = Vector3(outer_p1.x, 0, -outer_p1.y)
	var v_outer_2_bottom = Vector3(outer_p2.x, 0, -outer_p2.y)

	base_idx = vertices.size()

	vertices.append(v_outer_1_bottom)
	vertices.append(v_outer_2_bottom)
	vertices.append(v_outer_2)
	vertices.append(v_outer_1)

	var edge_normal = Vector3(wall_normal.x, 0, -wall_normal.y)
	for j in range(4):
		normals.append(edge_normal)

	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(wall_length / TEXTURE_SCALE, 0))
	uvs.append(Vector2(wall_length / TEXTURE_SCALE, SIDEWALK_HEIGHT))
	uvs.append(Vector2(0, SIDEWALK_HEIGHT))

	indices.append(base_idx + 0)
	indices.append(base_idx + 1)
	indices.append(base_idx + 2)
	indices.append(base_idx + 0)
	indices.append(base_idx + 2)
	indices.append(base_idx + 3)
