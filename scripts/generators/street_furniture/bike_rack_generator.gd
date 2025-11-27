extends Node
class_name BikeRackGenerator

## Bike Rack Generator
## Creates U-shaped bike racks (inverted U style)

## Bike rack dimensions
const RACK_HEIGHT = 0.85     # 85cm tall
const RACK_WIDTH = 0.7       # 70cm wide
const RACK_DEPTH = 0.05      # 5cm tube diameter
const NUM_LOOPS = 3          # Number of U-loops
const LOOP_SPACING = 0.5     # 50cm between loops
const SEGMENTS = 6           # Segments for curved top

## Main entry point
static func generate(position: Vector3, facing_angle: float, parent: Node) -> void:
	var rack_node = MeshInstance3D.new()
	rack_node.name = "BikeRack"

	var mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()

	# Generate multiple U-loops
	var total_width = (NUM_LOOPS - 1) * LOOP_SPACING
	var start_offset = -total_width / 2.0

	for i in range(NUM_LOOPS):
		var offset = start_offset + i * LOOP_SPACING
		_add_u_loop(vertices, normals, uvs, indices, Vector3(offset, 0, 0))

	# Connecting bar at base
	if NUM_LOOPS > 1:
		_add_tube_segment(
			vertices, normals, uvs, indices,
			Vector3(start_offset, 0.1, -RACK_WIDTH / 2.0),
			Vector3(start_offset + total_width, 0.1, -RACK_WIDTH / 2.0),
			RACK_DEPTH * 0.5
		)
		_add_tube_segment(
			vertices, normals, uvs, indices,
			Vector3(start_offset, 0.1, RACK_WIDTH / 2.0),
			Vector3(start_offset + total_width, 0.1, RACK_WIDTH / 2.0),
			RACK_DEPTH * 0.5
		)

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
	material.albedo_color = Color(0.6, 0.6, 0.65)  # Steel gray
	material.roughness = 0.4
	material.metallic = 0.7
	mesh.surface_set_material(0, material)

	rack_node.mesh = mesh
	rack_node.position = position
	rack_node.rotation.y = facing_angle

	parent.add_child(rack_node)

## Add a single U-loop
static func _add_u_loop(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	offset: Vector3
) -> void:
	var half_width = RACK_WIDTH / 2.0

	# Left vertical post
	_add_tube_segment(
		vertices, normals, uvs, indices,
		offset + Vector3(0, 0, -half_width),
		offset + Vector3(0, RACK_HEIGHT, -half_width),
		RACK_DEPTH
	)

	# Right vertical post
	_add_tube_segment(
		vertices, normals, uvs, indices,
		offset + Vector3(0, 0, half_width),
		offset + Vector3(0, RACK_HEIGHT, half_width),
		RACK_DEPTH
	)

	# Curved top (semicircle)
	for i in range(SEGMENTS):
		var angle1 = PI * i / SEGMENTS
		var angle2 = PI * (i + 1) / SEGMENTS

		var y1 = RACK_HEIGHT + sin(angle1) * half_width * 0.3
		var z1 = cos(angle1) * half_width
		var y2 = RACK_HEIGHT + sin(angle2) * half_width * 0.3
		var z2 = cos(angle2) * half_width

		_add_tube_segment(
			vertices, normals, uvs, indices,
			offset + Vector3(0, y1, -z1),
			offset + Vector3(0, y2, -z2),
			RACK_DEPTH
		)

## Add a tube segment between two points
static func _add_tube_segment(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	start: Vector3,
	end: Vector3,
	radius: float
) -> void:
	var direction = (end - start).normalized()
	var length = start.distance_to(end)

	# Find perpendicular vectors
	var up = Vector3.UP
	if abs(direction.dot(up)) > 0.9:
		up = Vector3.RIGHT

	var right = direction.cross(up).normalized()
	var actual_up = right.cross(direction).normalized()

	var tube_segments = 6

	for i in range(tube_segments):
		var angle1 = TAU * i / tube_segments
		var angle2 = TAU * (i + 1) / tube_segments

		var offset1 = (right * cos(angle1) + actual_up * sin(angle1)) * radius
		var offset2 = (right * cos(angle2) + actual_up * sin(angle2)) * radius

		var base_idx = vertices.size()

		vertices.append(start + offset1)
		vertices.append(start + offset2)
		vertices.append(end + offset2)
		vertices.append(end + offset1)

		var normal1 = offset1.normalized()
		var normal2 = offset2.normalized()

		normals.append(normal1)
		normals.append(normal2)
		normals.append(normal2)
		normals.append(normal1)

		uvs.append(Vector2(float(i) / tube_segments, 0))
		uvs.append(Vector2(float(i + 1) / tube_segments, 0))
		uvs.append(Vector2(float(i + 1) / tube_segments, 1))
		uvs.append(Vector2(float(i) / tube_segments, 1))

		indices.append(base_idx + 0)
		indices.append(base_idx + 1)
		indices.append(base_idx + 2)
		indices.append(base_idx + 0)
		indices.append(base_idx + 2)
		indices.append(base_idx + 3)
