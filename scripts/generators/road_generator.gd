extends RefCounted
class_name RoadGenerator

## Road Generator
##
## Creates road meshes from OSM path data.
## Supports continuous mesh extrusion, bridges, and material variations.

# ========================================================================
# CONSTANTS
# ========================================================================

const LABEL_FONT_SIZE_OTHER = 96  # Road label font size

# ========================================================================
# ROAD CREATION
# ========================================================================

## Create a road from path data
static func create_road(path: Array, road_data: Dictionary, parent: Node3D, roads_tracking: Array) -> Node3D:
	var highway_type = road_data.get("highway_type", "")

	# Skip service roads and cycleways
	if highway_type in ["cycleway", "service"]:
		return null

	var width = get_road_width(highway_type)
	var road_node = _create_simple_road(path, width, road_data)

	if road_node:
		parent.add_child(road_node)
		roads_tracking.append({
			"node": road_node,
			"path": path,
			"position": road_node.position
		})

	return road_node

## Get road width based on highway type
static func get_road_width(highway_type: String) -> float:
	match highway_type:
		"motorway", "trunk":
			return 20.0  # Wide highways
		"primary":
			return 16.0  # Major arterials
		"secondary", "tertiary":
			return 12.0  # Medium roads
		"residential", "unclassified":
			return 10.0  # Neighborhood streets
		"service":
			return 6.0   # Service roads (if we render them)
		"footway", "path", "pedestrian", "track":
			return 2.5   # Narrow footpaths
		"steps":
			return 2.0   # Stairs
		_:
			return 10.0  # Default

## Get road elevation based on type (for proper layering)
static func get_road_elevation(highway_type: String) -> float:
	match highway_type:
		"motorway", "trunk", "primary", "secondary", "tertiary", "residential", "unclassified":
			return 0.20  # Major roads highest
		"footway", "path", "pedestrian", "track", "steps":
			return 0.10  # Footpaths well above parks to prevent z-fighting
		_:
			return 0.20  # Default

# ========================================================================
# INTERNAL METHODS
# ========================================================================

## Create simple road without LOD - using continuous mesh
static func _create_simple_road(path: Array, width: float, road_data: Dictionary = {}) -> Node3D:
	# Calculate road center for positioning
	var road_center = Vector2.ZERO
	for point in path:
		road_center += point
	road_center /= path.size()

	# Create wrapper node for this road
	var road_node = Node3D.new()
	road_node.name = "Road_" + str(road_data.get("id", 0))
	road_node.position = Vector3(road_center.x, 0, -road_center.y)

	# Check if this is a bridge
	var is_bridge = road_data.get("bridge", false)
	var bridge_height = 8.0 if is_bridge else 0.0

	# Get elevation based on road type for proper layering
	var highway_type = road_data.get("highway_type", "")
	var base_elevation = get_road_elevation(highway_type)

	# Create continuous road mesh
	var mesh_instance = _create_road_mesh(path, road_center, width, bridge_height, base_elevation, road_data)
	if mesh_instance:
		road_node.add_child(mesh_instance)

	# Add bridge pillars if this is a bridge
	if is_bridge:
		_create_bridge_pillars_along_path(road_node, path, road_center, width, bridge_height)

	# Add road name label for named roads (excluding only footpaths/paths)
	var road_name = road_data.get("name", "")
	var show_label = highway_type in ["motorway", "trunk", "primary", "secondary", "tertiary", "residential", "unclassified"]

	if road_name != "" and show_label:
		var label = Label3D.new()
		label.name = "RoadLabel"
		label.text = road_name
		label.position = Vector3(0, 0.5, 0)  # 0.5m above ground
		label.font_size = LABEL_FONT_SIZE_OTHER
		label.outline_size = 12
		label.modulate = Color(0, 0.8, 1)  # Cyan for roads
		label.outline_modulate = Color(0, 0, 0)  # Black outline
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true  # Visible through objects
		road_node.add_child(label)

	return road_node

## Create continuous road mesh along path
static func _create_road_mesh(path: Array, road_center: Vector2, width: float, bridge_height: float, base_elevation: float, road_data: Dictionary) -> MeshInstance3D:
	if path.size() < 2:
		return null

	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()

	var half_width = width / 2.0
	var y = bridge_height + base_elevation  # Bridge height + road type elevation

	# Generate road geometry: extrude a rectangle along the path
	for i in range(path.size()):
		var p = path[i] - road_center
		var pos_3d = Vector3(p.x, y, -p.y)

		# Calculate direction for perpendicular offset
		var direction: Vector2
		if i == 0:
			direction = (path[i + 1] - path[i]).normalized()
		elif i == path.size() - 1:
			direction = (path[i] - path[i - 1]).normalized()
		else:
			var dir_prev = (path[i] - path[i - 1]).normalized()
			var dir_next = (path[i + 1] - path[i]).normalized()
			direction = (dir_prev + dir_next).normalized()

		# Perpendicular vector (rotate 90 degrees)
		var perpendicular = Vector2(-direction.y, direction.x)

		# Create two vertices for left and right edges
		var left = pos_3d + Vector3(perpendicular.x * half_width, 0, -perpendicular.y * half_width)
		var right = pos_3d + Vector3(-perpendicular.x * half_width, 0, perpendicular.y * half_width)

		vertices.append(left)
		vertices.append(right)
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)

		var u = float(i) / float(path.size() - 1)
		uvs.append(Vector2(0, u))
		uvs.append(Vector2(1, u))

	# Create triangles connecting consecutive cross-sections
	for i in range(path.size() - 1):
		var base = i * 2
		indices.append(base)
		indices.append(base + 2)
		indices.append(base + 3)
		indices.append(base)
		indices.append(base + 3)
		indices.append(base + 1)

	# Create ArrayMesh
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var array_mesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = array_mesh
	mesh_instance.material_override = _get_road_material(road_data)

	return mesh_instance

## Create bridge pillars along entire path
static func _create_bridge_pillars_along_path(parent: Node3D, path: Array, road_center: Vector2, _road_width: float, bridge_height: float):
	var pillar_spacing = 20.0  # Place pillars every 20 meters
	var accumulated_distance = 0.0

	for i in range(path.size() - 1):
		var p1 = path[i] - road_center
		var p2 = path[i + 1] - road_center
		var segment_length = p1.distance_to(p2)

		# Place pillars along this segment
		var remaining = segment_length
		while remaining > 0:
			var distance_from_start = segment_length - remaining

			if accumulated_distance + distance_from_start >= pillar_spacing:
				# Place a pillar here
				var t = distance_from_start / segment_length
				var pillar_pos_2d = p1.lerp(p2, t)

				var pillar = CSGBox3D.new()
				pillar.size = Vector3(2.0, bridge_height, 2.0)  # 2m x 2m column
				pillar.position = Vector3(pillar_pos_2d.x, bridge_height / 2.0, -pillar_pos_2d.y)

				# Concrete material
				var material = StandardMaterial3D.new()
				material.albedo_color = Color(0.5, 0.5, 0.5)
				material.roughness = 0.8
				pillar.material = material

				parent.add_child(pillar)

				# Reset distance counter
				accumulated_distance = 0.0
				remaining -= pillar_spacing
			else:
				remaining = 0

		accumulated_distance += segment_length

## Get road material based on OSM surface type
static func _get_road_material(road_data: Dictionary) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	var surface_type = road_data.get("surface", "").to_lower()

	match surface_type:
		"asphalt", "":
			material.albedo_color = Color(0.28, 0.28, 0.3)
			material.roughness = 0.75
			material.metallic = 0.05
		"concrete":
			material.albedo_color = Color(0.4, 0.4, 0.42)
			material.roughness = 0.7
			material.metallic = 0.02
		"gravel":
			material.albedo_color = Color(0.45, 0.4, 0.35)
			material.roughness = 1.0
		"dirt", "earth", "ground":
			material.albedo_color = Color(0.4, 0.3, 0.2)
			material.roughness = 0.95
		"paving_stones", "paved", "cobblestone":
			material.albedo_color = Color(0.5, 0.45, 0.45)
			material.roughness = 0.75
		"grass":
			material.albedo_color = Color(0.3, 0.5, 0.2)
			material.roughness = 1.0
		_:
			material.albedo_color = Color(0.2, 0.2, 0.22)
			material.roughness = 0.8

	return material
