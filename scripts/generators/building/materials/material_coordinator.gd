extends Node
class_name MaterialCoordinator

## Coordinates material creation and application to mesh surfaces

const WallMaterialBuilder = preload("res://scripts/generators/building/materials/builders/wall_material_builder.gd")
const GlassMaterialBuilder = preload("res://scripts/generators/building/materials/builders/glass_material_builder.gd")
const FrameMaterialBuilder = preload("res://scripts/generators/building/materials/builders/frame_material_builder.gd")
const RoofMaterialBuilder = preload("res://scripts/generators/building/materials/builders/roof_material_builder.gd")
const FloorMaterialBuilder = preload("res://scripts/generators/building/materials/builders/floor_material_builder.gd")

## Apply all materials to mesh instance surfaces
static func apply_materials(
	mesh_instance: MeshInstance3D,
	surface_indices: Dictionary,
	osm_data: Dictionary,
	material_lib = null
) -> void:
	# Apply wall material
	if surface_indices.get("wall", -1) >= 0:
		var wall_material = WallMaterialBuilder.create(osm_data, material_lib)
		mesh_instance.set_surface_override_material(surface_indices["wall"], wall_material)

	# Apply glass material
	if surface_indices.get("glass", -1) >= 0:
		var glass_material = GlassMaterialBuilder.create(osm_data, material_lib)
		mesh_instance.set_surface_override_material(surface_indices["glass"], glass_material)

	# Apply frame material
	if surface_indices.get("frame", -1) >= 0:
		var frame_material = FrameMaterialBuilder.create(material_lib)
		mesh_instance.set_surface_override_material(surface_indices["frame"], frame_material)

	# Apply roof material
	if surface_indices.get("roof", -1) >= 0:
		var roof_material = RoofMaterialBuilder.create(osm_data, material_lib)
		mesh_instance.set_surface_override_material(surface_indices["roof"], roof_material)

	# Apply floor material
	if surface_indices.get("floor", -1) >= 0:
		var floor_material = FloorMaterialBuilder.create(material_lib)
		mesh_instance.set_surface_override_material(surface_indices["floor"], floor_material)
