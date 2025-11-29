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
const RoadNetworkBuilder = preload("res://scripts/data/road_network_builder.gd")

# Terrain layer
const HeightmapLoader = preload("res://scripts/terrain/heightmap_loader.gd")

# Generator layer
const RoadGenerator = preload("res://scripts/generators/road_generator.gd")
const ParkGenerator = preload("res://scripts/generators/park_generator.gd")
const WaterGenerator = preload("res://scripts/generators/water_generator.gd")
const FeatureFactory = preload("res://scripts/generators/feature_factory.gd")

# City layer
const ChunkManager = preload("res://scripts/city/chunk_manager.gd")
const CameraController = preload("res://scripts/city/camera_controller.gd")
const DebugUI = preload("res://scripts/city/debug_ui.gd")

# Visual systems layer
const VisualManager = preload("res://scripts/visual/visual_manager.gd")
const MaterialLibrary = preload("res://scripts/visual/material_library.gd")
const LightingController = preload("res://scripts/visual/lighting_controller.gd")
const PostProcessingStack = preload("res://scripts/visual/post_processing_stack.gd")
const EnvironmentPresets = preload("res://scripts/visual/environment_presets.gd")
const LightingLODManager = preload("res://scripts/visual/lighting_lod_manager.gd")
const EnvironmentManager = preload("res://scripts/visual/environment_manager.gd")

# ========================================================================
# EXPORTS
# ========================================================================

@export_group("Retro Rendering")
@export var viewport_width: int = 1280
@export var viewport_height: int = 720
@export var current_palette: String = "extended_256"

# ========================================================================
# COMPONENTS (Dependency Injection)
# ========================================================================

var chunk_manager: ChunkManager
var camera_controller: CameraController
var debug_ui: DebugUI
var feature_factory: FeatureFactory

# Terrain system
var heightmap_loader: HeightmapLoader

# Road network (graph structure for intersections)
var road_network: RoadNetworkBuilder

# Visual systems
var visual_manager: VisualManager
var material_library: MaterialLibrary
var lighting_controller: LightingController
var post_processing_stack: PostProcessingStack
var environment_presets: EnvironmentPresets
var lighting_lod_manager: LightingLODManager
var environment_manager: EnvironmentManager

# Scene references for visual systems
var directional_light: DirectionalLight3D
var world_environment: WorldEnvironment

# Retro rendering components
var sub_viewport: SubViewport
var display_layer: CanvasLayer
var display_rect: TextureRect

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

	# Build road network graph (intersections + segments)
	road_network = RoadNetworkBuilder.new()
	road_network.build_network(osm_data.roads)
	print("")

	# Setup environment first (creates lighting/world_environment/ground plane)
	environment_manager = EnvironmentManager.new()
	add_child(environment_manager)
	environment_manager.setup(self)

	# Get references for visual systems
	directional_light = environment_manager.directional_light
	world_environment = environment_manager.world_environment

	# Setup anti-aliasing on main viewport
	environment_manager.setup_anti_aliasing(get_viewport())

	# Initialize visual systems (requires lighting/environment to be set up)
	_initialize_visual_systems()

	# Initialize terrain system (heightmap for elevation queries)
	_initialize_terrain()

	# Initialize components
	_initialize_components(osm_data)

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
	print("   F5: Cycle visual presets")
	print("   F6: Change time of day")
	print("   F7/F8: Adjust stylization (+/-)")

func _process(delta: float):
	# Update camera
	if camera_controller:
		camera_controller.update(delta)

	# Update chunk streaming
	if chunk_manager and camera_controller and camera_controller.camera:
		chunk_manager.update(delta, camera_controller.camera.global_position)

	# Update visual systems (for dynamic effects like time-of-day)
	if visual_manager:
		visual_manager._process(delta)

	# Update lighting LOD (manages light count based on camera distance)
	if lighting_lod_manager and camera_controller and camera_controller.camera:
		lighting_lod_manager.update_lod(camera_controller.camera.global_position, delta)

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

func _initialize_terrain():
	print("🏔️ Initializing terrain system...")
	print("")

	heightmap_loader = HeightmapLoader.new()

	var heightmap_config = "res://data/heightmap/heightmap_config.json"
	if not heightmap_loader.load_heightmap(heightmap_config):
		push_error("Failed to load heightmap - check data/heightmap/ folder")
		return

	print("   ✅ Terrain system initialized")
	print("")

func _initialize_components(osm_data: OSMDataComplete):
	print("🔧 Initializing components...")
	print("")

	# 1. Create FeatureFactory and set MaterialLibrary + Heightmap + RoadNetwork
	feature_factory = FeatureFactory.new()
	feature_factory.material_library = material_library
	feature_factory.heightmap = heightmap_loader
	feature_factory.road_network = road_network  # Enable batched road rendering

	# 2. Create ChunkManager with factory (uses Config singleton for defaults)
	chunk_manager = ChunkManager.new(feature_factory, self)
	# Values are now initialized from Config singleton in ChunkManager._init()

	print("   ⚡ Using Config: load_radius=", GameConfig.CHUNK_LOAD_RADIUS, "m, unload_radius=", GameConfig.CHUNK_UNLOAD_RADIUS, "m")

	# Organize data into chunks
	chunk_manager.organize_data(osm_data)

	# 3. Create CameraController
	camera_controller = CameraController.new()
	add_child(camera_controller)

	var start_position = Vector3(-300, 100, -2000)  # South Lake Union
	camera_controller.setup_camera(self, start_position)

	# Connect camera signals
	camera_controller.camera_moved.connect(_on_camera_moved)

	# Update visual systems with camera reference
	if visual_manager and camera_controller.camera:
		visual_manager.camera = camera_controller.camera
	if post_processing_stack and camera_controller.camera:
		post_processing_stack.camera = camera_controller.camera

	# 4. Create DebugUI with visual manager and LOD manager
	debug_ui = DebugUI.new()
	add_child(debug_ui)
	debug_ui.setup(self, chunk_manager, visual_manager, lighting_lod_manager)

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
# VISUAL SYSTEMS INITIALIZATION
# ========================================================================

func _initialize_visual_systems():
	print("🎨 Initializing visual systems...")
	print("")

	# 1. Create MaterialLibrary
	material_library = MaterialLibrary.new()
	add_child(material_library)
	material_library.initialize()

	# 2. Create LightingController
	lighting_controller = LightingController.new()
	add_child(lighting_controller)
	lighting_controller.initialize(world_environment, directional_light)

	# 3. Create PostProcessingStack
	post_processing_stack = PostProcessingStack.new()
	add_child(post_processing_stack)
	# Camera will be initialized later, pass null for now
	post_processing_stack.initialize(null, world_environment)

	# 4. Create EnvironmentPresets
	environment_presets = EnvironmentPresets.new()
	add_child(environment_presets)

	# 5. Create VisualManager and inject dependencies
	visual_manager = VisualManager.new()
	add_child(visual_manager)
	visual_manager.initialize(world_environment, directional_light, null)  # Camera set later
	visual_manager.inject_subsystems(
		lighting_controller,
		material_library,
		post_processing_stack,
		environment_presets
	)

	# 6. Create LightingLODManager for dynamic light LOD
	lighting_lod_manager = LightingLODManager.new()
	add_child(lighting_lod_manager)
	lighting_lod_manager.lighting_controller = lighting_controller

	# Connect time-of-day changes to LOD manager for building light fading
	lighting_controller.time_of_day_changed.connect(lighting_lod_manager.on_time_changed)

	# Apply default preset
	visual_manager.apply_preset("default")

	print("   ✅ Visual systems initialized with 'default' preset")
	print("   ✅ LightingLODManager initialized (32 shadow / 400 active, 1000m MID range)")
	print("")

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
		# Check both active_chunks AND chunk_states to prevent duplicate loading
		var chunk_state = chunk_manager.chunk_states.get(chunk_key, "unloaded")
		if not chunk_manager.active_chunks.has(chunk_key) and chunk_state == "unloaded":
			chunk_manager.load_chunk(chunk_key)

	# Load distant water at 2x radius
	chunk_manager._load_distant_water(camera_pos_2d, chunk_manager.chunk_load_radius * 2.0)

	print("   Active chunks AFTER: ", chunk_manager.active_chunks.size())
	print("========================================")

func _on_debug_settings_reset():
	# Reset to Config defaults
	chunk_manager.chunk_load_radius = GameConfig.CHUNK_LOAD_RADIUS
	chunk_manager.chunk_unload_radius = GameConfig.CHUNK_UNLOAD_RADIUS
	camera_controller.set_speeds(1.0)

	# Update UI
	var load_input = debug_ui.debug_panel.find_child("LoadInput", true, false) as LineEdit
	var unload_input = debug_ui.debug_panel.find_child("UnloadInput", true, false) as LineEdit
	var speed_input = debug_ui.debug_panel.find_child("SpeedInput", true, false) as LineEdit

	if load_input:
		load_input.text = str(int(GameConfig.CHUNK_LOAD_RADIUS))
	if unload_input:
		unload_input.text = str(int(GameConfig.CHUNK_UNLOAD_RADIUS))
	if speed_input:
		speed_input.text = "1.0"

	debug_ui.show_status("✓ Reset to defaults", false)

func _on_chunk_viz_toggled(enabled: bool):
	# Chunk visualization toggled - DebugUI handles the visualization
	pass

# ========================================================================
# RETRO VIEWPORT SETUP
# ========================================================================

func _setup_retro_viewport():
	"""
	Creates the SubViewport rendering architecture for native low-resolution rendering.

	Structure:
	  CityRenderer (Node3D)
	  ├── SubViewport (480×360) - Renders at LOW resolution
	  │   ├── Camera3D, Light, Environment, Chunks (created later)
	  │
	  └── CanvasLayer (layer -1) - Display layer
	      └── TextureRect (fullscreen) - Upscales SubViewport with shader
	"""
	print("   🎨 Setting up retro viewport (", viewport_width, "×", viewport_height, ")")

	# Create SubViewport for low-res rendering
	sub_viewport = SubViewport.new()
	sub_viewport.size = Vector2i(viewport_width, viewport_height)
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub_viewport.transparent_bg = false

	# Disable anti-aliasing for pixel-perfect retro look
	sub_viewport.msaa_3d = Viewport.MSAA_DISABLED
	sub_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	sub_viewport.use_taa = false
	sub_viewport.snap_2d_transforms_to_pixel = true

	add_child(sub_viewport)

	# Create display layer (behind debug UI)
	display_layer = CanvasLayer.new()
	display_layer.layer = -1
	add_child(display_layer)

	# Create fullscreen TextureRect to upscale the SubViewport
	display_rect = TextureRect.new()
	display_rect.texture = sub_viewport.get_texture()
	display_rect.stretch_mode = TextureRect.STRETCH_SCALE

	# Set anchors to fill the entire screen
	display_rect.anchor_left = 0.0
	display_rect.anchor_top = 0.0
	display_rect.anchor_right = 1.0
	display_rect.anchor_bottom = 1.0
	display_rect.offset_left = 0.0
	display_rect.offset_top = 0.0
	display_rect.offset_right = 0.0
	display_rect.offset_bottom = 0.0

	# CRITICAL: Use nearest-neighbor filtering for crisp pixel upscaling
	display_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	display_layer.add_child(display_rect)

	print("   ✅ Retro viewport created")

func _setup_retro_shader():
	"""
	Applies the retro 3D shader to the display TextureRect.
	Handles palette quantization and Bayer dithering.
	"""
	print("   🎨 Setting up retro shader (palette: ", current_palette, ")")

	# Load palette script
	var palette_script = load("res://visuals/palettes/" + current_palette + ".gd")
	if not palette_script:
		print("   ❌ Failed to load palette: ", current_palette)
		return

	# Get palette constant from script
	var palette_data = palette_script.PALETTE
	var palette_size = palette_script.PALETTE_SIZE

	print("   📊 Loaded ", palette_size, " colors from ", palette_script.PALETTE_NAME)

	# Load shader
	var shader = load("res://shaders/retro_3d.gdshader")
	if not shader:
		print("   ❌ Failed to load shader")
		return

	# Create shader material
	var material = ShaderMaterial.new()
	material.shader = shader

	# Set shader parameters
	material.set_shader_parameter("palette", palette_data)
	material.set_shader_parameter("palette_size", palette_size)
	material.set_shader_parameter("dither_strength", 0.0)  # Disabled for clean modern look
	material.set_shader_parameter("enable_dithering", false)  # No dithering
	material.set_shader_parameter("use_bayer_8x8", true)
	material.set_shader_parameter("show_palette_debug", false)

	# Apply material to display rect
	display_rect.material = material

	print("   ✅ Retro shader applied with ", palette_size, " colors")
