extends RefCounted
class_name WaterGenerator

## Water Generator
##
## Creates water meshes from OSM polygon data.
## Handles both large water bodies (lakes) and linear waterways (streams, rivers).

# ========================================================================
# CONSTANTS
# ========================================================================

const LABEL_FONT_SIZE = 96  # Water label font size

# ========================================================================
# WATER CREATION
# ========================================================================

## Create a water mesh from footprint data
static func create_water(footprint: Array, water_data: Dictionary, parent: Node3D) -> MeshInstance3D:
	# Handle linear waterways (streams, rivers, etc.) as paths, not polygons
	var water_type = water_data.get("water_type", "")
	var water_name = water_data.get("name", "unnamed")

	if water_type in ["stream", "river", "canal", "drain", "ditch"]:
		return _create_waterway_path(footprint, water_data, parent)

	# Validate polygon has enough points
	if footprint.size() < 3:
		return null

	# Calculate center for positioning
	var center = Vector2.ZERO
	for point in footprint:
		center += point
	center /= footprint.size()

	# Calculate area to determine if this is a large water body
	var area = _calculate_polygon_area(footprint)
	var is_large_water = area > 50000.0  # > 50k sq meters (e.g., Lake Union)

	# Create mesh from polygon using PROPER triangulation
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()

	# Convert footprint to local coordinates
	var local_polygon = []
	for point in footprint:
		local_polygon.append(point - center)

	# Use Godot's built-in triangulation (handles concave polygons correctly)
	var indices = PolygonTriangulator.triangulate(local_polygon)

	# Check if triangulation succeeded
	if indices.is_empty():
		print("❌ Failed to triangulate water body: ", water_name)
		print("   Points: ", local_polygon.size(), " | Area: ", _calculate_polygon_area(footprint))
		push_warning("Failed to triangulate water body: " + water_name + " (invalid polygon)")
		return null

	# DEBUG: Show triangulation success for Model Boat Pond
	if water_name == "Model Boat Pond":
		print("✅ Model Boat Pond triangulated!")
		print("   Vertices: ", local_polygon.size())
		print("   Indices: ", indices.size(), " (", int(indices.size() / 3.0), " triangles)")

	# REVERSE indices for correct winding order (normals facing UP)
	var reversed_indices = PackedInt32Array()
	for i in range(0, indices.size(), 3):
		reversed_indices.append(indices[i + 2])
		reversed_indices.append(indices[i + 1])
		reversed_indices.append(indices[i])
	indices = reversed_indices

	# Create vertices
	for point in local_polygon:
		vertices.append(Vector3(point.x, 0, -point.y))
		normals.append(Vector3.UP)
		uvs.append(Vector2(point.x / 100.0, point.y / 100.0))

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

	# Different settings for large vs small water bodies
	if is_large_water:
		# Large lakes: ground level, semi-transparent blue with reflections
		mesh_instance.position = Vector3(center.x, 0.0, -center.y)

		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.1, 0.25, 0.55, 0.85)  # Semi-transparent blue
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.roughness = 0.1  # Smooth for reflections
		material.metallic = 0.6  # Reflective surface
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		mesh_instance.material_override = material
	else:
		# Small water features: elevated, semi-transparent blue with reflections
		mesh_instance.position = Vector3(center.x, 0.1, -center.y)

		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.15, 0.3, 0.65, 0.85)  # Semi-transparent blue
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.roughness = 0.15  # Slightly rough
		material.metallic = 0.5  # Reflective surface
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		mesh_instance.material_override = material

	parent.add_child(mesh_instance)

	# DEBUG: Confirm mesh added for Model Boat Pond
	if water_name == "Model Boat Pond":
		print("✅ Model Boat Pond mesh added to scene at ", mesh_instance.position)

	# Add label
	water_type = water_data.get("water_type", "water")
	var label_text = water_name if water_name != "" else water_type.capitalize()
	_add_entity_label(parent, Vector3(center.x, 3, -center.y), "WATER: " + label_text, Color(0.3, 0.6, 1.0))

	return mesh_instance

# ========================================================================
# WATERWAY CREATION
# ========================================================================

## Create linear waterway (stream/river) as an extruded path
static func _create_waterway_path(path: Array, water_data: Dictionary, parent: Node3D) -> MeshInstance3D:
	if path.size() < 2:
		return null

	var waterway_type = water_data.get("water_type", "stream")
	var center = water_data.get("center", Vector2.ZERO)

	# Determine width based on waterway type
	var width = 3.0  # Default stream width
	match waterway_type:
		"river": width = 8.0
		"canal": width = 6.0
		"stream": width = 3.0
		"drain": width = 2.0
		"ditch": width = 1.5

	# Create mesh similar to roads
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()

	var half_width = width / 2.0
	var y = 0.05  # Slightly above ground

	# Generate geometry along path
	for i in range(path.size()):
		var p = path[i] - center
		var pos_3d = Vector3(p.x, y, -p.y)

		# Calculate direction
		var direction: Vector2
		if i == 0:
			direction = (path[i + 1] - path[i]).normalized()
		elif i == path.size() - 1:
			direction = (path[i] - path[i - 1]).normalized()
		else:
			var dir_prev = (path[i] - path[i - 1]).normalized()
			var dir_next = (path[i + 1] - path[i]).normalized()
			direction = (dir_prev + dir_next).normalized()

		var perpendicular = Vector2(-direction.y, direction.x)
		var left = pos_3d + Vector3(perpendicular.x * half_width, 0, -perpendicular.y * half_width)
		var right = pos_3d + Vector3(-perpendicular.x * half_width, 0, perpendicular.y * half_width)

		vertices.append(left)
		vertices.append(right)
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		uvs.append(Vector2(0, float(i)))
		uvs.append(Vector2(1, float(i)))

	# Create triangles
	for i in range(path.size() - 1):
		var base = i * 2
		indices.append(base)
		indices.append(base + 2)
		indices.append(base + 3)
		indices.append(base)
		indices.append(base + 3)
		indices.append(base + 1)

	# Create mesh
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
	mesh_instance.position = Vector3(center.x, 0, -center.y)

	# Lighter blue for flowing water with reflections
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.45, 0.75, 0.85)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.2  # Slightly rougher for flowing water
	material.metallic = 0.4  # More reflective
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mesh_instance.material_override = material

	parent.add_child(mesh_instance)

	return mesh_instance

# ========================================================================
# UTILITY
# ========================================================================

## Calculate polygon area
static func _calculate_polygon_area(polygon: Array) -> float:
	var area = 0.0
	for i in range(polygon.size()):
		var j = (i + 1) % polygon.size()
		area += polygon[i].x * polygon[j].y
		area -= polygon[j].x * polygon[i].y
	return abs(area) / 2.0

## Add a floating label to an entity
static func _add_entity_label(parent: Node, label_position: Vector3, text: String, color: Color):
	var label = Label3D.new()
	label.text = text
	label.position = label_position
	label.font_size = LABEL_FONT_SIZE
	label.outline_size = 15  # Thick black outline
	label.modulate = color
	label.outline_modulate = Color(0, 0, 0)  # Black outline
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true  # Always visible through objects
	parent.add_child(label)
