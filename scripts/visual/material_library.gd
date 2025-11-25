extends Node
class_name MaterialLibrary

## Centralized material library with variations, weathering, and stylization
## Provides easy material access and modification for all building elements

signal materials_updated()

## Material definitions - expanded from original 7 to 15+ types
const MATERIAL_DEFINITIONS = {
	# Wall materials
	"brick_red": {
		"color": Color(0.7, 0.4, 0.3),
		"roughness": 0.9,
		"metallic": 0.0,
		"texture_scale": 2.0,
		"category": "wall"
	},
	"brick_brown": {
		"color": Color(0.6, 0.35, 0.25),
		"roughness": 0.9,
		"metallic": 0.0,
		"texture_scale": 2.0,
		"category": "wall"
	},
	"brick_white": {
		"color": Color(0.85, 0.82, 0.78),
		"roughness": 0.85,
		"metallic": 0.0,
		"texture_scale": 2.0,
		"category": "wall"
	},
	"concrete_gray": {
		"color": Color(0.7, 0.7, 0.7),
		"roughness": 0.7,
		"metallic": 0.0,
		"texture_scale": 4.0,
		"category": "wall"
	},
	"concrete_white": {
		"color": Color(0.88, 0.88, 0.86),
		"roughness": 0.65,
		"metallic": 0.0,
		"texture_scale": 4.0,
		"category": "wall"
	},
	"concrete_dark": {
		"color": Color(0.45, 0.45, 0.45),
		"roughness": 0.75,
		"metallic": 0.0,
		"texture_scale": 4.0,
		"category": "wall"
	},
	"plaster_white": {
		"color": Color(0.9, 0.9, 0.85),
		"roughness": 0.6,
		"metallic": 0.0,
		"texture_scale": 5.0,
		"category": "wall"
	},
	"plaster_cream": {
		"color": Color(0.92, 0.88, 0.78),
		"roughness": 0.6,
		"metallic": 0.0,
		"texture_scale": 5.0,
		"category": "wall"
	},
	"plaster_beige": {
		"color": Color(0.82, 0.75, 0.65),
		"roughness": 0.65,
		"metallic": 0.0,
		"texture_scale": 5.0,
		"category": "wall"
	},
	"stone_gray": {
		"color": Color(0.65, 0.65, 0.6),
		"roughness": 0.85,
		"metallic": 0.0,
		"texture_scale": 3.0,
		"category": "wall"
	},
	"stone_sandstone": {
		"color": Color(0.78, 0.7, 0.55),
		"roughness": 0.8,
		"metallic": 0.0,
		"texture_scale": 3.0,
		"category": "wall"
	},
	"wood_natural": {
		"color": Color(0.6, 0.4, 0.2),
		"roughness": 0.8,
		"metallic": 0.0,
		"texture_scale": 1.0,
		"category": "wall"
	},
	"wood_dark": {
		"color": Color(0.4, 0.25, 0.15),
		"roughness": 0.75,
		"metallic": 0.0,
		"texture_scale": 1.0,
		"category": "wall"
	},
	"wood_painted": {
		"color": Color(0.75, 0.7, 0.65),
		"roughness": 0.5,
		"metallic": 0.0,
		"texture_scale": 1.0,
		"category": "wall"
	},

	# Glass materials
	"glass_clear": {
		"color": Color(0.8, 0.9, 1.0, 0.3),
		"roughness": 0.05,
		"metallic": 0.1,
		"transparency": 0.7,
		"category": "glass"
	},
	"glass_tinted_blue": {
		"color": Color(0.6, 0.75, 0.9, 0.4),
		"roughness": 0.05,
		"metallic": 0.1,
		"transparency": 0.6,
		"category": "glass"
	},
	"glass_tinted_green": {
		"color": Color(0.65, 0.8, 0.7, 0.4),
		"roughness": 0.05,
		"metallic": 0.1,
		"transparency": 0.6,
		"category": "glass"
	},
	"glass_reflective": {
		"color": Color(0.7, 0.75, 0.8, 0.5),
		"roughness": 0.02,
		"metallic": 0.4,
		"transparency": 0.5,
		"category": "glass"
	},

	# Metal materials
	"metal_steel": {
		"color": Color(0.6, 0.6, 0.65),
		"roughness": 0.3,
		"metallic": 0.8,
		"category": "metal"
	},
	"metal_aluminum": {
		"color": Color(0.75, 0.75, 0.76),
		"roughness": 0.25,
		"metallic": 0.85,
		"category": "metal"
	},
	"metal_copper": {
		"color": Color(0.72, 0.45, 0.2),
		"roughness": 0.4,
		"metallic": 0.9,
		"category": "metal"
	},
	"metal_rusted": {
		"color": Color(0.55, 0.35, 0.25),
		"roughness": 0.7,
		"metallic": 0.4,
		"category": "metal"
	},

	# Special materials
	"roof_tiles_red": {
		"color": Color(0.65, 0.3, 0.25),
		"roughness": 0.8,
		"metallic": 0.0,
		"category": "roof"
	},
	"roof_tiles_gray": {
		"color": Color(0.5, 0.5, 0.52),
		"roughness": 0.75,
		"metallic": 0.0,
		"category": "roof"
	},
	"roof_asphalt": {
		"color": Color(0.25, 0.25, 0.25),
		"roughness": 0.9,
		"metallic": 0.0,
		"category": "roof"
	},
	"road_asphalt": {
		"color": Color(0.3, 0.3, 0.3),
		"roughness": 0.85,
		"metallic": 0.0,
		"category": "road"
	},
	"sidewalk_concrete": {
		"color": Color(0.65, 0.65, 0.64),
		"roughness": 0.75,
		"metallic": 0.0,
		"category": "road"
	},
	"water": {
		"color": Color(0.2, 0.4, 0.6, 0.7),
		"roughness": 0.1,
		"metallic": 0.0,
		"transparency": 0.3,
		"category": "water"
	}
}

## Material cache - stores generated StandardMaterial3D instances
var _material_cache: Dictionary = {}

## Stylization settings
var stylization_factor: float = 0.0  # 0.0 = pure PBR, 1.0 = full stylized
var enable_weathering: bool = true
var weathering_intensity: float = 0.3

## Color variation settings
var enable_color_variation: bool = true
var color_variation_amount: float = 0.15  # 15% color variation

func initialize() -> void:
	print("[MaterialLibrary] Initializing with ", MATERIAL_DEFINITIONS.size(), " material definitions")
	_generate_all_materials()

func _generate_all_materials() -> void:
	"""Pre-generate all materials and cache them"""
	for material_name in MATERIAL_DEFINITIONS.keys():
		_create_material(material_name)
	print("[MaterialLibrary] Generated ", _material_cache.size(), " materials")

func get_material(material_name: String, apply_variation: bool = false) -> StandardMaterial3D:
	"""Get a material by name, optionally with color variation"""
	if not _material_cache.has(material_name):
		print("[MaterialLibrary] Warning: Material '", material_name, "' not found, using default")
		material_name = "concrete_gray"

	var base_material = _material_cache[material_name]

	if apply_variation and enable_color_variation:
		# Create a duplicate with slight color variation
		var varied_material = base_material.duplicate()
		var varied_color = _apply_color_variation(base_material.albedo_color)
		varied_material.albedo_color = varied_color
		return varied_material

	return base_material

func _create_material(material_name: String) -> StandardMaterial3D:
	"""Create a StandardMaterial3D from definition"""
	if not MATERIAL_DEFINITIONS.has(material_name):
		print("[MaterialLibrary] Error: Definition for '", material_name, "' not found")
		return null

	var def = MATERIAL_DEFINITIONS[material_name]
	var mat = StandardMaterial3D.new()

	# Basic properties
	mat.albedo_color = def["color"]
	mat.roughness = def["roughness"]
	mat.metallic = def.get("metallic", 0.0)

	# Transparency for glass and water
	if def.has("transparency"):
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var color = mat.albedo_color
		color.a = 1.0 - def["transparency"]
		mat.albedo_color = color

	# Enable features for better visuals
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	# Cache the material
	_material_cache[material_name] = mat

	return mat

func _apply_color_variation(base_color: Color) -> Color:
	"""Apply subtle random variation to a color"""
	var variation = color_variation_amount
	var h_shift = randf_range(-variation * 0.5, variation * 0.5)
	var s_shift = randf_range(-variation, variation)
	var v_shift = randf_range(-variation * 0.3, variation * 0.3)

	var hsv_color = Color.from_hsv(
		fmod(base_color.h + h_shift + 1.0, 1.0),
		clamp(base_color.s + s_shift, 0.0, 1.0),
		clamp(base_color.v + v_shift, 0.0, 1.0),
		base_color.a
	)

	return hsv_color

func get_material_by_osm_tags(osm_data: Dictionary, category: String = "wall") -> String:
	"""Infer material name from OSM building tags"""
	var material_tag = osm_data.get("building:material", "")
	var building_type = osm_data.get("building_type", "")
	var building_color = osm_data.get("building:colour", "")

	# Direct material mapping
	match material_tag:
		"brick":
			if "red" in building_color.to_lower():
				return "brick_red"
			elif "white" in building_color.to_lower():
				return "brick_white"
			else:
				return "brick_brown"
		"concrete":
			if "white" in building_color.to_lower():
				return "concrete_white"
			elif "dark" in building_color.to_lower() or "gray" in building_color.to_lower():
				return "concrete_dark"
			else:
				return "concrete_gray"
		"plaster", "stucco":
			if "white" in building_color.to_lower():
				return "plaster_white"
			elif "cream" in building_color.to_lower() or "yellow" in building_color.to_lower():
				return "plaster_cream"
			else:
				return "plaster_beige"
		"wood":
			if "dark" in building_color.to_lower():
				return "wood_dark"
			elif "painted" in building_color.to_lower() or "white" in building_color.to_lower():
				return "wood_painted"
			else:
				return "wood_natural"
		"stone":
			if "sand" in building_color.to_lower() or "tan" in building_color.to_lower():
				return "stone_sandstone"
			else:
				return "stone_gray"
		"metal":
			return "metal_steel"

	# Fallback: infer from building type
	match building_type:
		"house", "residential", "apartments":
			return "brick_red"
		"commercial", "retail":
			return "concrete_gray"
		"industrial", "warehouse":
			return "concrete_dark"
		"office":
			return "concrete_white"
		_:
			return "concrete_gray"

func get_glass_material(building_type: String = "residential") -> String:
	"""Get appropriate glass material for building type"""
	match building_type:
		"office", "commercial":
			return "glass_reflective"
		"industrial", "warehouse":
			return "glass_tinted_blue"
		_:
			return "glass_clear"

func get_roof_material(osm_data: Dictionary) -> String:
	"""Get roof material from OSM data"""
	var roof_material = osm_data.get("roof:material", "")
	var roof_color = osm_data.get("roof:colour", "")
	var building_type = osm_data.get("building_type", "")

	# Direct material mapping
	if roof_material == "tiles" or roof_material == "tile":
		if "gray" in roof_color.to_lower():
			return "roof_tiles_gray"
		else:
			return "roof_tiles_red"
	elif roof_material == "metal":
		return "metal_aluminum"
	elif roof_material == "concrete":
		return "concrete_gray"

	# Infer from building type
	match building_type:
		"house", "residential":
			return "roof_tiles_red"
		"commercial", "office", "industrial":
			return "concrete_gray"
		_:
			return "roof_asphalt"

func set_stylization_factor(value: float) -> void:
	"""Set stylization factor and update materials"""
	stylization_factor = clamp(value, 0.0, 1.0)
	_update_all_materials_stylization()

func _update_all_materials_stylization() -> void:
	"""Update all cached materials with current stylization"""
	for material_name in _material_cache.keys():
		var mat = _material_cache[material_name]
		var def = MATERIAL_DEFINITIONS[material_name]

		# Blend between realistic and stylized based on factor
		# At 1.0 stylization, reduce metallic and increase roughness for flatter look
		var base_metallic = def.get("metallic", 0.0)
		var base_roughness = def["roughness"]

		mat.metallic = lerp(base_metallic, 0.0, stylization_factor * 0.5)
		mat.roughness = lerp(base_roughness, 1.0, stylization_factor * 0.3)

func refresh_all_materials() -> void:
	"""Regenerate all materials (useful after settings change)"""
	_material_cache.clear()
	_generate_all_materials()
	materials_updated.emit()
	print("[MaterialLibrary] All materials refreshed")

func apply_settings(settings: Dictionary) -> void:
	"""Apply material settings from a dictionary"""
	if settings.has("stylization_factor"):
		stylization_factor = settings["stylization_factor"]
	if settings.has("enable_weathering"):
		enable_weathering = settings["enable_weathering"]
	if settings.has("weathering_intensity"):
		weathering_intensity = settings["weathering_intensity"]
	if settings.has("enable_color_variation"):
		enable_color_variation = settings["enable_color_variation"]
	if settings.has("color_variation_amount"):
		color_variation_amount = settings["color_variation_amount"]

	_update_all_materials_stylization()

func get_current_settings() -> Dictionary:
	"""Get current material settings"""
	return {
		"stylization_factor": stylization_factor,
		"enable_weathering": enable_weathering,
		"weathering_intensity": weathering_intensity,
		"enable_color_variation": enable_color_variation,
		"color_variation_amount": color_variation_amount
	}

func get_available_materials_by_category(category: String) -> Array:
	"""Get all material names for a specific category"""
	var materials = []
	for material_name in MATERIAL_DEFINITIONS.keys():
		if MATERIAL_DEFINITIONS[material_name].get("category", "") == category:
			materials.append(material_name)
	return materials

func get_random_material_from_category(category: String) -> String:
	"""Get a random material name from a category"""
	var materials = get_available_materials_by_category(category)
	if materials.size() > 0:
		return materials[randi() % materials.size()]
	return "concrete_gray"
