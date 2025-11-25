extends Node
class_name LabelGenerator

## Generates 3D text labels for buildings

const LABEL_HEIGHT_OFFSET = 10.0  # 10m above building
const FONT_SIZE = 128
const OUTLINE_SIZE = 32

## Add name label to building
static func add_label(
	building: Node3D,
	building_name: String,
	height: float,
	base_elevation: float
) -> void:
	var label = Label3D.new()
	label.name = "BuildingLabel"  # Name it so we can find it later for culling
	label.text = building_name
	label.position = Vector3(0, height + base_elevation + LABEL_HEIGHT_OFFSET, 0)

	# Visual styling
	label.font_size = FONT_SIZE  # Smaller, more readable size
	label.outline_size = OUTLINE_SIZE  # Extra thick outline creates background effect
	label.modulate = Color(0.9, 0.9, 0.9)  # Light gray, easy to read
	label.outline_modulate = Color(0, 0, 0, 0.7)  # Semi-transparent black outline

	# Billboard and rendering
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true  # Always visible through objects

	# Transparency settings
	label.alpha_cut = 0  # Ensure alpha is respected
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	building.add_child(label)
