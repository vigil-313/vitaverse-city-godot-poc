extends RefCounted
class_name ParkGenerator

## Park Generator
##
## Creates park meshes from OSM polygon data.
## Uses triangulation to handle complex concave shapes.

# ========================================================================
# CONSTANTS
# ========================================================================

const LABEL_FONT_SIZE = 96  # Park label font size

# ========================================================================
# PARK CREATION
# ========================================================================

## Create a park mesh from footprint data
static func create_park(footprint: Array, park_data: Dictionary, parent: Node3D) -> MeshInstance3D:
	var park_name = park_data.get("name", "unnamed")

	# Validate polygon has enough points
	if footprint.size() < 3:
		return null

	# Calculate center for positioning
	var center = Vector2.ZERO
	for point in footprint:
		center += point
	center /= footprint.size()

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
		push_warning("Failed to triangulate park: " + park_name + " (invalid polygon)")
		return null

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
	mesh_instance.position = Vector3(center.x, 0.0, -center.y)  # Ground level

	# DARK SATURATED green opaque material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.1, 0.5, 0.1)  # DARK GREEN - very visible
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	material.roughness = 0.9
	material.metallic = 0.0
	mesh_instance.material_override = material

	parent.add_child(mesh_instance)

	# Add label
	park_name = park_data.get("name", "")
	var park_type = park_data.get("leisure_type", "park")
	var label_text = park_name if park_name != "" else park_type.capitalize()
	_add_entity_label(parent, Vector3(center.x, 3, -center.y), "PARK: " + label_text, Color(0, 1, 0))

	return mesh_instance

# ========================================================================
# UTILITY
# ========================================================================

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
