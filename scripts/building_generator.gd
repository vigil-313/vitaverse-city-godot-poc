extends Node
class_name BuildingGenerator

# Generate a building from a template and OSM data
static func generate_building(template: BuildingTemplate, osm_data: Dictionary) -> Node3D:
	var building = Node3D.new()
	var building_name = osm_data.get("name", "")
	if building_name.is_empty():
		building_name = "Building_" + str(osm_data.get("id", randi()))
	building.name = building_name

	# Extract dimensions from OSM
	var footprint = osm_data.get("footprint", [])  # Array of Vector2 points
	var height = osm_data.get("height", template.floor_height * template.default_floors)
	var floors = osm_data.get("levels", template.default_floors)

	# Calculate building dimensions from footprint
	var bounds = _calculate_bounds(footprint)
	var width = bounds.size.x if bounds.size.x > 0 else template.default_width
	var depth = bounds.size.y if bounds.size.y > 0 else template.default_depth

	# Generate building structure
	var exterior = _create_exterior(template, width, depth, height)
	building.add_child(exterior)

	# Add windows
	var windows = _create_windows(template, width, depth, height, floors)
	building.add_child(windows)

	# Add roof
	var roof = _create_roof(template, width, depth, height)
	building.add_child(roof)

	# Add entrance
	var entrance = _create_entrance(template, width, depth)
	building.add_child(entrance)

	# Add decorative elements
	if template.has_chimney:
		var chimney = _create_chimney(template, width, depth, height)
		building.add_child(chimney)

	if template.has_balcony:
		var balconies = _create_balconies(template, width, depth, height, floors)
		building.add_child(balconies)

	# Add props
	if template.outdoor_seating:
		var seating = _create_outdoor_seating(template, width, depth)
		building.add_child(seating)

	return building

static func _calculate_bounds(footprint: Array) -> Rect2:
	if footprint.is_empty():
		return Rect2(0, 0, 10, 8)

	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF

	for point in footprint:
		min_x = min(min_x, point.x)
		max_x = max(max_x, point.x)
		min_y = min(min_y, point.y)
		max_y = max(max_y, point.y)

	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)

static func _create_exterior(template: BuildingTemplate, width: float, depth: float, height: float) -> Node3D:
	var exterior = Node3D.new()
	exterior.name = "Exterior"

	# Create walls with proper thickness
	var material = _create_wall_material(template)
	var wall_thickness = 0.5

	# Back wall
	var back_wall = CSGBox3D.new()
	back_wall.name = "BackWall"
	back_wall.transform.origin = Vector3(0, height / 2, -depth / 2)
	back_wall.size = Vector3(width, height, wall_thickness)
	back_wall.material_override = material
	back_wall.use_collision = true
	exterior.add_child(back_wall)

	# Front wall (split for door with proper gap)
	var door_width = 2.5
	var front_left = CSGBox3D.new()
	front_left.name = "FrontWallLeft"
	front_left.transform.origin = Vector3(-width / 2 + (width / 2 - door_width / 2) / 2, height / 2, depth / 2)
	front_left.size = Vector3(width / 2 - door_width / 2, height, wall_thickness)
	front_left.material_override = material
	front_left.use_collision = true
	exterior.add_child(front_left)

	var front_right = CSGBox3D.new()
	front_right.name = "FrontWallRight"
	front_right.transform.origin = Vector3(width / 2 - (width / 2 - door_width / 2) / 2, height / 2, depth / 2)
	front_right.size = Vector3(width / 2 - door_width / 2, height, wall_thickness)
	front_right.material_override = material
	front_right.use_collision = true
	exterior.add_child(front_right)

	# Left wall
	var left_wall = CSGBox3D.new()
	left_wall.name = "LeftWall"
	left_wall.transform.origin = Vector3(-width / 2, height / 2, 0)
	left_wall.size = Vector3(wall_thickness, height, depth)
	left_wall.material_override = material
	left_wall.use_collision = true
	exterior.add_child(left_wall)

	# Right wall
	var right_wall = CSGBox3D.new()
	right_wall.name = "RightWall"
	right_wall.transform.origin = Vector3(width / 2, height / 2, 0)
	right_wall.size = Vector3(wall_thickness, height, depth)
	right_wall.material_override = material
	right_wall.use_collision = true
	exterior.add_child(right_wall)

	# Floor
	var floor_mesh = CSGBox3D.new()
	floor_mesh.name = "Floor"
	floor_mesh.transform.origin = Vector3(0, 0.1, 0)
	floor_mesh.size = Vector3(width, 0.2, depth)
	floor_mesh.material_override = material
	floor_mesh.use_collision = true
	exterior.add_child(floor_mesh)

	# Add base trim
	var trim_material = StandardMaterial3D.new()
	trim_material.albedo_color = Color(0.2, 0.2, 0.2)
	trim_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	var base_trim = CSGBox3D.new()
	base_trim.name = "BaseTrim"
	base_trim.transform.origin = Vector3(0, 0.3, 0)
	base_trim.size = Vector3(width + 0.2, 0.6, depth + 0.2)
	base_trim.material_override = trim_material
	base_trim.use_collision = false
	exterior.add_child(base_trim)

	return exterior

static func _create_wall_material(template: BuildingTemplate) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()

	# Use TextureGenerator for brick texture
	if template.wall_material_type == "brick":
		material.albedo_texture = TextureGenerator.create_brick_texture()
	elif template.wall_material_type == "wood":
		material.albedo_texture = TextureGenerator.create_wood_texture()
	else:
		material.albedo_color = template.wall_color

	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 0.8
	return material

static func _create_windows(template: BuildingTemplate, width: float, depth: float, _height: float, floors: int) -> Node3D:
	var windows_node = Node3D.new()
	windows_node.name = "Windows"

	if template.window_style == "none":
		return windows_node

	var window_material = StandardMaterial3D.new()
	window_material.albedo_color = Color(0.3, 0.5, 0.7, 0.8)
	window_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	window_material.roughness = 0.1
	window_material.metallic = 0.3

	var frame_material = StandardMaterial3D.new()
	frame_material.albedo_color = Color(0.9, 0.9, 0.9)
	frame_material.roughness = 0.6

	# Calculate window spacing (approximately 1 window per 3-4 meters)
	var window_spacing = 3.5

	# Place windows on all walls
	for floor_num in range(floors):
		var floor_y = 1.5 + floor_num * template.floor_height

		# Ground floor storefront for retail/commercial
		if floor_num == 0 and template.has_storefront:
			_create_storefront(windows_node, width, depth, window_material, frame_material)
		else:
			# Left wall windows
			var num_left_windows = max(2, int(depth / window_spacing))
			for i in range(num_left_windows):
				var z_pos = -depth / 2 + (i + 1) * (depth / (num_left_windows + 1))
				_create_window_with_frame(windows_node, Vector3(-width / 2 - 0.15, floor_y, z_pos),
					Vector3(0, 90, 0), window_material, frame_material, str(floor_num) + "_L" + str(i))

			# Right wall windows
			var num_right_windows = max(2, int(depth / window_spacing))
			for i in range(num_right_windows):
				var z_pos = -depth / 2 + (i + 1) * (depth / (num_right_windows + 1))
				_create_window_with_frame(windows_node, Vector3(width / 2 + 0.15, floor_y, z_pos),
					Vector3(0, -90, 0), window_material, frame_material, str(floor_num) + "_R" + str(i))

			# Front wall windows
			var num_front_windows = max(2, int(width / window_spacing))
			for i in range(num_front_windows):
				var x_pos = -width / 2 + (i + 1) * (width / (num_front_windows + 1))
				_create_window_with_frame(windows_node, Vector3(x_pos, floor_y, depth / 2 + 0.15),
					Vector3(0, 0, 0), window_material, frame_material, str(floor_num) + "_F" + str(i))

			# Back wall windows
			var num_back_windows = max(2, int(width / window_spacing))
			for i in range(num_back_windows):
				var x_pos = -width / 2 + (i + 1) * (width / (num_back_windows + 1))
				_create_window_with_frame(windows_node, Vector3(x_pos, floor_y, -depth / 2 - 0.15),
					Vector3(0, 180, 0), window_material, frame_material, str(floor_num) + "_B" + str(i))

	return windows_node

static func _create_storefront(parent: Node3D, width: float, depth: float, window_mat: Material, frame_mat: Material):
	"""Create ground floor storefront with large windows"""
	var storefront_height = 2.5
	var storefront_y = 1.25

	# Large front windows (spanning most of front wall)
	var num_panels = max(2, int(width / 4))
	for i in range(num_panels):
		var x_pos = -width / 2 + (i + 0.5) * (width / num_panels)

		# Glass panel
		var window = CSGBox3D.new()
		window.name = "Storefront_" + str(i)
		window.transform.origin = Vector3(x_pos, storefront_y, depth / 2 + 0.15)
		window.size = Vector3((width / num_panels) - 0.3, storefront_height, 0.2)
		window.material_override = window_mat
		parent.add_child(window)

		# Frame
		var frame = CSGBox3D.new()
		frame.transform.origin = Vector3(x_pos, storefront_y, depth / 2 + 0.2)
		frame.size = Vector3((width / num_panels) - 0.2, storefront_height + 0.1, 0.15)
		frame.material_override = frame_mat
		parent.add_child(frame)

static func _create_window_with_frame(parent: Node3D, pos: Vector3, wall_rotation: Vector3, window_mat: Material, frame_mat: Material, id: String):
	"""Create a window with visible frame - orientation depends on wall"""
	var window = CSGBox3D.new()
	window.name = "Window_" + id
	window.transform.origin = pos

	# Determine window orientation based on wall rotation
	# Left/Right walls (90 or -90 degrees): thin in Z, wide in X
	# Front/Back walls (0 or 180 degrees): thin in X, wide in Z
	var is_side_wall = abs(wall_rotation.y) > 45 and abs(wall_rotation.y) < 135

	if is_side_wall:
		# Left/Right wall - window faces X direction, thin in Z
		window.size = Vector3(1.6, 2.0, 0.01)
	else:
		# Front/Back wall - window faces Z direction, thin in X
		window.size = Vector3(0.01, 2.0, 1.6)

	window.material_override = window_mat
	parent.add_child(window)

	# Frame dimensions also depend on orientation
	if is_side_wall:
		# Side wall frames
		var frame_top = CSGBox3D.new()
		frame_top.transform.origin = pos + Vector3(0, 1.1, 0)
		frame_top.size = Vector3(1.7, 0.2, 0.05)
		frame_top.material_override = frame_mat
		parent.add_child(frame_top)

		var frame_bottom = CSGBox3D.new()
		frame_bottom.transform.origin = pos + Vector3(0, -1.1, 0)
		frame_bottom.size = Vector3(1.7, 0.2, 0.05)
		frame_bottom.material_override = frame_mat
		parent.add_child(frame_bottom)

		var frame_left = CSGBox3D.new()
		frame_left.transform.origin = pos + Vector3(-0.85, 0, 0)
		frame_left.size = Vector3(0.1, 2.2, 0.05)
		frame_left.material_override = frame_mat
		parent.add_child(frame_left)

		var frame_right = CSGBox3D.new()
		frame_right.transform.origin = pos + Vector3(0.85, 0, 0)
		frame_right.size = Vector3(0.1, 2.2, 0.05)
		frame_right.material_override = frame_mat
		parent.add_child(frame_right)
	else:
		# Front/Back wall frames
		var frame_top = CSGBox3D.new()
		frame_top.transform.origin = pos + Vector3(0, 1.1, 0)
		frame_top.size = Vector3(0.05, 0.2, 1.7)
		frame_top.material_override = frame_mat
		parent.add_child(frame_top)

		var frame_bottom = CSGBox3D.new()
		frame_bottom.transform.origin = pos + Vector3(0, -1.1, 0)
		frame_bottom.size = Vector3(0.05, 0.2, 1.7)
		frame_bottom.material_override = frame_mat
		parent.add_child(frame_bottom)

		var frame_left = CSGBox3D.new()
		frame_left.transform.origin = pos + Vector3(0, 0, -0.85)
		frame_left.size = Vector3(0.05, 2.2, 0.1)
		frame_left.material_override = frame_mat
		parent.add_child(frame_left)

		var frame_right = CSGBox3D.new()
		frame_right.transform.origin = pos + Vector3(0, 0, 0.85)
		frame_right.size = Vector3(0.05, 2.2, 0.1)
		frame_right.material_override = frame_mat
		parent.add_child(frame_right)

static func _create_roof(template: BuildingTemplate, width: float, depth: float, height: float) -> Node3D:
	var roof_node = Node3D.new()
	roof_node.name = "Roof"

	var roof_material = StandardMaterial3D.new()
	roof_material.albedo_color = template.roof_color
	roof_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	roof_material.roughness = 0.9

	# Add cornice (decorative trim at roofline)
	var cornice_material = StandardMaterial3D.new()
	cornice_material.albedo_color = Color(0.85, 0.85, 0.85)
	cornice_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	var cornice = CSGBox3D.new()
	cornice.name = "Cornice"
	cornice.transform.origin = Vector3(0, height + 0.15, 0)
	cornice.size = Vector3(width + 0.4, 0.3, depth + 0.4)
	cornice.material_override = cornice_material
	cornice.use_collision = false
	roof_node.add_child(cornice)

	if template.roof_type == "flat":
		var roof = CSGBox3D.new()
		roof.transform.origin = Vector3(0, height + 0.35, 0)
		roof.size = Vector3(width + 0.6, 0.4, depth + 0.6)
		roof.material_override = roof_material
		roof.use_collision = false
		roof_node.add_child(roof)
	elif template.roof_type == "peaked":
		# Simple peaked roof
		var roof = CSGBox3D.new()
		roof.transform.origin = Vector3(0, height + 1.2, 0)
		roof.rotation.z = deg_to_rad(10)  # Slight angle for peaked roof
		roof.size = Vector3(width + 1, 0.4, depth + 1)
		roof.material_override = roof_material
		roof.use_collision = false
		roof_node.add_child(roof)

	return roof_node

static func _create_entrance(_template: BuildingTemplate, _width: float, depth: float) -> Node3D:
	var entrance = Node3D.new()
	entrance.name = "Entrance"

	# Create door centered on front wall
	var door_script = load("res://scripts/door.gd")
	var door = StaticBody3D.new()
	door.name = "Door"
	door.transform.origin = Vector3(-1.25, 1.5, depth / 2)
	door.set_script(door_script)

	var door_mesh = CSGBox3D.new()
	door_mesh.name = "DoorMesh"
	door_mesh.transform.origin = Vector3(1.25, 0, 0)
	door_mesh.size = Vector3(2.5, 3, 0.25)

	var door_material = StandardMaterial3D.new()
	door_material.albedo_texture = TextureGenerator.create_wood_texture()
	door_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	door_mesh.material_override = door_material

	door.add_child(door_mesh)

	# Door handle
	var handle_material = StandardMaterial3D.new()
	handle_material.albedo_color = Color(0.3, 0.3, 0.3)
	handle_material.metallic = 0.7

	var door_handle = CSGBox3D.new()
	door_handle.name = "DoorHandle"
	door_handle.transform.origin = Vector3(2.0, 0, 0.15)
	door_handle.size = Vector3(0.15, 0.3, 0.15)
	door_handle.material_override = handle_material
	door_mesh.add_child(door_handle)

	entrance.add_child(door)

	return entrance

static func _create_chimney(_template: BuildingTemplate, width: float, depth: float, height: float) -> Node3D:
	var chimney = Node3D.new()
	chimney.name = "Chimney"

	var chimney_material = StandardMaterial3D.new()
	chimney_material.albedo_texture = TextureGenerator.create_brick_texture()
	chimney_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	var base = CSGBox3D.new()
	base.transform.origin = Vector3(-width / 3, height + 1.5, -depth / 3)
	base.size = Vector3(1.2, 3, 1.2)
	base.material_override = chimney_material
	chimney.add_child(base)

	return chimney

static func _create_balconies(_template: BuildingTemplate, _width: float, _depth: float, _height: float, _floors: int) -> Node3D:
	var balconies = Node3D.new()
	balconies.name = "Balconies"
	# TODO: Add balcony generation
	return balconies

static func _create_outdoor_seating(_template: BuildingTemplate, _width: float, _depth: float) -> Node3D:
	var seating = Node3D.new()
	seating.name = "OutdoorSeating"
	# TODO: Add outdoor seating generation
	return seating
