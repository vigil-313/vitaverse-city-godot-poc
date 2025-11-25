extends Node
class_name RoofMaterialBuilder

## Creates roof material with PBR properties based on OSM data

const ColorParser = preload("res://scripts/generators/building/materials/parsers/color_parser.gd")

## Create roof material from OSM data
static func create(osm_data: Dictionary, material_lib = null) -> StandardMaterial3D:
	# Use MaterialLibrary if available
	if material_lib:
		var roof_material_name = material_lib.get_roof_material(osm_data)
		return material_lib.get_material(roof_material_name)

	# Fallback: create material manually
	var material = StandardMaterial3D.new()

	# Try to get roof color from OSM data
	var roof_color_str = osm_data.get("roof:colour", "")
	var roof_material_str = osm_data.get("roof:material", "")
	var building_id = int(osm_data.get("id", 0))
	var roof_color = Color.TRANSPARENT

	# Priority 1: Explicit OSM roof color
	if roof_color_str != "":
		roof_color = ColorParser.parse_osm_color(roof_color_str)

	# Priority 2: Roof material type
	if roof_color == Color.TRANSPARENT and roof_material_str != "":
		roof_color = _get_material_color(roof_material_str)

	# Priority 3: Realistic roof colors (based on real-world observation)
	if roof_color == Color.TRANSPARENT:
		roof_color = _get_realistic_roof_color(building_id)

	material.albedo_color = roof_color

	# PBR properties for realistic lighting
	material.roughness = 0.9  # Very rough for roofing materials
	material.metallic = 0.0   # Non-metallic

	return material

## Get color based on roof material type
static func _get_material_color(material_str: String) -> Color:
	match material_str.to_lower():
		"tile", "tiles", "clay":
			return Color.html("#A0522D")  # Terracotta red-brown
		"slate":
			return Color.html("#708090")  # Slate gray
		"metal", "steel":
			return Color.html("#B0B0B0")  # Light gray metal
		"concrete":
			return Color.html("#9E9E9E")  # Concrete gray
		"wood", "shingles":
			return Color.html("#654321")  # Dark brown
		"tar", "asphalt":
			return Color.html("#2F2F2F")  # Very dark gray
		"gravel":
			return Color.html("#A9A9A9")  # Gray
		_:
			return Color.TRANSPARENT

## Get realistic roof color variety
## Based on real-world observation: most modern roofs are white/grey/dark grey
static func _get_realistic_roof_color(building_id: int) -> Color:
	var realistic_roof_colors = [
		Color.html("#FFFFFF"),  # White (TPO/reflective)
		Color.html("#F5F5F5"),  # Off-white
		Color.html("#E8E8E8"),  # Very light grey
		Color.html("#D3D3D3"),  # Light grey
		Color.html("#C0C0C0"),  # Medium light grey
		Color.html("#A9A9A9"),  # Medium grey
		Color.html("#808080"),  # Grey
		Color.html("#696969"),  # Dark grey
		Color.html("#505050"),  # Darker grey
		Color.html("#3C3C3C"),  # Very dark grey (tar)
	]
	return realistic_roof_colors[building_id % realistic_roof_colors.size()]
