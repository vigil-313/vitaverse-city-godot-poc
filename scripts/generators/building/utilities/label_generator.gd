extends Node
class_name LabelGenerator

## Generates 3D text labels for landmark buildings
## Large, crisp, slowly rotating labels visible from far away

const RotatingLabel = preload("res://scripts/generators/building/utilities/rotating_label.gd")

const LABEL_HEIGHT_OFFSET = 40.0  # 40m above building for visibility
const FONT_SIZE = 600            # Huge for distance visibility

## Add name label to building
static func add_label(
	building: Node3D,
	building_name: String,
	height: float,
	base_elevation: float
) -> void:
	# Create a container that will rotate
	var label_container = Node3D.new()
	label_container.name = "LabelContainer"
	label_container.position = Vector3(0, height + base_elevation + LABEL_HEIGHT_OFFSET, 0)
	label_container.set_script(RotatingLabel)

	var label = Label3D.new()
	label.name = "BuildingLabel"
	label.text = building_name.to_upper()

	# Large crisp text - bright cyan/teal color stands out against white buildings
	label.font_size = FONT_SIZE
	label.outline_size = 8  # Thin dark outline for readability
	label.modulate = Color(0.0, 0.9, 1.0)  # Bright cyan - stands out
	label.outline_modulate = Color(0.0, 0.2, 0.3)  # Dark teal outline

	# No billboard - we control rotation ourselves
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.no_depth_test = true  # Always visible
	label.double_sided = true   # Visible from both sides

	# High quality rendering
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	label.pixel_size = 0.01  # Scale for world units

	label_container.add_child(label)
	building.add_child(label_container)
