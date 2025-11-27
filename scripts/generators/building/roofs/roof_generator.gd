extends Node
class_name RoofGenerator

## Roof generation coordinator
## Selects and generates appropriate roof shape, parapets, and equipment

const FlatRoof = preload("res://scripts/generators/building/roofs/shapes/flat_roof.gd")
const ParapetGenerator = preload("res://scripts/generators/building/roofs/details/parapet_generator.gd")
const RooftopEquipment = preload("res://scripts/generators/building/roofs/details/rooftop_equipment.gd")
# NOTE: Other roof shapes currently disabled due to geometry issues on irregular footprints
# const GabledRoof = preload("res://scripts/generators/building/roofs/shapes/gabled_roof.gd")
# const HippedRoof = preload("res://scripts/generators/building/roofs/shapes/hipped_roof.gd")
# const PyramidalRoof = preload("res://scripts/generators/building/roofs/shapes/pyramidal_roof.gd")

## Building types that get parapets
const PARAPET_TYPES = ["commercial", "retail", "office", "industrial", "warehouse"]

## Generate roof based on shape from context
static func generate_roof(context, surfaces: Dictionary) -> void:
	var roof_surface = surfaces["roof"]
	var wall_surface = surfaces["wall"]

	# Currently all roofs are forced to flat in BuildingContext
	# because sloped roofs have geometry issues on irregular footprints
	match context.roof_shape:
		"flat", "":
			FlatRoof.generate(context.footprint, context.center, context.height, roof_surface)

			# Add parapets to commercial/industrial flat roofs (multi-story only)
			if context.detailed and context.levels > 2 and _should_have_parapet(context.building_type):
				ParapetGenerator.generate(context.footprint, context.center, context.height, wall_surface)

			# Add rooftop equipment
			if context.detailed:
				RooftopEquipment.generate(context, wall_surface)
		# These are disabled in BuildingContext but included for future use:
		# "gabled":
		#	 GabledRoof.generate(context.footprint, context.center, context.height, context.osm_data, roof_surface)
		# "hipped":
		#	 HippedRoof.generate(context.footprint, context.center, context.height, context.osm_data, roof_surface)
		# "pyramidal":
		#	 PyramidalRoof.generate(context.footprint, context.center, context.height, context.osm_data, roof_surface)
		_:
			# Fallback to flat
			FlatRoof.generate(context.footprint, context.center, context.height, roof_surface)

			# Add equipment on fallback roofs too
			if context.detailed:
				RooftopEquipment.generate(context, wall_surface)

## Check if building type should have parapet
static func _should_have_parapet(building_type: String) -> bool:
	var type_lower = building_type.to_lower()
	for parapet_type in PARAPET_TYPES:
		if type_lower.contains(parapet_type):
			return true
	return false
