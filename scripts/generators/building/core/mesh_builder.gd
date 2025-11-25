extends Node
class_name MeshBuilder

## Handles ArrayMesh construction and surface management
## Creates multi-surface meshes for buildings (walls, glass, frames, roof, floor)

## Surface data container
class MeshSurfaceData:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()  # For window emission
	var indices: PackedInt32Array = PackedInt32Array()

	func has_geometry() -> bool:
		return vertices.size() > 0

## Create all surface data structures
static func create_all_surfaces() -> Dictionary:
	return {
		"walls": MeshSurfaceData.new(),
		"glass": MeshSurfaceData.new(),
		"frames": MeshSurfaceData.new(),
		"roof": MeshSurfaceData.new(),
		"floor": MeshSurfaceData.new()
	}

## Build final ArrayMesh from surfaces
static func finalize_mesh(surfaces: Dictionary) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "BuildingMesh"

	var array_mesh = ArrayMesh.new()
	var current_surface_index = 0

	# Track surface indices for material assignment
	var surface_map = {}

	# Add each surface if it has geometry
	var surface_order = ["walls", "glass", "frames", "roof", "floor"]
	for surface_name in surface_order:
		var surface_data: MeshSurfaceData = surfaces[surface_name]

		if surface_data.has_geometry():
			var arrays = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = surface_data.vertices
			arrays[Mesh.ARRAY_NORMAL] = surface_data.normals
			arrays[Mesh.ARRAY_TEX_UV] = surface_data.uvs
			arrays[Mesh.ARRAY_INDEX] = surface_data.indices

			# Add vertex colors if present (for window emission)
			if surface_data.colors.size() > 0:
				arrays[Mesh.ARRAY_COLOR] = surface_data.colors

			array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			surface_map[surface_name] = current_surface_index
			current_surface_index += 1

	mesh_instance.mesh = array_mesh
	mesh_instance.set_meta("surface_map", surface_map)  # Store for material assignment

	return mesh_instance
