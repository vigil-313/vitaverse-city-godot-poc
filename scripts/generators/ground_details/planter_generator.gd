extends Node
class_name GroundPlanterGenerator

## Ground Planter Generator
## Creates decorative street planters with plants

## Planter dimensions
const PLANTER_SIZES = [
	Vector3(0.8, 0.5, 0.8),   # Small square
	Vector3(1.2, 0.6, 0.6),   # Medium rectangular
	Vector3(1.0, 0.5, 1.0),   # Large square
]

const PLANTER_WALL_THICKNESS = 0.08
const SOIL_INSET = 0.05
const PLANT_HEIGHT_MIN = 0.3
const PLANT_HEIGHT_MAX = 0.6

## Planter colors
const PLANTER_COLORS = [
	Color(0.5, 0.45, 0.4),    # Terracotta
	Color(0.35, 0.35, 0.35),  # Dark gray concrete
	Color(0.55, 0.5, 0.45),   # Light stone
]

## Main entry point
static func generate(position: Vector3, seed_value: int, parent: Node) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value

	# Pick random planter size and color
	var size = PLANTER_SIZES[rng.randi() % PLANTER_SIZES.size()]
	var color = PLANTER_COLORS[rng.randi() % PLANTER_COLORS.size()]

	var planter_node = Node3D.new()
	planter_node.name = "Planter"

	# Create planter box mesh
	var box_mesh = _create_planter_box(size, color)
	planter_node.add_child(box_mesh)

	# Create soil surface
	var soil_mesh = _create_soil(size)
	planter_node.add_child(soil_mesh)

	# Create plants
	var plants_mesh = _create_plants(size, rng)
	planter_node.add_child(plants_mesh)

	planter_node.position = position
	parent.add_child(planter_node)

## Create planter box geometry
static func _create_planter_box(size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "PlanterBox"

	var mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()

	var half_x = size.x / 2.0
	var half_z = size.z / 2.0
	var height = size.y

	# Outer walls (4 sides)
	# Front
	_add_quad(vertices, normals, uvs, indices,
		Vector3(-half_x, 0, half_z),
		Vector3(half_x, 0, half_z),
		Vector3(half_x, height, half_z),
		Vector3(-half_x, height, half_z),
		Vector3(0, 0, 1))

	# Back
	_add_quad(vertices, normals, uvs, indices,
		Vector3(half_x, 0, -half_z),
		Vector3(-half_x, 0, -half_z),
		Vector3(-half_x, height, -half_z),
		Vector3(half_x, height, -half_z),
		Vector3(0, 0, -1))

	# Left
	_add_quad(vertices, normals, uvs, indices,
		Vector3(-half_x, 0, -half_z),
		Vector3(-half_x, 0, half_z),
		Vector3(-half_x, height, half_z),
		Vector3(-half_x, height, -half_z),
		Vector3(-1, 0, 0))

	# Right
	_add_quad(vertices, normals, uvs, indices,
		Vector3(half_x, 0, half_z),
		Vector3(half_x, 0, -half_z),
		Vector3(half_x, height, -half_z),
		Vector3(half_x, height, half_z),
		Vector3(1, 0, 0))

	# Top rim (inner edge visible)
	var inner_half_x = half_x - PLANTER_WALL_THICKNESS
	var inner_half_z = half_z - PLANTER_WALL_THICKNESS

	# Top surface (rim)
	_add_quad(vertices, normals, uvs, indices,
		Vector3(-half_x, height, -half_z),
		Vector3(-half_x, height, half_z),
		Vector3(-inner_half_x, height, inner_half_z),
		Vector3(-inner_half_x, height, -inner_half_z),
		Vector3.UP)

	_add_quad(vertices, normals, uvs, indices,
		Vector3(half_x, height, half_z),
		Vector3(half_x, height, -half_z),
		Vector3(inner_half_x, height, -inner_half_z),
		Vector3(inner_half_x, height, inner_half_z),
		Vector3.UP)

	_add_quad(vertices, normals, uvs, indices,
		Vector3(-half_x, height, half_z),
		Vector3(half_x, height, half_z),
		Vector3(inner_half_x, height, inner_half_z),
		Vector3(-inner_half_x, height, inner_half_z),
		Vector3.UP)

	_add_quad(vertices, normals, uvs, indices,
		Vector3(half_x, height, -half_z),
		Vector3(-half_x, height, -half_z),
		Vector3(-inner_half_x, height, -inner_half_z),
		Vector3(inner_half_x, height, -inner_half_z),
		Vector3.UP)

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	mesh.surface_set_material(0, material)

	mesh_instance.mesh = mesh
	return mesh_instance

## Create soil surface
static func _create_soil(size: Vector3) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Soil"

	var inner_half_x = size.x / 2.0 - PLANTER_WALL_THICKNESS - SOIL_INSET
	var inner_half_z = size.z / 2.0 - PLANTER_WALL_THICKNESS - SOIL_INSET
	var soil_height = size.y - SOIL_INSET

	var mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()

	_add_quad(vertices, normals, uvs, indices,
		Vector3(-inner_half_x, soil_height, -inner_half_z),
		Vector3(-inner_half_x, soil_height, inner_half_z),
		Vector3(inner_half_x, soil_height, inner_half_z),
		Vector3(inner_half_x, soil_height, -inner_half_z),
		Vector3.UP)

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.25, 0.15)  # Dark soil
	material.roughness = 1.0
	mesh.surface_set_material(0, material)

	mesh_instance.mesh = mesh
	return mesh_instance

## Create plants in the planter
static func _create_plants(size: Vector3, rng: RandomNumberGenerator) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Plants"

	var mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()

	var inner_half_x = size.x / 2.0 - PLANTER_WALL_THICKNESS - 0.1
	var inner_half_z = size.z / 2.0 - PLANTER_WALL_THICKNESS - 0.1
	var base_height = size.y - SOIL_INSET

	# Add several plant quads
	var num_plants = rng.randi_range(3, 6)

	for i in range(num_plants):
		var plant_x = rng.randf_range(-inner_half_x, inner_half_x)
		var plant_z = rng.randf_range(-inner_half_z, inner_half_z)
		var plant_height = rng.randf_range(PLANT_HEIGHT_MIN, PLANT_HEIGHT_MAX)
		var plant_width = plant_height * 0.6

		var plant_pos = Vector3(plant_x, base_height, plant_z)

		# Cross-billboard (two perpendicular quads)
		_add_plant_billboard(vertices, normals, uvs, indices, plant_pos, plant_width, plant_height, 0)
		_add_plant_billboard(vertices, normals, uvs, indices, plant_pos, plant_width, plant_height, PI / 2)

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.5, 0.15)  # Green foliage
	material.roughness = 0.9
	mesh.surface_set_material(0, material)

	mesh_instance.mesh = mesh
	return mesh_instance

## Add a plant billboard quad
static func _add_plant_billboard(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	pos: Vector3,
	width: float,
	height: float,
	rotation: float
) -> void:
	var half_width = width / 2.0
	var offset_x = cos(rotation) * half_width
	var offset_z = sin(rotation) * half_width

	var normal = Vector3(sin(rotation), 0, cos(rotation))

	var base_idx = vertices.size()

	vertices.append(pos + Vector3(-offset_x, 0, -offset_z))
	vertices.append(pos + Vector3(offset_x, 0, offset_z))
	vertices.append(pos + Vector3(offset_x, height, offset_z))
	vertices.append(pos + Vector3(-offset_x, height, -offset_z))

	for j in range(4):
		normals.append(normal)

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

## Helper: Add a quad
static func _add_quad(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	v1: Vector3, v2: Vector3, v3: Vector3, v4: Vector3,
	normal: Vector3
) -> void:
	var base_idx = vertices.size()

	vertices.append(v1)
	vertices.append(v2)
	vertices.append(v3)
	vertices.append(v4)

	for i in range(4):
		normals.append(normal)

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
