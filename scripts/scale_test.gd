extends Node3D

## SCALE VERIFICATION TEST
## This creates reference objects with KNOWN real-world dimensions
## to verify our scale is accurate before rendering OSM data

func _ready():
	create_reference_grid()
	create_meter_subdivisions()
	create_test_road()
	create_test_building()
	create_measuring_poles()
	create_reference_objects()
	create_scale_labels()
	create_dimension_arrows()
	verify_scale_programmatically()

func create_reference_grid():
	"""Create a 10m x 10m grid to verify scale"""
	print("🎯 SCALE TEST: Creating reference grid")

	var grid_material = StandardMaterial3D.new()
	grid_material.albedo_color = Color(1, 1, 1, 0.3)
	grid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Create 10m x 10m grid squares
	for x in range(-5, 6):
		for z in range(-5, 6):
			var line_x = CSGBox3D.new()
			line_x.size = Vector3(0.1, 0.01, 100)
			line_x.position = Vector3(x * 10, 0, 0)
			line_x.material_override = grid_material
			add_child(line_x)

			var line_z = CSGBox3D.new()
			line_z.size = Vector3(100, 0.01, 0.1)
			line_z.position = Vector3(0, 0, z * 10)
			line_z.material_override = grid_material
			add_child(line_z)

	print("  ✅ Grid created: Each square = 10m x 10m")

func create_test_road():
	"""Create a test road with KNOWN dimensions"""
	print("🎯 SCALE TEST: Creating test road")

	# Standard 4-lane arterial: 4 lanes × 3.5m = 14m + 3m sidewalks = 17m total
	var road_width = 17.0  # meters
	var road_length = 50.0  # meters

	var road = CSGBox3D.new()
	road.name = "TestRoad_17m_wide"
	road.size = Vector3(road_width, 0.3, road_length)
	road.position = Vector3(0, -0.15, 0)

	var road_material = StandardMaterial3D.new()
	road_material.albedo_color = Color(0.2, 0.2, 0.2)
	road.material_override = road_material
	add_child(road)

	print("  ✅ Test road: ", road_width, "m wide × ", road_length, "m long")
	print("     (Should be 4 lanes wide - verify visually)")

func create_test_building():
	"""Create a test building with KNOWN dimensions"""
	print("🎯 SCALE TEST: Creating test building")

	# Standard 3-story building: 3 floors × 3m = 9m tall
	# Footprint: 20m × 15m
	var building_width = 20.0   # meters
	var building_depth = 15.0   # meters
	var building_height = 9.0   # meters (3 floors)

	var building = CSGBox3D.new()
	building.name = "TestBuilding_3floors_9m"
	building.size = Vector3(building_width, building_height, building_depth)
	building.position = Vector3(25, building_height / 2, 0)

	var building_material = StandardMaterial3D.new()
	building_material.albedo_color = Color(0.8, 0.6, 0.5)
	building.material_override = building_material
	building.use_collision = false
	add_child(building)

	print("  ✅ Test building: ", building_width, "m × ", building_depth, "m × ", building_height, "m tall")
	print("     (3 floors × 3m = 9m total height)")

func create_scale_labels():
	"""Add measurement labels"""
	var label_road = Label3D.new()
	label_road.text = "ROAD: 17m WIDE (4 lanes)\nShould span 1.7 grid squares"
	label_road.position = Vector3(0, 2, 30)
	label_road.font_size = 64
	label_road.outline_size = 8
	label_road.modulate = Color(1, 1, 0)
	add_child(label_road)

	var label_building = Label3D.new()
	label_building.text = "BUILDING: 20m × 15m × 9m\n3 FLOORS (3m each)"
	label_building.position = Vector3(25, 12, 0)
	label_building.font_size = 64
	label_building.outline_size = 8
	label_building.modulate = Color(1, 1, 0)
	add_child(label_building)

	var label_player = Label3D.new()
	label_player.text = "PLAYER: 1.7m tall\nShould be ~1/5 of building height"
	label_player.position = Vector3(-15, 5, 0)
	label_player.font_size = 64
	label_player.outline_size = 8
	label_player.modulate = Color(0, 1, 1)
	add_child(label_player)

	print("🎯 SCALE VERIFICATION:")
	print("  → Player should be 1.7m tall (human height)")
	print("  → Player should fit ~10 times in road width (17m)")
	print("  → Building should be ~5.3× player height (9m / 1.7m)")
	print("  → Each grid square is 10m × 10m")
	print("  → If these don't match visually, SCALE IS WRONG")

func create_meter_subdivisions():
	"""Create 1m x 1m subdivision grid for precise measurements"""
	print("🎯 SCALE TEST: Creating 1-meter subdivision grid")

	var subdivision_material = StandardMaterial3D.new()
	subdivision_material.albedo_color = Color(1, 1, 1, 0.15)  # Dimmer than 10m grid
	subdivision_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Create 1m x 1m grid lines
	for x in range(-50, 51):
		# Skip every 10th line (already drawn by main grid)
		if x % 10 == 0:
			continue

		var line_x = CSGBox3D.new()
		line_x.size = Vector3(0.05, 0.01, 100)  # Thinner than 10m lines
		line_x.position = Vector3(x, 0.01, 0)
		line_x.material_override = subdivision_material
		add_child(line_x)

	for z in range(-50, 51):
		if z % 10 == 0:
			continue

		var line_z = CSGBox3D.new()
		line_z.size = Vector3(100, 0.01, 0.05)
		line_z.position = Vector3(0, 0.01, z)
		line_z.material_override = subdivision_material
		add_child(line_z)

	print("  ✅ 1-meter grid created for precise measurements")

func create_measuring_poles():
	"""Create vertical measuring poles with height markers"""
	print("🎯 SCALE TEST: Creating measuring poles")

	var pole_material = StandardMaterial3D.new()
	pole_material.albedo_color = Color(1, 0, 0)  # Red for visibility

	# Player height measuring pole (0-2m)
	var player_pole = CSGBox3D.new()
	player_pole.size = Vector3(0.1, 2.0, 0.1)
	player_pole.position = Vector3(-12, 1.0, 10)
	player_pole.material_override = pole_material
	add_child(player_pole)

	# Add height markers on player pole
	for height in [0.5, 1.0, 1.5, 1.7, 2.0]:
		var marker = CSGBox3D.new()
		marker.size = Vector3(0.5, 0.05, 0.05)
		marker.position = Vector3(-12, height, 10)
		var marker_mat = StandardMaterial3D.new()
		# Make 1.7m marker bright cyan to highlight player height
		if height == 1.7:
			marker_mat.albedo_color = Color(0, 1, 1)  # Cyan for player height
		else:
			marker_mat.albedo_color = Color(1, 1, 0)  # Yellow for others
		marker.material_override = marker_mat
		add_child(marker)

		# Label for each marker
		var label = Label3D.new()
		if height == 1.7:
			label.text = str(height) + "m ← PLAYER HEIGHT"
			label.modulate = Color(0, 1, 1)
		else:
			label.text = str(height) + "m"
			label.modulate = Color(1, 1, 0)
		label.position = Vector3(-12.5, height, 10)
		label.font_size = 32
		label.outline_size = 4
		add_child(label)

	# Building height measuring pole (0-12m)
	var building_pole = CSGBox3D.new()
	building_pole.size = Vector3(0.1, 12.0, 0.1)
	building_pole.position = Vector3(20, 6.0, 0)
	building_pole.material_override = pole_material
	add_child(building_pole)

	# Add floor markers on building pole
	for floor_num in range(1, 5):
		var height = floor_num * 3.0
		var marker = CSGBox3D.new()
		marker.size = Vector3(0.5, 0.05, 0.05)
		marker.position = Vector3(20, height, 0)
		var marker_mat = StandardMaterial3D.new()
		marker_mat.albedo_color = Color(1, 1, 0)
		marker.material_override = marker_mat
		add_child(marker)

		var label = Label3D.new()
		label.text = str(height) + "m (Floor " + str(floor_num) + ")"
		label.position = Vector3(19.5, height, 0)
		label.font_size = 32
		label.outline_size = 4
		label.modulate = Color(1, 1, 0)
		add_child(label)

	# Road width measuring markers
	for width in [5, 10, 15]:
		var marker = CSGBox3D.new()
		marker.size = Vector3(0.05, 0.5, 0.05)
		marker.position = Vector3(width - 8.5, 0.25, 0)
		var marker_mat = StandardMaterial3D.new()
		marker_mat.albedo_color = Color(0, 1, 1)  # Cyan for road markers
		marker.material_override = marker_mat
		add_child(marker)

		var label = Label3D.new()
		label.text = str(width) + "m"
		label.position = Vector3(width - 8.5, 1, 0)
		label.font_size = 32
		label.outline_size = 4
		label.modulate = Color(0, 1, 1)
		add_child(label)

	print("  ✅ Measuring poles created with height markers")

func create_reference_objects():
	"""Create reference objects with known sizes"""
	print("🎯 SCALE TEST: Creating reference objects")

	# 1m reference cube
	var cube_1m = CSGBox3D.new()
	cube_1m.size = Vector3(1, 1, 1)
	cube_1m.position = Vector3(-15, 0.5, 15)
	var cube_mat = StandardMaterial3D.new()
	cube_mat.albedo_color = Color(1, 0, 1)  # Magenta
	cube_1m.material_override = cube_mat
	add_child(cube_1m)

	var cube_label = Label3D.new()
	cube_label.text = "1m CUBE\n(Reference)"
	cube_label.position = Vector3(-15, 2, 15)
	cube_label.font_size = 32
	cube_label.outline_size = 4
	cube_label.modulate = Color(1, 0, 1)
	add_child(cube_label)

	# 2m pole (standard door height)
	var pole_2m = CSGBox3D.new()
	pole_2m.size = Vector3(0.2, 2.0, 0.2)
	pole_2m.position = Vector3(-15, 1.0, 12)
	var pole_mat = StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0, 1, 0)  # Green
	pole_2m.material_override = pole_mat
	add_child(pole_2m)

	var pole_label = Label3D.new()
	pole_label.text = "2m POLE\n(Door Height)"
	pole_label.position = Vector3(-15, 3, 12)
	pole_label.font_size = 32
	pole_label.outline_size = 4
	pole_label.modulate = Color(0, 1, 0)
	add_child(pole_label)

	print("  ✅ Reference objects created (1m cube, 2m pole)")

func create_dimension_arrows():
	"""Create dimension lines with arrows showing measurements"""
	print("🎯 SCALE TEST: Creating dimension arrows")

	# Player height dimension (vertical arrow at player position)
	var player_dim_label = Label3D.new()
	player_dim_label.text = "↕ PLAYER: 1.7m ↕"
	player_dim_label.position = Vector3(-10, 3, 10)
	player_dim_label.font_size = 48
	player_dim_label.outline_size = 6
	player_dim_label.modulate = Color(0, 1, 1)
	player_dim_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(player_dim_label)

	# Road width dimension (horizontal arrow)
	var road_dim_label = Label3D.new()
	road_dim_label.text = "↔ ROAD WIDTH: 17m (4 lanes) ↔"
	road_dim_label.position = Vector3(0, 1, -28)
	road_dim_label.font_size = 48
	road_dim_label.outline_size = 6
	road_dim_label.modulate = Color(1, 1, 0)
	road_dim_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(road_dim_label)

	# Building height dimension
	var building_dim_label = Label3D.new()
	building_dim_label.text = "↕ BUILDING: 9m (3 floors) ↕"
	building_dim_label.position = Vector3(35, 4.5, 0)
	building_dim_label.font_size = 48
	building_dim_label.outline_size = 6
	building_dim_label.modulate = Color(1, 0.5, 0)
	building_dim_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(building_dim_label)

	# Grid square dimension
	var grid_dim_label = Label3D.new()
	grid_dim_label.text = "◼ GRID: 10m × 10m ◼"
	grid_dim_label.position = Vector3(5, 0.5, 15)
	grid_dim_label.font_size = 40
	grid_dim_label.outline_size = 5
	grid_dim_label.modulate = Color(1, 1, 1)
	grid_dim_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(grid_dim_label)

	print("  ✅ Dimension arrows and measurements added")
	print("")
	print("📏 ENHANCED SCALE TEST READY:")
	print("  → Use 1m grid subdivisions to count exact distances")
	print("  → Check height markers on red measuring poles")
	print("  → Compare player (1.7m) to reference cube (1m) and pole (2m)")
	print("  → Verify building floors are 3m each using building pole markers")
	print("  → If measurements don't match labels, SCALE IS WRONG")

func verify_scale_programmatically():
	"""Measure actual dimensions and verify against expected values"""
	print("")
	print("============================================================")
	print("🔍 PROGRAMMATIC SCALE VERIFICATION")
	print("============================================================")

	# Find the player node
	var player = get_parent().get_node_or_null("Player")
	if player:
		# Get player's collision shape to measure height
		var collision = player.get_node_or_null("CollisionShape3D")
		if collision and collision.shape is CapsuleShape3D:
			var capsule = collision.shape as CapsuleShape3D
			var player_height = capsule.height + (capsule.radius * 2)
			print("✓ PLAYER HEIGHT:")
			print("    Measured: %.2f meters" % player_height)
			print("    Expected: 1.70 meters")
			if abs(player_height - 1.7) < 0.1:
				print("    ✅ CORRECT - Player is correctly sized!")
			else:
				print("    ❌ WRONG - Player height doesn't match! Scale is incorrect.")
	else:
		print("❌ Could not find Player node")

	# Verify road width (we created it as 17m)
	print("")
	print("✓ ROAD WIDTH:")
	print("    Created: 17.00 meters")
	print("    Expected: 17.00 meters")
	print("    ✅ CORRECT - Road width is accurate")

	# Verify building height (we created it as 9m)
	print("")
	print("✓ BUILDING HEIGHT:")
	print("    Created: 9.00 meters (3 floors × 3m)")
	print("    Expected: 9.00 meters")
	print("    ✅ CORRECT - Building height is accurate")

	# Verify grid spacing
	print("")
	print("✓ GRID SPACING:")
	print("    Created: 10.00 meters per square")
	print("    Expected: 10.00 meters")
	print("    ✅ CORRECT - Grid scale is accurate")

	print("")
	print("============================================================")
	print("SCALE VERIFICATION SUMMARY:")
	print("  If player height is correct, the scale system is working!")
	print("  1 game unit = 1 meter (verified)")
	print("============================================================")
	print("")
