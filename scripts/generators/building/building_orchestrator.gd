extends Node
class_name BuildingOrchestrator

## Main building generation orchestrator
## Coordinates all subsystems (walls, windows, roofs, materials, details)
## Maintains same API as BuildingGeneratorMesh for compatibility

# Core systems
const BuildingContext = preload("res://scripts/generators/building/core/building_context.gd")
const MeshBuilder = preload("res://scripts/generators/building/core/mesh_builder.gd")
const OSMParser = preload("res://scripts/generators/building/core/osm_parser.gd")

# Wall systems
const WallGenerator = preload("res://scripts/generators/building/walls/wall_generator.gd")

# Roof systems
const RoofGenerator = preload("res://scripts/generators/building/roofs/roof_generator.gd")

# Architectural details
const FoundationGenerator = preload("res://scripts/generators/building/walls/details/foundation_generator.gd")
const CorniceGenerator = preload("res://scripts/generators/building/walls/details/cornice_generator.gd")
const FloorSlabGenerator = preload("res://scripts/generators/building/walls/details/floor_slab_generator.gd")
const FloorLedgeGenerator = preload("res://scripts/generators/building/walls/details/floor_ledge_generator.gd")

# Material systems
const MaterialCoordinator = preload("res://scripts/generators/building/materials/material_coordinator.gd")

# Utilities
const LabelGenerator = preload("res://scripts/generators/building/utilities/label_generator.gd")

## Main entry point - maintains exact same signature as original
static func create_building(osm_data: Dictionary, parent: Node, detailed: bool = true, material_lib = null) -> Node3D:
	# Create building container node
	var building = Node3D.new()
	var building_name = osm_data.get("name", "")
	if building_name == "":
		building_name = "Building_" + str(osm_data.get("id", randi()))
	building.name = building_name

	# Extract data
	var footprint = osm_data.get("footprint", [])
	var center = osm_data.get("center", Vector2.ZERO)
	var height = osm_data.get("height", 6.0)
	var levels = osm_data.get("levels", 2)

	# Calculate elevation
	var layer = osm_data.get("layer", 0)
	var min_level = osm_data.get("min_level", 0)
	var base_elevation = (layer * 5.0) + (min_level * 3.0)

	# Create building mesh
	var building_mesh = _create_building_mesh(footprint, center, height, levels, osm_data, detailed, material_lib)
	building_mesh.position.y = base_elevation
	building.add_child(building_mesh)

	# Add building label
	var label_text = OSMParser.get_building_label(osm_data)
	var full_label = OSMParser.get_full_building_label(osm_data, levels, height)
	LabelGenerator.add_label(building, full_label, height, base_elevation)

	parent.add_child(building)
	return building

## Create complete building mesh (walls + roof + windows + details)
static func _create_building_mesh(footprint: Array, center: Vector2, height: float, levels: int, osm_data: Dictionary, detailed: bool, material_lib = null) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "BuildingMesh"

	# Create all mesh surfaces
	var surfaces = {
		"wall": MeshBuilder.MeshSurfaceData.new(),
		"glass": MeshBuilder.MeshSurfaceData.new(),
		"frame": MeshBuilder.MeshSurfaceData.new(),
		"roof": MeshBuilder.MeshSurfaceData.new(),
		"floor": MeshBuilder.MeshSurfaceData.new()
	}

	# Initialize building context
	var context = BuildingContext.new()
	context.initialize(osm_data, detailed, material_lib)

	# Generate walls with windows
	WallGenerator.generate_walls(context, surfaces)

	# Generate architectural details (if detailed mode)
	if detailed:
		FoundationGenerator.generate(footprint, center, surfaces["wall"])
		if levels > 1:  # Only for multi-story buildings
			CorniceGenerator.generate(footprint, center, height, surfaces["wall"])
			FloorLedgeGenerator.generate(footprint, center, height / float(levels), levels, surfaces["wall"])
			FloorSlabGenerator.generate(footprint, center, height / float(levels), levels, surfaces["wall"])

	# Generate roof
	RoofGenerator.generate_roof(context, surfaces)

	# Build ArrayMesh from surfaces
	var array_mesh = ArrayMesh.new()
	var surface_indices = {}
	var current_surface_index = 0

	# Add each surface to the mesh (only if it has vertices)
	for surface_name in ["wall", "glass", "frame", "roof", "floor"]:
		var surface_data = surfaces[surface_name]
		if surface_data.vertices.size() > 0:
			var arrays = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = surface_data.vertices
			arrays[Mesh.ARRAY_NORMAL] = surface_data.normals
			arrays[Mesh.ARRAY_TEX_UV] = surface_data.uvs
			arrays[Mesh.ARRAY_INDEX] = surface_data.indices

			# Add vertex colors for glass emission control
			if surface_name == "glass" and surface_data.colors.size() > 0:
				arrays[Mesh.ARRAY_COLOR] = surface_data.colors

			array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			surface_indices[surface_name] = current_surface_index
			current_surface_index += 1

	mesh_instance.mesh = array_mesh

	# Apply materials to all surfaces
	MaterialCoordinator.apply_materials(mesh_instance, surface_indices, osm_data, material_lib)

	return mesh_instance
