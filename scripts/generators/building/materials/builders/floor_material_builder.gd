extends Node
class_name FloorMaterialBuilder

## Creates floor slab material (concrete)

## Create concrete floor material
static func create(material_lib = null) -> StandardMaterial3D:
	# Use MaterialLibrary if available
	if material_lib:
		return material_lib.get_material("concrete_gray")

	# Fallback: create material manually
	var material = StandardMaterial3D.new()

	# Concrete grey color
	material.albedo_color = Color.html("#A0A0A0")  # Medium grey concrete

	# PBR properties for concrete
	material.roughness = 0.7  # Somewhat rough
	material.metallic = 0.0   # Non-metallic

	return material
