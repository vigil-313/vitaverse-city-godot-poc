extends Node
class_name FrameMaterialBuilder

## Creates window frame material with PBR properties

## Create window frame material
static func create(material_lib = null) -> StandardMaterial3D:
	# Use MaterialLibrary if available
	if material_lib:
		return material_lib.get_material("metal_aluminum")

	# Fallback: create material manually
	var material = StandardMaterial3D.new()

	# Dark frames for contrast against glass and walls
	material.albedo_color = Color.html("#424242")  # Dark gray

	# PBR properties for frame material
	material.roughness = 0.7  # Moderate roughness
	material.metallic = 0.1   # Slight metallic

	return material
