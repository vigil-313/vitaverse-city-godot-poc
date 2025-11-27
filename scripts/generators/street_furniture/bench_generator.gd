extends Node
class_name BenchGenerator

## Park/Street Bench Generator
## Creates simple wooden benches with metal frames

## Bench dimensions
const BENCH_LENGTH = 1.5      # 1.5m long
const BENCH_DEPTH = 0.5       # 50cm deep
const SEAT_HEIGHT = 0.45      # 45cm seat height
const BACK_HEIGHT = 0.4       # 40cm back height
const LEG_WIDTH = 0.08        # 8cm leg width
const SLAT_THICKNESS = 0.04   # 4cm thick slats

## Main entry point
static func generate(position: Vector3, facing_angle: float, parent: Node) -> void:
	var bench_node = MeshInstance3D.new()
	bench_node.name = "Bench"

	var mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()

	# Generate bench geometry
	_add_bench_geometry(vertices, normals, uvs, indices)

	# Create mesh arrays
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	# Wood material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.35, 0.2)  # Wood brown
	material.roughness = 0.8
	mesh.surface_set_material(0, material)

	bench_node.mesh = mesh
	bench_node.position = position
	bench_node.rotation.y = facing_angle

	parent.add_child(bench_node)

## Generate bench geometry
static func _add_bench_geometry(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array
) -> void:
	var half_length = BENCH_LENGTH / 2.0
	var half_depth = BENCH_DEPTH / 2.0

	# Seat (horizontal planks)
	var num_slats = 4
	var slat_spacing = BENCH_DEPTH / float(num_slats)

	for i in range(num_slats):
		var slat_z = -half_depth + slat_spacing * (i + 0.5)
		_add_box(
			vertices, normals, uvs, indices,
			Vector3(0, SEAT_HEIGHT, slat_z),
			Vector3(BENCH_LENGTH, SLAT_THICKNESS, slat_spacing * 0.8)
		)

	# Back rest (vertical planks)
	for i in range(num_slats):
		var slat_z = -half_depth + slat_spacing * (i + 0.5)
		_add_box(
			vertices, normals, uvs, indices,
			Vector3(0, SEAT_HEIGHT + BACK_HEIGHT / 2.0, -half_depth - 0.05),
			Vector3(BENCH_LENGTH, BACK_HEIGHT, SLAT_THICKNESS)
		)

	# Legs (4 corners)
	var leg_positions = [
		Vector3(-half_length + 0.1, SEAT_HEIGHT / 2.0, half_depth - 0.1),
		Vector3(-half_length + 0.1, SEAT_HEIGHT / 2.0, -half_depth + 0.1),
		Vector3(half_length - 0.1, SEAT_HEIGHT / 2.0, half_depth - 0.1),
		Vector3(half_length - 0.1, SEAT_HEIGHT / 2.0, -half_depth + 0.1),
	]

	for leg_pos in leg_positions:
		_add_box(
			vertices, normals, uvs, indices,
			leg_pos,
			Vector3(LEG_WIDTH, SEAT_HEIGHT, LEG_WIDTH)
		)

	# Armrests
	_add_box(
		vertices, normals, uvs, indices,
		Vector3(-half_length + 0.1, SEAT_HEIGHT + 0.15, 0),
		Vector3(LEG_WIDTH, 0.06, BENCH_DEPTH)
	)
	_add_box(
		vertices, normals, uvs, indices,
		Vector3(half_length - 0.1, SEAT_HEIGHT + 0.15, 0),
		Vector3(LEG_WIDTH, 0.06, BENCH_DEPTH)
	)

## Add a box (centered)
static func _add_box(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	center: Vector3,
	size: Vector3
) -> void:
	var half = size / 2.0
	var base_idx = vertices.size()

	# 8 corners
	var corners = [
		center + Vector3(-half.x, -half.y, -half.z),  # 0: left-bottom-back
		center + Vector3(half.x, -half.y, -half.z),   # 1: right-bottom-back
		center + Vector3(half.x, -half.y, half.z),    # 2: right-bottom-front
		center + Vector3(-half.x, -half.y, half.z),   # 3: left-bottom-front
		center + Vector3(-half.x, half.y, -half.z),   # 4: left-top-back
		center + Vector3(half.x, half.y, -half.z),    # 5: right-top-back
		center + Vector3(half.x, half.y, half.z),     # 6: right-top-front
		center + Vector3(-half.x, half.y, half.z),    # 7: left-top-front
	]

	# 6 faces with proper normals
	var faces = [
		[0, 1, 5, 4, Vector3(0, 0, -1)],   # Back
		[2, 3, 7, 6, Vector3(0, 0, 1)],    # Front
		[3, 0, 4, 7, Vector3(-1, 0, 0)],   # Left
		[1, 2, 6, 5, Vector3(1, 0, 0)],    # Right
		[4, 5, 6, 7, Vector3(0, 1, 0)],    # Top
		[3, 2, 1, 0, Vector3(0, -1, 0)],   # Bottom
	]

	for face in faces:
		var face_base = vertices.size()

		vertices.append(corners[face[0]])
		vertices.append(corners[face[1]])
		vertices.append(corners[face[2]])
		vertices.append(corners[face[3]])

		for j in range(4):
			normals.append(face[4])

		uvs.append(Vector2(0, 0))
		uvs.append(Vector2(1, 0))
		uvs.append(Vector2(1, 1))
		uvs.append(Vector2(0, 1))

		indices.append(face_base + 0)
		indices.append(face_base + 1)
		indices.append(face_base + 2)
		indices.append(face_base + 0)
		indices.append(face_base + 2)
		indices.append(face_base + 3)
