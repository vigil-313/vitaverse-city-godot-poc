extends Node3D

## City Renderer - Main Coordinator
##
## Coordinates the city rendering system using modular components:
##   - ChunkManager: Handles chunk streaming
##   - CameraController: Manages camera movement and input
##   - DebugUI: Provides HUD and debug visualization
##   - FeatureFactory: Creates city features (buildings, roads, parks, water)
##
## This is a thin coordinator that connects components via dependency injection
## and signal-based communication.

# ========================================================================
# PRELOADED DEPENDENCIES
# ========================================================================

# Data layer
const OSMDataComplete = preload("res://scripts/data/osm_data_complete.gd")

# Generator layer
const BuildingGeneratorMesh = preload("res://scripts/generators/building_generator_mesh.gd")
const RoadGenerator = preload("res://scripts/generators/road_generator.gd")
const ParkGenerator = preload("res://scripts/generators/park_generator.gd")
const WaterGenerator = preload("res://scripts/generators/water_generator.gd")
const FeatureFactory = preload("res://scripts/generators/feature_factory.gd")

# City layer
const ChunkManager = preload("res://scripts/city/chunk_manager.gd")
const CameraController = preload("res://scripts/city/camera_controller.gd")
const DebugUI = preload("res://scripts/city/debug_ui.gd")

# ========================================================================
# COMPONENTS (Dependency Injection)
# ========================================================================

var chunk_manager: ChunkManager
var camera_controller: CameraController
var debug_ui: DebugUI
var feature_factory: FeatureFactory

# ========================================================================
# LIFECYCLE
# ========================================================================

func _ready():
	print("🌆 CITY RENDERER - South Lake Union")
	print("============================================================")

	# Load OSM data
	var osm_data = OSMDataComplete.new()
	var success = osm_data.load_osm_data("res://data/osm_complete.json")

	if not success:
		print("❌ Failed to load OSM data")
		return

	print("")
	print("📊 Loaded Data:")
	print("   🏢 Buildings: ", osm_data.buildings.size())
	print("   🛣️  Roads: ", osm_data.roads.size())
	print("   🌳 Parks: ", osm_data.parks.size())
	print("   💧 Water: ", osm_data.water.size())
	print("")

	# Initialize components
	_initialize_components(osm_data)

	# Setup environment
	_setup_environment()

	print("")
	print("✅ City rendering complete (chunked streaming enabled)!")
	print("============================================================")
	print("")
	print("🎮 CONTROLS:")
	print("   Right-Click + Drag: Look around")
	print("   WASD: Move camera")
	print("   Q/E: Move up/down")
	print("   Shift: Fast movement (100m/s)")
	print("   Scroll Wheel: Adjust speed")
	print("   ESC: Release mouse")
	print("   F3: Toggle debug panel (chunk settings & speed control)")
	print("   F4: Toggle chunk visualization")

func _process(delta: float):
	# Update camera
	if camera_controller:
		camera_controller.update(delta)

	# Update chunk streaming
	if chunk_manager and camera_controller and camera_controller.camera:
		chunk_manager.update(delta, camera_controller.camera.global_position)

	# Update HUD
	if debug_ui and camera_controller and camera_controller.camera:
		var heading_info = camera_controller.get_heading_info()
		var current_speed = camera_controller.get_current_speed()
		var chunk_stats = chunk_manager.get_stats() if chunk_manager else {}

		debug_ui.update_hud(
			camera_controller.camera.global_position,
			heading_info,
			current_speed,
			chunk_stats
		)

func _input(event: InputEvent):
	# Route input to components
	if camera_controller:
		camera_controller.handle_input(event)

	if debug_ui:
		debug_ui.handle_input(event)

# ========================================================================
# COMPONENT INITIALIZATION
# ========================================================================

func _initialize_components(osm_data: OSMDataComplete):
	print("🔧 Initializing components...")
	print("")

	# 1. Create FeatureFactory
	feature_factory = FeatureFactory.new()

	# 2. Create ChunkManager with factory
	chunk_manager = ChunkManager.new(feature_factory, self)
	chunk_manager.chunk_size = 500.0
	chunk_manager.chunk_load_radius = 1000.0
	chunk_manager.chunk_unload_radius = 1500.0
	chunk_manager.chunk_update_interval = 1.0
	chunk_manager.max_chunks_per_frame = 2

	# Organize data into chunks
	chunk_manager.organize_data(osm_data)

	# 3. Create CameraController
	camera_controller = CameraController.new()
	add_child(camera_controller)

	var start_position = Vector3(-300, 100, -2000)  # South Lake Union
	camera_controller.setup_camera(self, start_position)

	# Connect camera signals
	camera_controller.camera_moved.connect(_on_camera_moved)

	# 4. Create DebugUI
	debug_ui = DebugUI.new()
	add_child(debug_ui)
	debug_ui.setup(self, chunk_manager)

	# Connect debug UI signals
	debug_ui.settings_apply_requested.connect(_on_debug_settings_apply)
	debug_ui.settings_reset_requested.connect(_on_debug_settings_reset)
	debug_ui.chunk_viz_toggled.connect(_on_chunk_viz_toggled)
	camera_controller.camera_speed_changed.connect(debug_ui.update_speeds_display)

	# Connect chunk manager signals to debug UI
	chunk_manager.chunks_updated.connect(func(_a, _b, _c): debug_ui.update_chunk_visualization())

	# 5. Load initial chunks
	var camera_start_pos = Vector2(start_position.x, -start_position.z)
	chunk_manager.load_initial_chunks(camera_start_pos)

	print("   ✅ Components initialized")

# ========================================================================
# SIGNAL HANDLERS
# ========================================================================

func _on_camera_moved(position: Vector3):
	# Camera moved - chunk streaming will update automatically in _process
	pass

func _on_debug_settings_apply(load_radius: float, unload_radius: float, speed_multiplier: float):
	# Validate settings
	var errors = []
	if load_radius < 100 or load_radius > 5000:
		errors.append("Load radius must be 100-5000m")
	if unload_radius < 200 or unload_radius > 6000:
		errors.append("Unload radius must be 200-6000m")
	if unload_radius <= load_radius:
		errors.append("Unload radius must be > load radius")
	if speed_multiplier < 0.1 or speed_multiplier > 10.0:
		errors.append("Speed multiplier must be 0.1-10.0x")

	if errors.size() > 0:
		debug_ui.show_status("ERROR: " + errors[0], true)
		print("❌ Invalid settings: ", errors)
		return

	# Apply chunk settings
	var old_load = chunk_manager.chunk_load_radius
	var old_unload = chunk_manager.chunk_unload_radius

	chunk_manager.chunk_load_radius = load_radius
	chunk_manager.chunk_unload_radius = unload_radius

	# Apply camera speed
	camera_controller.set_speeds(speed_multiplier)

	debug_ui.show_status("✓ Applied! Check console for details", false)

	print("========================================")
	print("🔧 SETTINGS CHANGED:")
	print("   Load: ", int(old_load), "m → ", int(load_radius), "m")
	print("   Unload: ", int(old_unload), "m → ", int(unload_radius), "m")
	print("   Speed: ", speed_multiplier, "x")
	print("   Active chunks BEFORE: ", chunk_manager.active_chunks.size())
	print("========================================")

	# Force immediate chunk update
	var camera_pos_2d = Vector2(camera_controller.camera.global_position.x, -camera_controller.camera.global_position.z)

	# Unload chunks beyond new radius
	var chunks_to_unload = []
	for chunk_key in chunk_manager.active_chunks.keys():
		var chunk_center = Vector2(
			chunk_key.x * chunk_manager.chunk_size + chunk_manager.chunk_size/2,
			chunk_key.y * chunk_manager.chunk_size + chunk_manager.chunk_size/2
		)
		var distance = camera_pos_2d.distance_to(chunk_center)
		if distance > chunk_manager.chunk_unload_radius:
			chunks_to_unload.append(chunk_key)

	for chunk_key in chunks_to_unload:
		chunk_manager.unload_chunk(chunk_key)

	# Load chunks within new radius
	var chunks_to_load = chunk_manager.get_chunks_in_radius(camera_pos_2d, chunk_manager.chunk_load_radius)
	for chunk_key in chunks_to_load:
		if not chunk_manager.active_chunks.has(chunk_key):
			chunk_manager.load_chunk(chunk_key)

	# Load distant water at 2x radius
	chunk_manager._load_distant_water(camera_pos_2d, chunk_manager.chunk_load_radius * 2.0)

	print("   Active chunks AFTER: ", chunk_manager.active_chunks.size())
	print("========================================")

func _on_debug_settings_reset():
	# Reset to defaults
	chunk_manager.chunk_load_radius = 1000.0
	chunk_manager.chunk_unload_radius = 1500.0
	camera_controller.set_speeds(1.0)

	# Update UI
	var load_input = debug_ui.debug_panel.find_child("LoadInput", true, false) as LineEdit
	var unload_input = debug_ui.debug_panel.find_child("UnloadInput", true, false) as LineEdit
	var speed_input = debug_ui.debug_panel.find_child("SpeedInput", true, false) as LineEdit

	if load_input:
		load_input.text = "1000"
	if unload_input:
		unload_input.text = "1500"
	if speed_input:
		speed_input.text = "1.0"

	debug_ui.show_status("✓ Reset to defaults", false)

func _on_chunk_viz_toggled(enabled: bool):
	# Chunk visualization toggled - DebugUI handles the visualization
	pass

# ========================================================================
# ENVIRONMENT SETUP
# ========================================================================

func _setup_environment():
	# Directional light (sun)
	var light = DirectionalLight3D.new()
	light.position = Vector3(0, 100, 0)
	light.rotation_degrees = Vector3(-50, -30, 0)
	light.shadow_enabled = true
	light.light_energy = 1.3
	light.light_color = Color(1.0, 0.98, 0.95)

	# High-quality shadows
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	light.directional_shadow_split_1 = 0.05
	light.directional_shadow_split_2 = 0.15
	light.directional_shadow_split_3 = 0.35
	light.directional_shadow_max_distance = 500.0
	light.shadow_bias = 0.02
	light.shadow_normal_bias = 1.0

	add_child(light)

	# Environment
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY

	# Sky
	var sky = Sky.new()
	var sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.4, 0.6, 0.9)
	sky_material.sky_horizon_color = Color(0.7, 0.8, 0.9)
	sky_material.ground_bottom_color = Color(0.3, 0.3, 0.3)
	sky_material.ground_horizon_color = Color(0.6, 0.6, 0.6)
	sky.sky_material = sky_material
	env.sky = sky

	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7

	# Fog
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.8, 0.9)
	env.fog_light_energy = 1.0
	env.fog_density = 0.0008

	# SSAO
	env.ssao_enabled = true
	env.ssao_radius = 2.0
	env.ssao_intensity = 1.5
	env.ssao_power = 2.0
	env.ssao_detail = 0.5

	# Glow/Bloom
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_strength = 0.8
	env.glow_bloom = 0.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	var world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
