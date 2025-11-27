extends Node
class_name BollardGenerator

## Bollard Generator
## Creates short protective posts for sidewalks

## Bollard dimensions
const BOLLARD_HEIGHT = 0.8     # 80cm tall
const BOLLARD_RADIUS = 0.1     # 10cm radius
const CAP_RADIUS = 0.12        # 12cm cap radius
const CAP_HEIGHT = 0.05        # 5cm cap height
const SEGMENTS = 6             # Hexagonal approximation

## Main entry point
static func generate(position: Vector3, parent: Node) -> void:
	var bollard_node = MeshInstance3D.new()
	bollard_node.name = "Bollard"

	var mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()

	# Main post
	_add_cylinder(vertices, normals, uvs, indices, Vector3.ZERO, BOLLARD_RADIUS, BOLLARD_HEIGHT - CAP_HEIGHT)

	# Rounded cap
	_add_cylinder(vertices, normals, uvs, indices, Vector3(0, BOLLARD_HEIGHT - CAP_HEIGHT, 0), CAP_RADIUS, CAP_HEIGHT)
	_add_cap(vertices, normals, uvs, indices, Vector3(0, BOLLARD_HEIGHT, 0), CAP_RADIUS)

	# Create mesh arrays
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	# Metal material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.3, 0.32)  # Dark steel
	material.roughness = 0.5
	material.metallic = 0.6
	mesh.surface_set_material(0, material)

	bollard_node.mesh = mesh
	bollard_node.position = position

	parent.add_child(bollard_node)

## Add cylinder geometry
static func _add_cylinder(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	base_pos: Vector3,
	radius: float,
	height: float
) -> void:
	for i in range(SEGMENTS):
		var angle1 = TAU * i / SEGMENTS
		var angle2 = TAU * (i + 1) / SEGMENTS

		var x1 = cos(angle1) * radius
		var z1 = sin(angle1) * radius
		var x2 = cos(angle2) * radius
		var z2 = sin(angle2) * radius

		var base_idx = vertices.size()

		vertices.append(base_pos + Vector3(x1, 0, z1))
		vertices.append(base_pos + Vector3(x2, 0, z2))
		vertices.append(base_pos + Vector3(x2, height, z2))
		vertices.append(base_pos + Vector3(x1, height, z1))

		var normal = Vector3(cos((angle1 + angle2) / 2), 0, sin((angle1 + angle2) / 2))
		for j in range(4):
			normals.append(normal)

		uvs.append(Vector2(float(i) / SEGMENTS, 0))
		uvs.append(Vector2(float(i + 1) / SEGMENTS, 0))
		uvs.append(Vector2(float(i + 1) / SEGMENTS, 1))
		uvs.append(Vector2(float(i) / SEGMENTS, 1))

		indices.append(base_idx + 0)
		indices.append(base_idx + 1)
		indices.append(base_idx + 2)
		indices.append(base_idx + 0)
		indices.append(base_idx + 2)
		indices.append(base_idx + 3)

## Add top cap
static func _add_cap(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	center: Vector3,
	radius: float
) -> void:
	var center_idx = vertices.size()
	vertices.append(center)
	normals.append(Vector3.UP)
	uvs.append(Vector2(0.5, 0.5))

	for i in range(SEGMENTS):
		var angle = TAU * i / SEGMENTS
		var x = cos(angle) * radius
		var z = sin(angle) * radius

		vertices.append(center + Vector3(x, 0, z))
		normals.append(Vector3.UP)
		uvs.append(Vector2(0.5 + cos(angle) * 0.5, 0.5 + sin(angle) * 0.5))

	for i in range(SEGMENTS):
		indices.append(center_idx)
		indices.append(center_idx + 1 + i)
		indices.append(center_idx + 1 + (i + 1) % SEGMENTS)
