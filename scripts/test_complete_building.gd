extends Node3D

## Test Complete Building System
## Loads OSM data and renders ONE building with full detail
## to verify all the new systems work correctly

# Preload required scripts
const BuildingGeneratorMesh = preload("res://scripts/building_generator_mesh.gd")
const OSMDataComplete = preload("res://scripts/osm_data_complete.gd")

func _ready():
	print("🏗️  TESTING COMPLETE BUILDING SYSTEM")
	print("============================================================")

	# Load OSM data
	var osm_data = OSMDataComplete.new()
	var success = osm_data.load_osm_data("res://data/osm_complete.json")

	if not success:
		print("❌ Failed to load OSM data")
		return

	if osm_data.buildings.is_empty():
		print("❌ No buildings found in OSM data")
		return

	# Find an interesting building (one with a name and color if possible)
	var test_building = null
	for building in osm_data.buildings:
		if building.get("name", "") != "" and building.get("building:colour", "") != "":
			test_building = building
			break

	# If no colored named building, just use first named one
	if not test_building:
		for building in osm_data.buildings:
			if building.get("name", "") != "":
				test_building = building
				break

	# If still nothing, use first building
	if not test_building:
		test_building = osm_data.buildings[0]

	print("")
	print("📋 Test Building Selected:")
	print("   Name: ", test_building.get("name", "(unnamed)"))
	print("   Type: ", test_building.get("building_type"))
	print("   Levels: ", test_building.get("levels"))
	print("   Height: ", test_building.get("height"), "m")
	print("   Color: ", test_building.get("building:colour", "(default)"))
	print("   Material: ", test_building.get("building:material", "(default)"))
	print("   Roof Shape: ", test_building.get("roof:shape", "flat"))
	print("   Roof Color: ", test_building.get("roof:colour", "(default)"))
	print("")

	# Create the building
	print("🏗️  Generating building with new mesh-based generator...")
	var _building = BuildingGeneratorMesh.create_building(test_building, self, true)

	print("")
	print("📐 DEBUG - Positions:")
	print("   Building is at world origin: (0, 0, 0)")
	print("   Camera will be at: (30, ", test_building.get("height", 6.0), ", 30)")
	print("   Looking at: (0, ", test_building.get("height", 6.0) / 2, ", 0)")

	# Position camera to view the building
	_setup_camera(test_building)

	# Add ground plane at origin (where building is)
	_create_ground(Vector2.ZERO)

	# Add reference grid (at building location)
	_create_reference_grid(test_building)

	print("")
	print("✅ Test complete! Building rendered with full detail.")
	print("============================================================")

## Setup camera to view the building
func _setup_camera(building_data: Dictionary):
	var camera = Camera3D.new()
	var height = building_data.get("height", 6.0)

	# Add camera to tree first
	add_child(camera)

	# Building is at (0,0,0) since footprint is in local coords
	# Position camera to view building from good angle
	camera.position = Vector3(30, height, 30)
	camera.look_at(Vector3(0, height / 2, 0), Vector3.UP)

	# Add light
	var light = DirectionalLight3D.new()
	light.position = Vector3(0, 50, 0)
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.shadow_enabled = true
	light.light_energy = 1.5  # Brighter light
	add_child(light)

	# Add environment
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.7, 0.9)  # Light blue sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.8  # Much brighter ambient light
	var world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

## Create ground plane at building location
func _create_ground(center: Vector2):
	var ground = CSGBox3D.new()
	ground.size = Vector3(200, 1, 200)
	ground.position = Vector3(center.x, -0.5, center.y)

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.6, 0.3)
	ground.material = material

	add_child(ground)

## Create reference grid around building
func _create_reference_grid(building_data: Dictionary):
	var center = building_data.get("center", Vector2.ZERO)

	var grid_material = StandardMaterial3D.new()
	grid_material.albedo_color = Color(1, 1, 1, 0.3)
	grid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# 10m grid
	for x in range(-5, 6):
		var line = CSGBox3D.new()
		line.size = Vector3(0.1, 0.01, 100)
		line.position = Vector3(center.x + (x * 10), 0, center.y)
		line.material = grid_material
		add_child(line)

	for z in range(-5, 6):
		var line = CSGBox3D.new()
		line.size = Vector3(100, 0.01, 0.1)
		line.position = Vector3(center.x, 0, center.y + (z * 10))
		line.material = grid_material
		add_child(line)
