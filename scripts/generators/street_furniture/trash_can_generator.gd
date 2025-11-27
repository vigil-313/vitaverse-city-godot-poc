extends Node
class_name TrashCanGenerator

## Street Trash Can Generator
## Creates cylindrical public trash cans

## Trash can dimensions
const CAN_RADIUS = 0.25      # 25cm radius
const CAN_HEIGHT = 0.9       # 90cm tall
const RIM_HEIGHT = 0.05      # 5cm rim
const RIM_EXTRA = 0.03       # 3cm rim overhang
const SEGMENTS = 8           # Octagonal approximation

## Main entry point
static func generate(position: Vector3, parent: Node) -> void:
	var can_node = MeshInstance3D.new()
	can_node.name = "TrashCan"

	var mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()

	# Generate trash can geometry
	_add_cylinder(vertices, normals, uvs, indices, Vector3.ZERO, CAN_RADIUS, CAN_HEIGHT - RIM_HEIGHT)
	_add_cylinder(vertices, normals, uvs, indices, Vector3(0, CAN_HEIGHT - RIM_HEIGHT, 0), CAN_RADIUS + RIM_EXTRA, RIM_HEIGHT)

	# Create mesh arrays
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	# Dark metal material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.28, 0.25)  # Dark green-gray
	material.roughness = 0.7
	material.metallic = 0.3
	mesh.surface_set_material(0, material)

	can_node.mesh = mesh
	can_node.position = position

	parent.add_child(can_node)

## Generate cylinder geometry
static func _add_cylinder(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	base_pos: Vector3,
	radius: float,
	height: float
) -> void:
	# Side faces
	for i in range(SEGMENTS):
		var angle1 = TAU * i / SEGMENTS
		var angle2 = TAU * (i + 1) / SEGMENTS

		var x1 = cos(angle1) * radius
		var z1 = sin(angle1) * radius
		var x2 = cos(angle2) * radius
		var z2 = sin(angle2) * radius

		var base_idx = vertices.size()

		# 4 vertices for this quad
		vertices.append(base_pos + Vector3(x1, 0, z1))
		vertices.append(base_pos + Vector3(x2, 0, z2))
		vertices.append(base_pos + Vector3(x2, height, z2))
		vertices.append(base_pos + Vector3(x1, height, z1))

		# Normal pointing outward
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

	# Top cap
	var center_idx = vertices.size()
	vertices.append(base_pos + Vector3(0, height, 0))
	normals.append(Vector3.UP)
	uvs.append(Vector2(0.5, 0.5))

	for i in range(SEGMENTS):
		var angle = TAU * i / SEGMENTS
		var x = cos(angle) * radius
		var z = sin(angle) * radius

		vertices.append(base_pos + Vector3(x, height, z))
		normals.append(Vector3.UP)
		uvs.append(Vector2(0.5 + cos(angle) * 0.5, 0.5 + sin(angle) * 0.5))

	for i in range(SEGMENTS):
		indices.append(center_idx)
		indices.append(center_idx + 1 + i)
		indices.append(center_idx + 1 + (i + 1) % SEGMENTS)

	# Bottom cap (facing down)
	center_idx = vertices.size()
	vertices.append(base_pos)
	normals.append(Vector3.DOWN)
	uvs.append(Vector2(0.5, 0.5))

	for i in range(SEGMENTS):
		var angle = TAU * i / SEGMENTS
		var x = cos(angle) * radius
		var z = sin(angle) * radius

		vertices.append(base_pos + Vector3(x, 0, z))
		normals.append(Vector3.DOWN)
		uvs.append(Vector2(0.5 + cos(angle) * 0.5, 0.5 + sin(angle) * 0.5))

	for i in range(SEGMENTS):
		indices.append(center_idx)
		indices.append(center_idx + 1 + (i + 1) % SEGMENTS)
		indices.append(center_idx + 1 + i)
