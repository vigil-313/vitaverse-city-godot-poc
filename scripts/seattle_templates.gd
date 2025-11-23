extends Node
class_name SeattleTemplates

# Seattle-specific building templates for accurate recreation

static func get_template_for_building(osm_data: Dictionary) -> BuildingTemplate:
	"""Select appropriate template based on OSM data"""
	var building_type = osm_data.get("type", "yes")
	var amenity = osm_data.get("amenity", "")
	var shop = osm_data.get("shop", "")
	var building_name = osm_data.get("name", "").to_lower()

	# Check for iconic Seattle landmarks
	if "space needle" in building_name:
		return create_space_needle_template()
	elif "pike place" in building_name or "market" in building_name:
		return create_pike_place_template()

	# Check by amenity/shop type
	if amenity == "cafe" or shop == "coffee":
		return create_seattle_cafe_template()
	elif shop in ["convenience", "supermarket", "department_store"]:
		return create_retail_store_template()
	elif amenity == "restaurant":
		return create_restaurant_template()

	# Check by building type
	if building_type == "commercial":
		return create_commercial_building_template()
	elif building_type == "retail":
		return create_retail_building_template()
	elif building_type == "apartments":
		return create_apartment_building_template()
	elif building_type == "house":
		return create_seattle_house_template()
	elif building_type == "industrial":
		return create_industrial_template()

	# Default
	return create_default_building_template()

# ICONIC LANDMARKS

static func create_space_needle_template() -> BuildingTemplate:
	var template = BuildingTemplate.new()
	template.template_name = "Space Needle"
	template.building_type = "landmark"
	template.default_width = 20.0
	template.default_depth = 20.0
	template.floor_height = 5.0
	template.default_floors = 120  # ~184m tall
	template.wall_material_type = "concrete"
	template.wall_color = Color(0.9, 0.9, 0.9)
	template.iconic_feature = "space_needle"
	template.seattle_era = "mid_century"
	return template

static func create_pike_place_template() -> BuildingTemplate:
	var template = BuildingTemplate.new()
	template.template_name = "Pike Place Market"
	template.building_type = "landmark"
	template.default_width = 40.0
	template.default_depth = 30.0
	template.floor_height = 4.0
	template.default_floors = 3
	template.wall_material_type = "brick"
	template.wall_color = Color(0.7, 0.3, 0.2)
	template.has_awning = true
	template.awning_color = Color(0.9, 0.1, 0.1)
	template.has_storefront = true
	template.seattle_era = "early_1900s"
	template.iconic_feature = "pike_place"
	return template

# SEATTLE-SPECIFIC STYLES

static func create_seattle_cafe_template() -> BuildingTemplate:
	"""Cozy Seattle coffee shop - brick with large windows"""
	var template = BuildingTemplate.new()
	template.template_name = "Seattle Cafe"
	template.building_type = "retail"
	template.default_width = 12.0
	template.default_depth = 10.0
	template.floor_height = 3.5
	template.default_floors = 2
	template.wall_material_type = "brick"
	template.wall_color = Color(0.6, 0.3, 0.2)
	template.roof_type = "peaked"
	template.window_style = "storefront"
	template.windows_per_floor = 4
	template.has_awning = true
	template.awning_color = Color(0.3, 0.5, 0.3)
	template.outdoor_seating = true
	template.window_boxes = true
	template.entrance_type = "glass_door"
	template.has_chimney = true
	template.seattle_era = "contemporary"
	return template

static func create_seattle_house_template() -> BuildingTemplate:
	"""Classic Seattle craftsman-style house"""
	var template = BuildingTemplate.new()
	template.template_name = "Seattle Craftsman House"
	template.building_type = "residential"
	template.default_width = 10.0
	template.default_depth = 12.0
	template.floor_height = 3.0
	template.default_floors = 2
	template.wall_material_type = "wood"
	template.wall_color = Color(0.5, 0.45, 0.4)
	template.roof_type = "peaked"
	template.roof_color = Color(0.3, 0.25, 0.2)
	template.window_style = "standard"
	template.windows_per_floor = 3
	template.has_chimney = true
	template.entrance_type = "door"
	template.corner_style = "ornate"
	template.seattle_era = "early_1900s"
	return template

static func create_apartment_building_template() -> BuildingTemplate:
	"""Modern Seattle apartment building"""
	var template = BuildingTemplate.new()
	template.template_name = "Modern Apartment"
	template.building_type = "residential"
	template.default_width = 25.0
	template.default_depth = 20.0
	template.floor_height = 3.0
	template.default_floors = 6
	template.wall_material_type = "concrete"
	template.wall_color = Color(0.7, 0.7, 0.7)
	template.roof_type = "flat"
	template.window_style = "large"
	template.windows_per_floor = 8
	template.has_balcony = true
	template.entrance_type = "glass_door"
	template.seattle_era = "contemporary"
	return template

# COMMERCIAL BUILDINGS

static func create_commercial_building_template() -> BuildingTemplate:
	"""Generic Seattle commercial building"""
	var template = BuildingTemplate.new()
	template.template_name = "Commercial Building"
	template.building_type = "commercial"
	template.default_width = 20.0
	template.default_depth = 15.0
	template.floor_height = 3.5
	template.default_floors = 4
	template.wall_material_type = "concrete"
	template.wall_color = Color(0.65, 0.65, 0.7)
	template.roof_type = "flat"
	template.window_style = "large"
	template.windows_per_floor = 6
	template.entrance_type = "double_door"
	template.seattle_era = "modern"
	return template

static func create_retail_building_template() -> BuildingTemplate:
	"""Street-level retail building"""
	var template = BuildingTemplate.new()
	template.template_name = "Retail Store"
	template.building_type = "retail"
	template.default_width = 15.0
	template.default_depth = 12.0
	template.floor_height = 4.0
	template.default_floors = 2
	template.wall_material_type = "brick"
	template.wall_color = Color(0.55, 0.4, 0.35)
	template.roof_type = "flat"
	template.has_storefront = true
	template.window_style = "storefront"
	template.has_awning = true
	template.awning_color = Color(0.2, 0.4, 0.6)
	template.entrance_type = "glass_door"
	template.seattle_era = "modern"
	return template

static func create_retail_store_template() -> BuildingTemplate:
	"""Small retail shop"""
	var template = BuildingTemplate.new()
	template.template_name = "Small Shop"
	template.building_type = "retail"
	template.default_width = 10.0
	template.default_depth = 8.0
	template.floor_height = 3.5
	template.default_floors = 1
	template.wall_material_type = "wood"
	template.wall_color = Color(0.6, 0.5, 0.4)
	template.roof_type = "flat"
	template.has_storefront = true
	template.window_style = "storefront"
	template.entrance_type = "door"
	template.seattle_era = "contemporary"
	return template

static func create_restaurant_template() -> BuildingTemplate:
	"""Seattle restaurant"""
	var template = BuildingTemplate.new()
	template.template_name = "Restaurant"
	template.building_type = "retail"
	template.default_width = 14.0
	template.default_depth = 12.0
	template.floor_height = 3.5
	template.default_floors = 1
	template.wall_material_type = "brick"
	template.wall_color = Color(0.65, 0.35, 0.25)
	template.roof_type = "flat"
	template.has_storefront = true
	template.window_style = "storefront"
	template.has_awning = true
	template.awning_color = Color(0.8, 0.2, 0.2)
	template.outdoor_seating = true
	template.entrance_type = "glass_door"
	template.seattle_era = "contemporary"
	return template

static func create_industrial_template() -> BuildingTemplate:
	"""Industrial/warehouse building"""
	var template = BuildingTemplate.new()
	template.template_name = "Industrial Building"
	template.building_type = "industrial"
	template.default_width = 30.0
	template.default_depth = 40.0
	template.floor_height = 5.0
	template.default_floors = 2
	template.wall_material_type = "concrete"
	template.wall_color = Color(0.5, 0.5, 0.55)
	template.roof_type = "flat"
	template.window_style = "standard"
	template.windows_per_floor = 4
	template.entrance_type = "double_door"
	template.seattle_era = "mid_century"
	return template

static func create_default_building_template() -> BuildingTemplate:
	"""Default fallback template"""
	var template = BuildingTemplate.new()
	template.template_name = "Generic Building"
	template.building_type = "commercial"
	template.default_width = 12.0
	template.default_depth = 10.0
	template.floor_height = 3.0
	template.default_floors = 2
	template.wall_material_type = "brick"
	template.wall_color = Color(0.6, 0.4, 0.3)
	template.roof_type = "flat"
	template.window_style = "standard"
	template.windows_per_floor = 4
	template.entrance_type = "door"
	template.seattle_era = "modern"
	return template
