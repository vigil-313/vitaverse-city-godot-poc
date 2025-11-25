extends Node
class_name WallMaterialBuilder

## Creates wall material with PBR properties and realistic colors

const ColorParser = preload("res://scripts/generators/building/materials/parsers/color_parser.gd")

## Create wall material from OSM data
static func create(osm_data: Dictionary, material_lib = null) -> StandardMaterial3D:
	# Use MaterialLibrary if available
	if material_lib:
		var material_name = material_lib.get_material_by_osm_tags(osm_data, "wall")
		return material_lib.get_material(material_name, true)  # Apply variation

	# Fallback: create material manually
	var material = StandardMaterial3D.new()

	# Try to get building color from OSM data
	var building_color_str = osm_data.get("building:colour", "")
	var building_material_str = osm_data.get("building:material", "")
	var building_type = osm_data.get("building_type", "")
	var building_id = int(osm_data.get("id", 0))
	var wall_color = Color.TRANSPARENT

	# Priority 1: Explicit OSM building color
	if building_color_str != "":
		wall_color = ColorParser.parse_osm_color(building_color_str)

	# Priority 2: Building material type
	if wall_color == Color.TRANSPARENT and building_material_str != "":
		wall_color = _get_material_color(building_material_str)

	# Priority 3: Realistic variety based on building type
	if wall_color == Color.TRANSPARENT:
		wall_color = _get_type_based_color(building_type, building_id)

	material.albedo_color = wall_color

	# PBR properties for realistic lighting
	material.roughness = 0.8  # Slightly rough surface for buildings
	material.metallic = 0.0   # Non-metallic

	return material

## Get color based on building material type
static func _get_material_color(material_str: String) -> Color:
	match material_str.to_lower():
		"brick":
			return Color.html("#B85C4D")  # Red brick
		"concrete":
			return Color.html("#C0C0C0")  # Gray concrete
		"wood":
			return Color.html("#D2B48C")  # Light wood/tan
		"stone":
			return Color.html("#A8A8A8")  # Gray stone
		"plaster", "stucco":
			return Color.html("#F5E6D3")  # Off-white/cream
		"glass":
			return Color.html("#E0F2F7")  # Light blue-tinted
		_:
			return Color.TRANSPARENT

## Get color based on building type
static func _get_type_based_color(building_type: String, building_id: int) -> Color:
	match building_type:
		"house", "residential":
			# Residential: warm, varied colors
			var colors = [
				Color.html("#F5DEB3"),  # Wheat/tan
				Color.html("#E8D4C0"),  # Beige
				Color.html("#D2B48C"),  # Light tan
				Color.html("#C9B8A0"),  # Warm gray
				Color.html("#B85C4D"),  # Red brick
				Color.html("#8B7355"),  # Brown
				Color.html("#FFFACD"),  # Light yellow
				Color.html("#E6E6E6"),  # Light gray
			]
			return colors[building_id % colors.size()]
		"commercial", "office", "retail":
			# Commercial: grays, whites, modern
			var colors = [
				Color.html("#E0E0E0"),  # Light gray
				Color.html("#F5F5F5"),  # Off-white
				Color.html("#C0C0C0"),  # Gray
				Color.html("#B0B0B0"),  # Medium gray
				Color.html("#D3D3D3"),  # Light steel
			]
			return colors[building_id % colors.size()]
		"industrial", "warehouse":
			# Industrial: utilitarian colors
			var colors = [
				Color.html("#A0A0A0"),  # Gray
				Color.html("#8B7355"),  # Brown
				Color.html("#B0B0B0"),  # Light gray metal
				Color.html("#696969"),  # Dim gray
			]
			return colors[building_id % colors.size()]
		_:
			# Default: neutral palette
			var colors = [
				Color.html("#F5F5DC"),  # Beige
				Color.html("#E8E8E8"),  # Light gray
				Color.html("#D2B48C"),  # Tan
				Color.html("#C0C0C0"),  # Gray
			]
			return colors[building_id % colors.size()]
