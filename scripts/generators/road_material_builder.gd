extends RefCounted
class_name RoadMaterialBuilder

## Road Material Builder
##
## Creates and caches materials for road surfaces, markings, and curbs.
## Extracted from RoadMeshBatcher to improve organization.
##
## Usage:
##   var material = RoadMaterialBuilder.get_material(RoadMaterialBuilder.MaterialType.ASPHALT)

## Material types for road surfaces
enum MaterialType {
	ASPHALT,       # Main road surface
	CONCRETE,      # Sidewalks
	CURB,          # Curb geometry
	MARKING_WHITE, # White lane markings
	MARKING_YELLOW # Yellow center lines
}

## Cached materials for reuse
static var _materials: Dictionary = {}

# ========================================================================
# MATERIAL COLORS
# ========================================================================

const COLOR_ASPHALT = Color(0.25, 0.25, 0.27)
const COLOR_CONCRETE = Color(0.5, 0.48, 0.45)
const COLOR_CURB = Color(0.6, 0.6, 0.58)
const COLOR_MARKING_WHITE = Color(0.95, 0.95, 0.95)
const COLOR_MARKING_YELLOW = Color(0.95, 0.85, 0.2)

# ========================================================================
# PUBLIC API
# ========================================================================

## Get or create a cached material for the given type
static func get_material(type: MaterialType, material_library = null) -> Material:
	if _materials.has(type):
		return _materials[type]

	var material = _create_material(type, material_library)
	_materials[type] = material
	return material

## Clear the material cache (call if materials need to be regenerated)
static func clear_cache() -> void:
	_materials.clear()

## Get all material types as array (for iteration)
static func get_all_types() -> Array:
	return MaterialType.values()

## Get human-readable name for a material type
static func get_type_name(type: MaterialType) -> String:
	match type:
		MaterialType.ASPHALT:
			return "Asphalt"
		MaterialType.CONCRETE:
			return "Concrete"
		MaterialType.CURB:
			return "Curbs"
		MaterialType.MARKING_WHITE:
			return "MarkingsWhite"
		MaterialType.MARKING_YELLOW:
			return "MarkingsYellow"
		_:
			return "Unknown"

# ========================================================================
# MATERIAL CREATION
# ========================================================================

## Create a new material for the given type
static func _create_material(type: MaterialType, material_library = null) -> StandardMaterial3D:
	match type:
		MaterialType.ASPHALT:
			return _create_asphalt_material(material_library)
		MaterialType.CONCRETE:
			return _create_concrete_material()
		MaterialType.CURB:
			return _create_curb_material()
		MaterialType.MARKING_WHITE:
			return _create_marking_material(COLOR_MARKING_WHITE)
		MaterialType.MARKING_YELLOW:
			return _create_marking_material(COLOR_MARKING_YELLOW)
		_:
			return _create_default_material()

## Create asphalt road material (optionally from library)
static func _create_asphalt_material(material_library = null) -> StandardMaterial3D:
	# Try to get from material library first
	if material_library and material_library.has_method("get_material"):
		var lib_material = material_library.get_material("road_asphalt")
		if lib_material:
			return lib_material

	# Create default asphalt
	var material = StandardMaterial3D.new()
	material.albedo_color = COLOR_ASPHALT
	material.roughness = 0.9
	material.metallic = 0.0
	return material

## Create concrete sidewalk material
static func _create_concrete_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = COLOR_CONCRETE
	material.roughness = 0.85
	material.metallic = 0.0
	return material

## Create curb material
static func _create_curb_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = COLOR_CURB
	material.roughness = 0.85
	material.metallic = 0.0
	return material

## Create lane marking material (white or yellow)
static func _create_marking_material(color: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.5
	material.metallic = 0.0
	return material

## Fallback default material
static func _create_default_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.5, 0.5, 0.5)
	material.roughness = 0.8
	return material
