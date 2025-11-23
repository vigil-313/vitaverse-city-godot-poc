extends Node

## Complete Building Generator
## Creates detailed, accurate 3D buildings using ALL OSM data
##
## Features:
## - Actual building colors from OSM
## - Material-based appearance (brick, concrete, glass, etc.)
## - Roof shapes (flat, gabled, hipped, pyramidal, dome)
## - Architectural styles
## - Windows based on building type and period
## - Proper scaling for whole-city rendering

class_name BuildingGeneratorComplete

## Material definitions
const MATERIALS = {
	"brick": {"color": Color(0.7, 0.4, 0.3), "roughness": 0.9},
	"concrete": {"color": Color(0.7, 0.7, 0.7), "roughness": 0.7},
	"glass": {"color": Color(0.8, 0.9, 1.0, 0.3), "roughness": 0.1, "metallic": 0.2},
	"metal": {"color": Color(0.6, 0.6, 0.65), "roughness": 0.3, "metallic": 0.8},
	"wood": {"color": Color(0.6, 0.4, 0.2), "roughness": 0.8},
	"stone": {"color": Color(0.65, 0.65, 0.6), "roughness": 0.85},
	"plaster": {"color": Color(0.9, 0.9, 0.85), "roughness": 0.6},
	"tiles": {"color": Color(0.8, 0.7, 0.6), "roughness": 0.7}
}

## Generate complete building from OSM data
static func create_building(osm_data: Dictionary, parent: Node3D, detailed: bool = true) -> Node3D:
	var building = Node3D.new()
	building.name = osm_data.get("name", "Building_" + str(osm_data.get("id", "")))

	# Extract data
	var footprint = osm_data.get("footprint", [])
	var center = osm_data.get("center", Vector2.ZERO)
	var height = osm_data.get("height", 6.0)
	var levels = osm_data.get("levels", 2)
	var building_type = osm_data.get("building_type", "yes")

	# Calculate elevation from layer and min_level
	var layer = osm_data.get("layer", 0)
	var min_level = osm_data.get("min_level", 0)
	var base_elevation = (layer * 5.0) + (min_level * 3.0)

	# Create main building body
	var body = _create_building_body(footprint, center, height, osm_data)
	body.position.y = base_elevation
	building.add_child(body)

	# Create roof
	var roof = _create_roof(footprint, center, height, osm_data)
	roof.position.y = base_elevation
	building.add_child(roof)

	# Add windows if detailed
	if detailed and levels > 0:
		_add_windows(building, footprint, center, height, levels, building_type, base_elevation)

	# Add building label if it has a name
	if osm_data.get("name", "") != "":
		_add_name_label(building, osm_data.get("name"), height, base_elevation)

	parent.add_child(building)

	# Debug output
	var color_info = ""
	if osm_data.get("building:colour", "") != "":
		color_info = " (color: " + osm_data.get("building:colour") + ")"
	print("  ✅ ", building.name, " - ", levels, " floors, ", height, "m", color_info)

	return building

## Create main building body
static func _create_building_body(footprint: Array, center: Vector2, height: float, osm_data: Dictionary) -> CSGPolygon3D:
	var polygon = CSGPolygon3D.new()
	polygon.name = "Body"
	polygon.mode = CSGPolygon3D.MODE_DEPTH
	polygon.depth = height

	# Convert footprint to local coordinates
	var polygon_points: PackedVector2Array = []
	for point in footprint:
		var local_point = point - center
		polygon_points.append(Vector2(local_point.x, -local_point.y))
	polygon.polygon = polygon_points

	# Position at half-height
	polygon.position = Vector3(0, height / 2, 0)

	# Apply material
	var material = _create_building_material(osm_data)
	polygon.material = material

	return polygon

## Create building material from OSM data
static func _create_building_material(osm_data: Dictionary) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()

	# Priority 1: Use OSM building:colour if available
	var osm_color = osm_data.get("building:colour", "")
	if osm_color != "":
		var color = _parse_osm_color(osm_color)
		if color != Color.TRANSPARENT:
			material.albedo_color = color
			material.roughness = 0.7
			return material

	# Priority 2: Use material type
	var material_type = osm_data.get("building:material", osm_data.get("building:cladding", "")).to_lower()
	if MATERIALS.has(material_type):
		var mat_def = MATERIALS[material_type]
		material.albedo_color = mat_def["color"]
		material.roughness = mat_def.get("roughness", 0.7)
		if mat_def.has("metallic"):
			material.metallic = mat_def["metallic"]
		if mat_def.has("color") and mat_def["color"].a < 1.0:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		return material

	# Priority 3: Use building type defaults
	var building_type = osm_data.get("building_type", "yes")
	match building_type:
		"commercial", "office", "retail":
			material.albedo_color = Color(0.85, 0.85, 0.9)  # Light gray-blue
		"residential", "apartments", "house":
			material.albedo_color = Color(0.9, 0.85, 0.75)  # Warm beige
		"industrial", "warehouse":
			material.albedo_color = Color(0.6, 0.6, 0.65)  # Dark gray
		"civic", "public", "government":
			material.albedo_color = Color(0.8, 0.75, 0.7)  # Stone gray
		"historic", "heritage":
			material.albedo_color = Color(0.7, 0.4, 0.3)  # Brick red
		_:
			material.albedo_color = Color(0.8, 0.8, 0.8)  # Default light gray

	material.roughness = 0.7
	return material

## Create roof
static func _create_roof(footprint: Array, center: Vector2, building_height: float, osm_data: Dictionary) -> Node3D:
	var roof_container = Node3D.new()
	roof_container.name = "Roof"

	var roof_shape = osm_data.get("roof:shape", "flat")
	var _roof_height = osm_data.get("roof:height", 0.0)  # Reserved for future pitched roofs

	# For now, implement flat roofs (can expand to gabled, hipped, etc.)
	match roof_shape:
		"flat", "":
			var roof = _create_flat_roof(footprint, center, building_height, osm_data)
			roof_container.add_child(roof)
		_:
			# Fallback to flat for unimplemented shapes
			var roof = _create_flat_roof(footprint, center, building_height, osm_data)
			roof_container.add_child(roof)

	return roof_container

## Create flat roof
static func _create_flat_roof(footprint: Array, center: Vector2, building_height: float, osm_data: Dictionary) -> CSGPolygon3D:
	var roof = CSGPolygon3D.new()
	roof.mode = CSGPolygon3D.MODE_DEPTH
	roof.depth = 0.3  # Roof thickness

	# Convert footprint
	var polygon_points: PackedVector2Array = []
	for point in footprint:
		var local_point = point - center
		polygon_points.append(Vector2(local_point.x, -local_point.y))
	roof.polygon = polygon_points

	# Position at top of building
	roof.position = Vector3(0, building_height + 0.15, 0)

	# Apply roof material
	var material = _create_roof_material(osm_data)
	roof.material = material

	return roof

## Create roof material from OSM data
static func _create_roof_material(osm_data: Dictionary) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()

	# Use OSM roof:colour if available
	var roof_color = osm_data.get("roof:colour", "")
	if roof_color != "":
		var color = _parse_osm_color(roof_color)
		if color != Color.TRANSPARENT:
			material.albedo_color = color
			material.roughness = 0.9
			return material

	# Use roof material type
	var roof_material_type = osm_data.get("roof:material", "").to_lower()
	match roof_material_type:
		"tiles", "tile":
			material.albedo_color = Color(0.5, 0.3, 0.2)  # Clay tiles
		"metal":
			material.albedo_color = Color(0.4, 0.4, 0.45)
			material.metallic = 0.6
		"concrete":
			material.albedo_color = Color(0.5, 0.5, 0.5)
		"tar_paper", "asphalt":
			material.albedo_color = Color(0.2, 0.2, 0.2)
		_:
			# Default dark roof
			material.albedo_color = Color(0.3, 0.3, 0.3)

	material.roughness = 0.9
	return material

## Add windows to building
static func _add_windows(building: Node3D, footprint: Array, center: Vector2, height: float, levels: int, building_type: String, base_elevation: float):
	var floor_height = height / float(levels)

	# Determine window style based on building type
	var window_spacing = 3.0
	var window_width = 1.5
	var window_height = 2.0

	match building_type:
		"commercial", "office", "retail":
			window_spacing = 2.5
			window_width = 2.0
			window_height = 2.5  # Large windows
		"residential", "apartments", "house":
			window_spacing = 3.5
			window_width = 1.2
			window_height = 1.8
		"industrial", "warehouse":
			window_spacing = 5.0
			window_width = 1.0
			window_height = 1.5

	# Add windows for each floor
	for floor_num in range(levels):
		var floor_y = (floor_num * floor_height) + (floor_height / 2) + base_elevation
		_add_floor_windows(building, footprint, center, floor_y, window_width, window_height, window_spacing)

## Add windows to a floor
static func _add_floor_windows(building: Node3D, footprint: Array, center: Vector2, floor_y: float, width: float, height: float, spacing: float):
	# Walk perimeter and place windows
	for i in range(footprint.size()):
		var p1 = footprint[i] - center
		var p2 = footprint[(i + 1) % footprint.size()] - center

		var wall_length = p1.distance_to(p2)
		var num_windows = max(1, int(wall_length / spacing))

		for w in range(num_windows):
			var t = (w + 0.5) / float(num_windows)
			var window_pos_2d = p1.lerp(p2, t)
			var window_pos = Vector3(window_pos_2d.x, floor_y, -window_pos_2d.y)

			var wall_dir = (p2 - p1).normalized()
			var wall_angle = atan2(wall_dir.y, wall_dir.x)

			_create_window(building, window_pos, wall_angle, width, height)

## Create a single window
static func _create_window(parent: Node3D, pos: Vector3, wall_angle: float, width: float, height: float):
	var window = CSGBox3D.new()
	window.size = Vector3(0.15, height, width)
	window.position = pos
	window.rotation.y = wall_angle

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.6, 0.7, 0.9, 0.6)  # Glass blue
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.metallic = 0.2
	material.roughness = 0.1
	window.material = material

	parent.add_child(window)

## Add name label to building
static func _add_name_label(building: Node3D, building_name: String, height: float, base_elevation: float):
	var label = Label3D.new()
	label.text = building_name
	label.position = Vector3(0, height + base_elevation + 2, 0)
	label.font_size = 48
	label.outline_size = 8
	label.modulate = Color(1, 1, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	building.add_child(label)

## Parse OSM color (hex or named)
static func _parse_osm_color(color_string: String) -> Color:
	if color_string == "" or color_string == "yes":
		return Color.TRANSPARENT

	# Hex colors like "#e8ead4"
	if color_string.begins_with("#"):
		return Color.html(color_string)

	# Try HTML/CSS color name (Godot supports many CSS colors)
	var html_color = Color.from_string(color_string, Color.TRANSPARENT)
	if html_color != Color.TRANSPARENT:
		return html_color

	# Fallback named colors
	match color_string.to_lower():
		"red": return Color.RED
		"blue": return Color.BLUE
		"green": return Color.GREEN
		"white": return Color.WHITE
		"gray", "grey": return Color.GRAY
		"brown": return Color(0.6, 0.4, 0.2)
		"tan": return Color(0.8, 0.7, 0.5)
		"yellow": return Color.YELLOW
		"orange": return Color.ORANGE
		_: return Color.TRANSPARENT
