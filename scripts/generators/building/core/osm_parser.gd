extends Node
class_name OSMParser

## OSM data normalization and parsing for buildings

## Extract and normalize building name for labels
static func get_building_label(osm_data: Dictionary) -> String:
	var name = osm_data.get("name", "")
	if name != "":
		return name

	var building_type = osm_data.get("building_type", "building")
	return building_type.capitalize().replace("_", " ")

## Get full label with metadata
static func get_full_building_label(osm_data: Dictionary, levels: int, height: float) -> String:
	var label = get_building_label(osm_data)
	return "BUILDING: " + label + "\n" + str(levels) + " floors, " + str(int(height)) + "m"

## Normalize building type for classification
static func normalize_building_type(type: String) -> String:
	# Normalize common building types
	match type:
		"yes", "building":
			return "commercial"
		"house", "residential", "apartments", "dormitory":
			return "residential"
		"commercial", "retail", "shop", "supermarket":
			return "commercial"
		"industrial", "warehouse":
			return "industrial"
		_:
			return "commercial"
