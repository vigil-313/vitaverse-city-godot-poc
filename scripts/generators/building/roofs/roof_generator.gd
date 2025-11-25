extends Node
class_name RoofGenerator

## Roof generation coordinator
## Selects and generates appropriate roof shape

const FlatRoof = preload("res://scripts/generators/building/roofs/shapes/flat_roof.gd")
# NOTE: Other roof shapes currently disabled due to geometry issues on irregular footprints
# const GabledRoof = preload("res://scripts/generators/building/roofs/shapes/gabled_roof.gd")
# const HippedRoof = preload("res://scripts/generators/building/roofs/shapes/hipped_roof.gd")
# const PyramidalRoof = preload("res://scripts/generators/building/roofs/shapes/pyramidal_roof.gd")

## Generate roof based on shape from context
static func generate_roof(context, surfaces: Dictionary) -> void:
	var roof_surface = surfaces["roof"]

	# Currently all roofs are forced to flat in BuildingContext
	# because sloped roofs have geometry issues on irregular footprints
	match context.roof_shape:
		"flat", "":
			FlatRoof.generate(context.footprint, context.center, context.height, roof_surface)
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
