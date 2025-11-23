extends Resource
class_name BuildingTemplate

# Building metadata
@export var template_name: String = "Generic Building"
@export var building_type: String = "residential"  # residential, commercial, retail, office, landmark

# Dimensions (in meters, will be scaled from OSM)
@export var default_width: float = 10.0
@export var default_depth: float = 8.0
@export var floor_height: float = 3.0
@export var default_floors: int = 2

# Style parameters
@export var wall_material_type: String = "brick"  # brick, concrete, glass, wood
@export var wall_color: Color = Color(0.6, 0.3, 0.2)
@export var roof_type: String = "flat"  # flat, peaked, complex
@export var roof_color: Color = Color(0.5, 0.25, 0.15)

# Window configuration
@export var window_style: String = "standard"  # standard, large, storefront, none
@export var windows_per_floor: int = 4
@export var window_spacing: float = 2.5

# Ground floor details
@export var has_storefront: bool = false
@export var has_awning: bool = false
@export var awning_color: Color = Color(0.8, 0.2, 0.2)

# Decorative elements
@export var has_chimney: bool = false
@export var has_balcony: bool = false
@export var corner_style: String = "simple"  # simple, ornate, modern

# Props
@export var outdoor_seating: bool = false
@export var window_boxes: bool = false
@export var entrance_type: String = "door"  # door, double_door, glass_door, revolving

# Seattle-specific
@export var seattle_era: String = "modern"  # pioneer_square, early_1900s, mid_century, modern, contemporary
@export var iconic_feature: String = ""  # For landmarks like Space Needle, Pike Place, etc.
