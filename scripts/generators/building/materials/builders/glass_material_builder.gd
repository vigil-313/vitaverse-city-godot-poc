extends Node
class_name GlassMaterialBuilder

## Creates window glass material with shader, transparency, and emission

## Create glass material with per-vertex emission control
static func create(osm_data: Dictionary, material_lib = null) -> ShaderMaterial:
	# Create shader material with per-vertex emission control
	var shader = load("res://shaders/window_glass.gdshader")
	var material = ShaderMaterial.new()
	material.shader = shader

	# Set base glass appearance (light blue, transparent)
	material.set_shader_parameter("albedo_color", Color(0.64, 0.71, 0.96, 0.8))
	material.set_shader_parameter("roughness", 0.1)
	material.set_shader_parameter("metallic", 0.2)

	# Set emission parameters (per-window control via vertex colors)
	var building_type = osm_data.get("building_type", "residential")
	var base_emission = _get_type_based_emission(building_type)

	material.set_shader_parameter("base_emission_color", base_emission)
	material.set_shader_parameter("emission_energy", 0.6)

	# Enable transparency and render after opaque geometry
	material.render_priority = 1

	return material

## Get emission color based on building type
static func _get_type_based_emission(building_type: String) -> Color:
	match building_type:
		"residential", "house", "apartments":
			return Color(1.0, 0.85, 0.6)  # Warm orange
		"commercial", "office", "retail":
			return Color(0.85, 0.95, 1.0)  # Cool blue-white
		"industrial", "warehouse":
			return Color(1.0, 1.0, 0.95)  # Bright neutral
		_:
			return Color(1.0, 0.9, 0.75)  # Warm neutral
