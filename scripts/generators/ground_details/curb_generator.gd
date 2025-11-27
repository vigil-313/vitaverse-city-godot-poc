extends Node
class_name CurbGenerator

## Curb Generator
## Creates raised curbs along road edges

## Curb dimensions
const CURB_HEIGHT = 0.15      # 15cm tall curb
const CURB_WIDTH = 0.2        # 20cm wide curb top
const CURB_OFFSET = 0.1       # Offset from road edge

## Main entry point - generate curbs along a road
static func generate_for_road(road_data: Dictionary, parent: Node) -> void:
	var path = road_data.get("path", [])
	if path.size() < 2:
		return

	var road_type = road_data.get("road_type", "residential")
	var width = _get_road_width(road_type)

	# Skip very small roads (footways, paths)
	if width < 3.0:
		return

	var curb_node = MeshInstance3D.new()
	curb_node.name = "Curb"

	var mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()

	# Generate curb segments along both sides of road
	for i in range(path.size() - 1):
		var p1 = path[i]
		var p2 = path[i + 1]

		_add_curb_segment(p1, p2, width / 2.0 + CURB_OFFSET, vertices, normals, uvs, indices)
		_add_curb_segment(p1, p2, -(width / 2.0 + CURB_OFFSET), vertices, normals, uvs, indices)

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
	material.albedo_color = Color(0.65, 0.63, 0.6)  # Gray concrete
	material.roughness = 0.85
	mesh.surface_set_material(0, material)

	curb_node.mesh = mesh
	parent.add_child(curb_node)

## Add a curb segment along one side of road
static func _add_curb_segment(
	p1: Vector2,
	p2: Vector2,
	side_offset: float,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array
) -> void:
	var road_dir = (p2 - p1).normalized()
	var road_normal = Vector2(-road_dir.y, road_dir.x)
	var segment_length = p1.distance_to(p2)

	# Offset to side of road
	var offset = road_normal * side_offset

	# Inner edge (road side)
	var inner_p1 = p1 + offset
	var inner_p2 = p2 + offset

	# Outer edge (away from road)
	var outer_offset = road_normal * (side_offset + CURB_WIDTH * sign(side_offset))
	var outer_p1 = p1 + outer_offset
	var outer_p2 = p2 + outer_offset

	# Convert to 3D
	var v_inner_1_bottom = Vector3(inner_p1.x, 0, -inner_p1.y)
	var v_inner_2_bottom = Vector3(inner_p2.x, 0, -inner_p2.y)
	var v_inner_1_top = Vector3(inner_p1.x, CURB_HEIGHT, -inner_p1.y)
	var v_inner_2_top = Vector3(inner_p2.x, CURB_HEIGHT, -inner_p2.y)
	var v_outer_1_top = Vector3(outer_p1.x, CURB_HEIGHT, -outer_p1.y)
	var v_outer_2_top = Vector3(outer_p2.x, CURB_HEIGHT, -outer_p2.y)

	# Inner face (facing road)
	var base_idx = vertices.size()
	var inner_normal = Vector3(-road_normal.x * sign(side_offset), 0, road_normal.y * sign(side_offset))

	vertices.append(v_inner_1_bottom)
	vertices.append(v_inner_2_bottom)
	vertices.append(v_inner_2_top)
	vertices.append(v_inner_1_top)

	for j in range(4):
		normals.append(inner_normal)

	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(segment_length, 0))
	uvs.append(Vector2(segment_length, CURB_HEIGHT))
	uvs.append(Vector2(0, CURB_HEIGHT))

	indices.append(base_idx + 0)
	indices.append(base_idx + 1)
	indices.append(base_idx + 2)
	indices.append(base_idx + 0)
	indices.append(base_idx + 2)
	indices.append(base_idx + 3)

	# Top surface
	base_idx = vertices.size()

	vertices.append(v_inner_1_top)
	vertices.append(v_inner_2_top)
	vertices.append(v_outer_2_top)
	vertices.append(v_outer_1_top)

	for j in range(4):
		normals.append(Vector3.UP)

	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(segment_length, 0))
	uvs.append(Vector2(segment_length, CURB_WIDTH))
	uvs.append(Vector2(0, CURB_WIDTH))

	indices.append(base_idx + 0)
	indices.append(base_idx + 1)
	indices.append(base_idx + 2)
	indices.append(base_idx + 0)
	indices.append(base_idx + 2)
	indices.append(base_idx + 3)

## Get road width based on type
static func _get_road_width(road_type: String) -> float:
	match road_type:
		"motorway", "trunk":
			return 14.0
		"primary":
			return 12.0
		"secondary":
			return 10.0
		"tertiary":
			return 8.0
		"residential", "unclassified":
			return 6.0
		"service":
			return 4.0
		_:
			return 6.0
