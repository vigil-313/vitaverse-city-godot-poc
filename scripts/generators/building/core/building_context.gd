extends RefCounted
class_name BuildingContext

## Shared context object for building generation
## Contains all data needed by subsystems, avoiding parameter hell

# OSM Data
var osm_data: Dictionary = {}
var building_id: int = 0
var building_name: String = ""
var building_type: String = ""

# Geometry
var footprint: Array = []
var center: Vector2 = Vector2.ZERO
var height: float = 6.0
var levels: int = 2
var floor_height: float = 3.0

# Elevation
var layer: int = 0
var min_level: int = 0
var base_elevation: float = 0.0

# Roof
var roof_shape: String = "flat"
var roof_height: float = 0.0

# Flags
var detailed: bool = true

# External systems
var material_lib = null

## Initialize context from OSM data
func initialize(p_osm_data: Dictionary, p_detailed: bool, p_material_lib) -> void:
	osm_data = p_osm_data
	detailed = p_detailed
	material_lib = p_material_lib

	# Extract basic data
	building_id = int(osm_data.get("id", 0))
	building_name = osm_data.get("name", "")
	building_type = osm_data.get("building_type", "yes")

	# Geometry
	footprint = osm_data.get("footprint", [])
	center = osm_data.get("center", Vector2.ZERO)
	height = osm_data.get("height", 6.0)
	levels = osm_data.get("levels", 2)
	floor_height = height / float(levels) if levels > 0 else height

	# Elevation
	layer = osm_data.get("layer", 0)
	min_level = osm_data.get("min_level", 0)
	base_elevation = (layer * 5.0) + (min_level * 3.0)

	# Roof
	roof_shape = osm_data.get("roof:shape", "flat")
	# Force flat roofs for now (sloped roof algorithms have issues with irregular footprints)
	if roof_shape in ["gabled", "hipped", "pyramidal", ""]:
		roof_shape = "flat"

## Get a value from OSM data with fallback
func get_osm(key: String, default = null):
	return osm_data.get(key, default)
