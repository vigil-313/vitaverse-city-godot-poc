extends Node
class_name StreetLampFurniture

## Street Lamp Furniture Generator
## Creates traditional street lamps with light sources

## Lamp dimensions
const POLE_HEIGHT = 4.5        # 4.5m tall pole
const POLE_RADIUS = 0.06       # 6cm radius
const ARM_LENGTH = 0.8         # 80cm arm extension
const LAMP_SIZE = 0.35         # 35cm lamp housing
const LAMP_HEIGHT = 0.5        # 50cm lamp housing height
const BASE_HEIGHT = 0.3        # 30cm decorative base
const BASE_RADIUS = 0.15       # 15cm base radius
const SEGMENTS = 6             # Hexagonal approximation

## Main entry point
static func generate(position: Vector3, parent: Node) -> void:
	var lamp_node = Node3D.new()
	lamp_node.name = "StreetLamp"

	# Create pole mesh
	var pole_mesh = _create_pole_mesh()
	var pole_instance = MeshInstance3D.new()
	pole_instance.mesh = pole_mesh
	lamp_node.add_child(pole_instance)

	# Create lamp housing mesh
	var housing_mesh = _create_housing_mesh()
	var housing_instance = MeshInstance3D.new()
	housing_instance.mesh = housing_mesh
	housing_instance.position = Vector3(ARM_LENGTH * 0.5, POLE_HEIGHT, 0)
	lamp_node.add_child(housing_instance)

	# Add light source
	var light = OmniLight3D.new()
	light.position = Vector3(ARM_LENGTH * 0.5, POLE_HEIGHT - LAMP_HEIGHT * 0.3, 0)
	light.light_color = Color(1.0, 0.95, 0.8)  # Warm white
	light.light_energy = 2.0
	light.omni_range = 15.0
	light.omni_attenuation = 1.5
	light.shadow_enabled = false  # Performance - too many lamps for shadows
	lamp_node.add_child(light)

	lamp_node.position = position
	parent.add_child(lamp_node)

## Create pole and base mesh
static func _create_pole_mesh() -> ArrayMesh:
	var mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()

	# Decorative base (wider bottom)
	_add_cylinder(vertices, normals, uvs, indices, Vector3.ZERO, BASE_RADIUS, BASE_HEIGHT)

	# Main pole
	_add_cylinder(vertices, normals, uvs, indices, Vector3(0, BASE_HEIGHT, 0), POLE_RADIUS, POLE_HEIGHT - BASE_HEIGHT)

	# Arm (horizontal extension)
	_add_arm(vertices, normals, uvs, indices, Vector3(0, POLE_HEIGHT, 0), ARM_LENGTH)

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	# Dark metal material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.15, 0.15, 0.15)  # Dark iron
	material.roughness = 0.6
	material.metallic = 0.5
	mesh.surface_set_material(0, material)

	return mesh

## Create lamp housing mesh
static func _create_housing_mesh() -> ArrayMesh:
	var mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()

	# Lamp housing (lantern style)
	_add_lantern(vertices, normals, uvs, indices, Vector3.ZERO)

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	# Glass/metal material with emission
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.85, 0.7)  # Warm glass
	material.roughness = 0.3
	material.emission_enabled = true
	material.emission = Color(1.0, 0.9, 0.7)
	material.emission_energy_multiplier = 2.0
	mesh.surface_set_material(0, material)

	return mesh

## Add lantern housing geometry
static func _add_lantern(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	pos: Vector3
) -> void:
	var half_size = LAMP_SIZE / 2.0
	var height = LAMP_HEIGHT

	# Create 4-sided lantern
	var corners_bottom = [
		pos + Vector3(-half_size, 0, -half_size),
		pos + Vector3(half_size, 0, -half_size),
		pos + Vector3(half_size, 0, half_size),
		pos + Vector3(-half_size, 0, half_size),
	]

	var corners_top = [
		pos + Vector3(-half_size * 0.7, -height, -half_size * 0.7),
		pos + Vector3(half_size * 0.7, -height, -half_size * 0.7),
		pos + Vector3(half_size * 0.7, -height, half_size * 0.7),
		pos + Vector3(-half_size * 0.7, -height, half_size * 0.7),
	]

	# Side faces (glass panels)
	var face_normals = [
		Vector3(0, 0, -1),
		Vector3(1, 0, 0),
		Vector3(0, 0, 1),
		Vector3(-1, 0, 0),
	]

	for i in range(4):
		var next = (i + 1) % 4
		var base_idx = vertices.size()

		vertices.append(corners_bottom[i])
		vertices.append(corners_bottom[next])
		vertices.append(corners_top[next])
		vertices.append(corners_top[i])

		for j in range(4):
			normals.append(face_normals[i])

		uvs.append(Vector2(0, 0))
		uvs.append(Vector2(1, 0))
		uvs.append(Vector2(1, 1))
		uvs.append(Vector2(0, 1))

		indices.append(base_idx + 0)
		indices.append(base_idx + 1)
		indices.append(base_idx + 2)
		indices.append(base_idx + 0)
		indices.append(base_idx + 2)
		indices.append(base_idx + 3)

	# Bottom cap
	var base_idx = vertices.size()
	for corner in corners_top:
		vertices.append(corner)
		normals.append(Vector3.DOWN)
	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(1, 0))
	uvs.append(Vector2(1, 1))
	uvs.append(Vector2(0, 1))

	indices.append(base_idx + 0)
	indices.append(base_idx + 1)
	indices.append(base_idx + 2)
	indices.append(base_idx + 0)
	indices.append(base_idx + 2)
	indices.append(base_idx + 3)

## Add arm geometry
static func _add_arm(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	start: Vector3,
	length: float
) -> void:
	var arm_radius = POLE_RADIUS * 0.7
	var end = start + Vector3(length, 0, 0)

	# Curved arm (slight droop)
	var mid = (start + end) / 2.0 + Vector3(0, -0.1, 0)

	# Simplified as two segments
	_add_tube(vertices, normals, uvs, indices, start, mid, arm_radius)
	_add_tube(vertices, normals, uvs, indices, mid, end, arm_radius)

## Add a simple tube between two points
static func _add_tube(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	start: Vector3,
	end: Vector3,
	radius: float
) -> void:
	var direction = (end - start).normalized()
	var right = direction.cross(Vector3.UP).normalized()
	if right.length() < 0.1:
		right = direction.cross(Vector3.RIGHT).normalized()
	var up = right.cross(direction).normalized()

	for i in range(SEGMENTS):
		var angle1 = TAU * i / SEGMENTS
		var angle2 = TAU * (i + 1) / SEGMENTS

		var offset1 = (right * cos(angle1) + up * sin(angle1)) * radius
		var offset2 = (right * cos(angle2) + up * sin(angle2)) * radius

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

		uvs.append(Vector2(0, 0))
		uvs.append(Vector2(1, 0))
		uvs.append(Vector2(1, 1))
		uvs.append(Vector2(0, 1))

		indices.append(base_idx + 0)
		indices.append(base_idx + 1)
		indices.append(base_idx + 2)
		indices.append(base_idx + 0)
		indices.append(base_idx + 2)
		indices.append(base_idx + 3)

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
