extends Node3D

## City Renderer with Chunk-Based Streaming
##
## Renders a 3D city from OpenStreetMap data (South Lake Union, Seattle)
## Features:
##   - Dynamic chunk-based streaming (load/unload based on camera position)
##   - Detailed building generation with windows, roofs, and materials
##   - Roads, parks, and water bodies
##   - Real-time adjustable chunk parameters via debug UI
##
## Dependencies (globally available via class_name):
##   - BuildingGeneratorMesh: Procedural building mesh generator
##   - OSMDataComplete: OSM data parser
##   - PolygonTriangulator: Polygon triangulation utility

# ========================================================================
# CONFIGURATION
# ========================================================================

# Label Settings
const LABEL_DISTANCE_SHOW = 200.0     # Show labels within this distance from camera
const LABEL_FONT_SIZE_BUILDING = 256  # Building label font size (HUGE for visibility)
const LABEL_FONT_SIZE_OTHER = 96      # Road/Park/Water label font size

# ========================================================================

# ========================================================================
# STATE VARIABLES
# ========================================================================

# Camera
var camera: Camera3D

# HUD
var hud_label: Label
var debug_panel: Control
var debug_visible: bool = false
var chunk_viz_enabled: bool = false
var chunk_viz_nodes: Dictionary = {}  # Vector2i → Node3D (debug wireframes)

# Building tracking (for chunk unload cleanup)
var buildings: Array = []  # Array of {node, position}

# Road tracking (for chunk unload cleanup)
var roads: Array = []  # Array of {node, path, position}

# ========================================================================
# CHUNK STREAMING SYSTEM
# ========================================================================

# Chunk streaming configuration (editable in inspector and at runtime)
@export_group("Chunk Streaming")
@export_range(100.0, 2000.0, 50.0) var chunk_size: float = 500.0  ## Size of each chunk (meters × meters)
@export_range(500.0, 5000.0, 100.0) var chunk_load_radius: float = 1000.0  ## Load chunks within this distance (optimized for performance)
@export_range(500.0, 6000.0, 100.0) var chunk_unload_radius: float = 1500.0  ## Unload chunks beyond this distance
@export_range(0.1, 2.0, 0.1) var chunk_update_interval: float = 1.0  ## How often to check for chunk updates (seconds)
@export var max_chunks_per_frame: int = 2  ## Maximum chunks to load/unload per update cycle

# Chunk data storage
var building_data_by_chunk: Dictionary = {}  # Vector2i → Array[BuildingData]
var road_data_by_chunk: Dictionary = {}      # Vector2i → Array[RoadData]
var park_data_by_chunk: Dictionary = {}      # Vector2i → Array[ParkData]
var water_data_by_chunk: Dictionary = {}     # Vector2i → Array[WaterData]

# Active chunks (currently loaded)
var active_chunks: Dictionary = {}  # Vector2i → Node3D (chunk container)

# Streaming update timer
var chunk_update_timer: float = 0.0

# ========================================================================

# Camera movement settings
var camera_speed: float = 20.0
var camera_fast_speed: float = 100.0
var camera_sensitivity: float = 0.002
var camera_rotation: Vector2 = Vector2.ZERO
var mouse_captured: bool = false

# ========================================================================
# LIFECYCLE METHODS
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

	# Setup camera
	_setup_camera(osm_data)

	# Setup environment
	_setup_environment()

	# Organize ALL features into chunks (prepare for streaming)
	print("🏗️  Organizing world into chunks...")
	print("")

	_organize_buildings_into_chunks(osm_data.buildings)
	_organize_roads_into_chunks(osm_data.roads)
	_organize_parks_into_chunks(osm_data.parks)
	_organize_water_into_chunks(osm_data.water)

	print("")
	print("📦 Loading initial chunks around camera...")

	# Load initial chunks around camera start position
	var camera_start_pos = Vector2(camera.global_position.x, -camera.global_position.z)
	var initial_chunks = _get_chunks_in_radius(camera_start_pos, chunk_load_radius)

	for chunk_key in initial_chunks:
		_load_chunk(chunk_key)

	print("")
	print("   ✅ Loaded ", active_chunks.size(), " initial chunks")
	print("      Buildings: ", buildings.size())
	print("      Roads: ", roads.size())

	# Create ground plane (lowest level)
	# DISABLED - ground covers parks and water
	# _create_ground()

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
	if not camera:
		return

	# Get movement input
	var input_dir = Vector3.ZERO

	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		input_dir -= camera.global_transform.basis.z
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		input_dir += camera.global_transform.basis.z
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input_dir -= camera.global_transform.basis.x
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input_dir += camera.global_transform.basis.x

	# Q/E for up/down
	if Input.is_key_pressed(KEY_Q):
		input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_E):
		input_dir.y += 1.0

	# Normalize and apply speed
	if input_dir.length() > 0:
		input_dir = input_dir.normalized()

		# Use fast speed with Shift
		var speed = camera_fast_speed if Input.is_key_pressed(KEY_SHIFT) else camera_speed
		camera.global_position += input_dir * speed * delta

	# ========================================================================
	# CHUNK STREAMING - Load/unload chunks as camera moves
	# ========================================================================
	chunk_update_timer += delta
	if chunk_update_timer >= chunk_update_interval:
		_update_chunk_streaming()
		chunk_update_timer = 0.0

	# Update HUD
	_update_hud()

func _update_hud():
	if not hud_label or not camera:
		return

	# Get camera direction (forward vector) - flip Z for correct north
	var forward = -camera.global_transform.basis.z
	var heading_angle = rad_to_deg(atan2(forward.x, -forward.z))  # Flip Z for correct compass
	if heading_angle < 0:
		heading_angle += 360

	# Determine compass direction
	var compass = ""
	if heading_angle >= 337.5 or heading_angle < 22.5:
		compass = "N"
	elif heading_angle >= 22.5 and heading_angle < 67.5:
		compass = "NE"
	elif heading_angle >= 67.5 and heading_angle < 112.5:
		compass = "E"
	elif heading_angle >= 112.5 and heading_angle < 157.5:
		compass = "SE"
	elif heading_angle >= 157.5 and heading_angle < 202.5:
		compass = "S"
	elif heading_angle >= 202.5 and heading_angle < 247.5:
		compass = "SW"
	elif heading_angle >= 247.5 and heading_angle < 292.5:
		compass = "W"
	else:
		compass = "NW"

	# Build HUD text
	var pos = camera.global_position
	var speed = camera_fast_speed if Input.is_key_pressed(KEY_SHIFT) else camera_speed
	var hud_text = ""
	hud_text += "POSITION: (%.0f, %.0f, %.0f)\n" % [pos.x, pos.y, pos.z]
	hud_text += "HEADING: %s (%.0f°)\n" % [compass, heading_angle]
	hud_text += "SPEED: %.0f m/s\n" % speed
	hud_text += "\n"
	hud_text += "TARGETS:\n"
	hud_text += "  Lake Union: (319, 0, -1544)\n"
	hud_text += "  Model Boat Pond: (92, 0, -54)\n"
	hud_text += "  Seattle Center: (-965, 0, 458)\n"
	hud_text += "\n"
	hud_text += "Active Chunks: %d | Buildings: %d | Roads: %d\n" % [active_chunks.size(), buildings.size(), roads.size()]
	hud_text += "FPS: %d" % Engine.get_frames_per_second()

	hud_label.text = hud_text

	# Update debug panel stats if visible
	if debug_visible and debug_panel:
		var stats_label = debug_panel.find_child("StatsLabel")
		if stats_label:
			stats_label.text = "Active Chunks: %d\nBuildings: %d\nRoads: %d" % [active_chunks.size(), buildings.size(), roads.size()]

# ========================================================================
# INPUT HANDLING
# ========================================================================

func _input(event: InputEvent):
	# Right-click to capture mouse
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				mouse_captured = true
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				mouse_captured = false

	# ESC to release mouse
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE and event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			mouse_captured = false

		# F3 to toggle debug panel
		if event.keycode == KEY_F3 and event.pressed:
			debug_visible = not debug_visible
			if debug_panel:
				debug_panel.visible = debug_visible

		# F4 to toggle chunk visualization
		if event.keycode == KEY_F4 and event.pressed:
			chunk_viz_enabled = not chunk_viz_enabled
			_update_chunk_visualization()
			print("🔲 Chunk visualization: ", "ON" if chunk_viz_enabled else "OFF")

	# Mouse movement for camera rotation
	if event is InputEventMouseMotion and mouse_captured:
		camera_rotation.x -= event.relative.y * camera_sensitivity
		camera_rotation.y -= event.relative.x * camera_sensitivity

		# Clamp vertical rotation to avoid flipping
		camera_rotation.x = clamp(camera_rotation.x, -PI/2, PI/2)

		# Apply rotation to camera
		camera.rotation.x = camera_rotation.x
		camera.rotation.y = camera_rotation.y

	# Scroll wheel to adjust speed
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera_speed = min(camera_speed + 5.0, 100.0)
			camera_fast_speed = min(camera_fast_speed + 20.0, 300.0)
			print("Camera speed: ", camera_speed, "m/s (Shift: ", camera_fast_speed, "m/s)")
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera_speed = max(camera_speed - 5.0, 5.0)
			camera_fast_speed = max(camera_fast_speed - 20.0, 20.0)
			print("Camera speed: ", camera_speed, "m/s (Shift: ", camera_fast_speed, "m/s)")

# ========================================================================
# SCENE SETUP
# ========================================================================

func _setup_camera(_osm_data: OSMDataComplete):
	camera = Camera3D.new()
	add_child(camera)

	# Position camera in South Lake Union
	camera.position = Vector3(-300, 100, -2000)
	camera.look_at(Vector3(-300, 0, -2000), Vector3.UP)
	camera.fov = 70

	# Initialize camera rotation to match current orientation
	camera_rotation = Vector2(camera.rotation.x, camera.rotation.y)

	# Create HUD
	_create_hud()
	_create_debug_panel()

	print("📷 Camera positioned at: ", camera.position)

func _create_hud():
	var canvas = CanvasLayer.new()
	add_child(canvas)

	hud_label = Label.new()
	hud_label.position = Vector2(20, 20)
	hud_label.add_theme_font_size_override("font_size", 14)  # Reduced from 18
	hud_label.add_theme_color_override("font_color", Color(1, 1, 0))  # Yellow
	hud_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hud_label.add_theme_constant_override("outline_size", 2)  # Reduced from 3
	canvas.add_child(hud_label)
	print("📊 HUD created")

func _create_debug_panel():
	var canvas = CanvasLayer.new()
	add_child(canvas)

	debug_panel = PanelContainer.new()
	debug_panel.position = Vector2(20, 200)
	debug_panel.visible = false
	canvas.add_child(debug_panel)

	var vbox = VBoxContainer.new()
	debug_panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "DEBUG PANEL (F3 to toggle)"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1, 1, 0))
	vbox.add_child(title)

	# === MOVEMENT SPEED SECTION ===
	var speed_header = Label.new()
	speed_header.text = "--- Movement Speed ---"
	speed_header.add_theme_font_size_override("font_size", 14)
	speed_header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(speed_header)

	# Speed Multiplier
	var speed_hbox = HBoxContainer.new()
	vbox.add_child(speed_hbox)

	var speed_label = Label.new()
	speed_label.text = "Speed Multiplier:"
	speed_label.custom_minimum_size = Vector2(120, 0)
	speed_hbox.add_child(speed_label)

	var speed_input = LineEdit.new()
	speed_input.text = "1.0"
	speed_input.custom_minimum_size = Vector2(80, 0)
	speed_input.name = "SpeedInput"
	speed_hbox.add_child(speed_input)

	# Current speeds display
	var speeds_label = Label.new()
	speeds_label.text = "Normal: 20 m/s | Fast: 100 m/s"
	speeds_label.name = "SpeedsLabel"
	speeds_label.add_theme_font_size_override("font_size", 12)
	speeds_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(speeds_label)

	# === CHUNK STREAMING SECTION ===
	var chunk_header = Label.new()
	chunk_header.text = "--- Chunk Streaming ---"
	chunk_header.add_theme_font_size_override("font_size", 14)
	chunk_header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(chunk_header)

	# Load Radius Input
	var load_hbox = HBoxContainer.new()
	vbox.add_child(load_hbox)

	var load_label = Label.new()
	load_label.text = "Load Radius (m):"
	load_label.custom_minimum_size = Vector2(120, 0)
	load_hbox.add_child(load_label)

	var load_input = LineEdit.new()
	load_input.text = str(int(chunk_load_radius))
	load_input.custom_minimum_size = Vector2(80, 0)
	load_input.name = "LoadInput"
	load_hbox.add_child(load_input)

	# Unload Radius Input
	var unload_hbox = HBoxContainer.new()
	vbox.add_child(unload_hbox)

	var unload_label = Label.new()
	unload_label.text = "Unload Radius (m):"
	unload_label.custom_minimum_size = Vector2(120, 0)
	unload_hbox.add_child(unload_label)

	var unload_input = LineEdit.new()
	unload_input.text = str(int(chunk_unload_radius))
	unload_input.custom_minimum_size = Vector2(80, 0)
	unload_input.name = "UnloadInput"
	unload_hbox.add_child(unload_input)

	# Chunk Size (Read-only display)
	var size_hbox = HBoxContainer.new()
	vbox.add_child(size_hbox)

	var size_label = Label.new()
	size_label.text = "Chunk Size: " + str(int(chunk_size)) + "m (fixed)"
	size_label.custom_minimum_size = Vector2(250, 0)
	size_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	size_hbox.add_child(size_label)

	# Apply Button
	var apply_button = Button.new()
	apply_button.text = "Apply Changes"
	apply_button.pressed.connect(_on_apply_chunk_settings)
	vbox.add_child(apply_button)

	# Reset Button
	var reset_button = Button.new()
	reset_button.text = "Reset to Defaults"
	reset_button.pressed.connect(_on_reset_chunk_settings)
	vbox.add_child(reset_button)

	# Status Label
	var status_label = Label.new()
	status_label.text = ""
	status_label.name = "StatusLabel"
	status_label.add_theme_color_override("font_color", Color(0, 1, 0))
	vbox.add_child(status_label)

	# Stats
	var stats_label = Label.new()
	stats_label.text = "Active Chunks: 0"
	stats_label.name = "StatsLabel"
	vbox.add_child(stats_label)

	print("🐛 Debug panel created (F3 to toggle)")

func _on_apply_chunk_settings():
	var load_input = debug_panel.find_child("LoadInput", true, false) as LineEdit
	var unload_input = debug_panel.find_child("UnloadInput", true, false) as LineEdit
	var speed_input = debug_panel.find_child("SpeedInput", true, false) as LineEdit
	var status_label = debug_panel.find_child("StatusLabel", true, false) as Label

	if not load_input or not unload_input or not speed_input or not status_label:
		print("❌ Debug panel UI elements not found")
		return

	# Parse values
	var new_load = load_input.text.to_float()
	var new_unload = unload_input.text.to_float()
	var new_speed = speed_input.text.to_float()

	# Validate
	var errors = []
	if new_load < 100 or new_load > 5000:
		errors.append("Load radius must be 100-5000m")
	if new_unload < 200 or new_unload > 6000:
		errors.append("Unload radius must be 200-6000m")
	if new_unload <= new_load:
		errors.append("Unload radius must be > load radius")
	if new_speed < 0.1 or new_speed > 10.0:
		errors.append("Speed multiplier must be 0.1-10.0x")

	if errors.size() > 0:
		status_label.text = "ERROR: " + errors[0]
		status_label.add_theme_color_override("font_color", Color(1, 0, 0))
		print("❌ Invalid settings: ", errors)
		return

	# Apply settings
	var old_load = chunk_load_radius
	var old_unload = chunk_unload_radius

	chunk_load_radius = new_load
	chunk_unload_radius = new_unload

	# Apply speed multiplier
	var base_speed = 20.0
	var base_fast_speed = 100.0
	camera_speed = base_speed * new_speed
	camera_fast_speed = base_fast_speed * new_speed

	# Update speed display
	var speeds_label = debug_panel.find_child("SpeedsLabel", true, false) as Label
	if speeds_label:
		speeds_label.text = "Normal: " + str(int(camera_speed)) + " m/s | Fast: " + str(int(camera_fast_speed)) + " m/s"

	status_label.text = "✓ Applied! Check console for details"
	status_label.add_theme_color_override("font_color", Color(0, 1, 0))

	print("========================================")
	print("🔧 SETTINGS CHANGED:")
	print("   Load: ", int(old_load), "m → ", int(new_load), "m")
	print("   Unload: ", int(old_unload), "m → ", int(new_unload), "m")
	print("   Speed: ", new_speed, "x (Normal: ", int(camera_speed), " m/s, Fast: ", int(camera_fast_speed), " m/s)")
	print("   Active chunks BEFORE: ", active_chunks.size())
	print("========================================")

	# Force immediate chunk streaming update (no gradual loading)
	var camera_pos_2d = Vector2(camera.global_position.x, -camera.global_position.z)

	# Unload ALL chunks beyond new unload radius
	var chunks_to_unload = []
	for chunk_key in active_chunks.keys():
		var chunk_center = Vector2(chunk_key.x * chunk_size + chunk_size/2, chunk_key.y * chunk_size + chunk_size/2)
		var distance = camera_pos_2d.distance_to(chunk_center)
		if distance > chunk_unload_radius:
			chunks_to_unload.append(chunk_key)

	for chunk_key in chunks_to_unload:
		_unload_chunk(chunk_key)

	# Load ALL new chunks within new load radius
	var chunks_to_load = _get_chunks_in_radius(camera_pos_2d, chunk_load_radius)
	for chunk_key in chunks_to_load:
		if not active_chunks.has(chunk_key):
			_load_chunk(chunk_key)

	# Also load large water bodies at 2x distance
	_load_distant_water(camera_pos_2d, chunk_load_radius * 2.0)

	print("   Active chunks AFTER: ", active_chunks.size())
	print("   Unloaded: ", chunks_to_unload.size(), " | Loaded: ", chunks_to_load.size() - (active_chunks.size() - chunks_to_unload.size()))
	print("========================================")

func _on_reset_chunk_settings():
	# Update UI first
	var load_input = debug_panel.find_child("LoadInput", true, false) as LineEdit
	var unload_input = debug_panel.find_child("UnloadInput", true, false) as LineEdit
	var speed_input = debug_panel.find_child("SpeedInput", true, false) as LineEdit

	if load_input:
		load_input.text = "1000"
	if unload_input:
		unload_input.text = "1500"
	if speed_input:
		speed_input.text = "1.0"

	# Apply via the normal flow
	_on_apply_chunk_settings()

# Removed _on_speed_changed - speed now applies with Apply Changes button

func _setup_environment():
	# Directional light (sun)
	var light = DirectionalLight3D.new()
	light.position = Vector3(0, 100, 0)
	light.rotation_degrees = Vector3(-50, -30, 0)
	light.shadow_enabled = true
	light.light_energy = 1.3  # Slightly brighter
	light.light_color = Color(1.0, 0.98, 0.95)  # Slightly warm sunlight

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

	# Create sky
	var sky = Sky.new()
	var sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.4, 0.6, 0.9)  # Blue sky
	sky_material.sky_horizon_color = Color(0.7, 0.8, 0.9)  # Lighter horizon
	sky_material.ground_bottom_color = Color(0.3, 0.3, 0.3)
	sky_material.ground_horizon_color = Color(0.6, 0.6, 0.6)
	sky.sky_material = sky_material
	env.sky = sky

	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7  # Increased to show building colors better

	# Add fog for distance
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.8, 0.9)
	env.fog_light_energy = 1.0
	env.fog_density = 0.0008  # Slightly reduced for better visibility

	# Enable SSAO for depth and ambient occlusion
	env.ssao_enabled = true
	env.ssao_radius = 2.0
	env.ssao_intensity = 1.5
	env.ssao_power = 2.0
	env.ssao_detail = 0.5

	# Enable glow/bloom for subtle highlights
	env.glow_enabled = true
	env.glow_intensity = 0.3  # Subtle
	env.glow_strength = 0.8
	env.glow_bloom = 0.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	var world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

# ========================================================================
# ROAD GENERATION
# ========================================================================

func _get_road_width(highway_type: String) -> float:
	match highway_type:
		"motorway", "trunk":
			return 20.0  # Wide highways
		"primary":
			return 16.0  # Major arterials
		"secondary", "tertiary":
			return 12.0  # Medium roads
		"residential", "unclassified":
			return 10.0  # Neighborhood streets
		"service":
			return 6.0   # Service roads (if we render them)
		"footway", "path", "pedestrian", "track":
			return 2.5   # Narrow footpaths
		"steps":
			return 2.0   # Stairs
		_:
			return 10.0  # Default

## Get road elevation based on type (for proper layering)
func _get_road_elevation(highway_type: String) -> float:
	match highway_type:
		"motorway", "trunk", "primary", "secondary", "tertiary", "residential", "unclassified":
			return 0.20  # Major roads highest
		"footway", "path", "pedestrian", "track", "steps":
			return 0.10  # Footpaths well above parks to prevent z-fighting
		_:
			return 0.20  # Default

## Create simple road without LOD - using continuous mesh
func _create_simple_road(path: Array, width: float, road_data: Dictionary = {}) -> Node3D:
	# Calculate road center for positioning
	var road_center = Vector2.ZERO
	for point in path:
		road_center += point
	road_center /= path.size()

	# Create wrapper node for this road
	var road_node = Node3D.new()
	road_node.name = "Road_" + str(road_data.get("id", 0))
	road_node.position = Vector3(road_center.x, 0, -road_center.y)
	# NOTE: Parent is set by caller (chunk system or old rendering code)

	# Check if this is a bridge
	var is_bridge = road_data.get("bridge", false)
	var bridge_height = 8.0 if is_bridge else 0.0

	# Get elevation based on road type for proper layering
	var highway_type = road_data.get("highway_type", "")
	var base_elevation = _get_road_elevation(highway_type)

	# Create continuous road mesh
	var mesh_instance = _create_road_mesh(path, road_center, width, bridge_height, base_elevation, road_data)
	if mesh_instance:
		road_node.add_child(mesh_instance)

	# Add bridge pillars if this is a bridge
	if is_bridge:
		_create_bridge_pillars_along_path(road_node, path, road_center, width, bridge_height)

	# Add road name label for named roads (excluding only footpaths/paths)
	var road_name = road_data.get("name", "")
	var show_label = highway_type in ["motorway", "trunk", "primary", "secondary", "tertiary", "residential", "unclassified"]

	if road_name != "" and show_label:
		var label = Label3D.new()
		label.name = "RoadLabel"  # For distance culling
		label.text = road_name
		label.position = Vector3(0, 0.5, 0)  # 0.5m above ground
		label.font_size = LABEL_FONT_SIZE_OTHER  # 96pt
		label.outline_size = 12
		label.modulate = Color(0, 0.8, 1)  # Cyan for roads
		label.outline_modulate = Color(0, 0, 0)  # Black outline
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true  # Visible through objects
		road_node.add_child(label)

	return road_node

## Create continuous road mesh along path (fixes choppy segmentation)
func _create_road_mesh(path: Array, road_center: Vector2, width: float, bridge_height: float, base_elevation: float, road_data: Dictionary) -> MeshInstance3D:
	if path.size() < 2:
		return null

	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()

	var half_width = width / 2.0
	var y = bridge_height + base_elevation  # Bridge height + road type elevation

	# Generate road geometry: extrude a rectangle along the path
	for i in range(path.size()):
		var p = path[i] - road_center
		var pos_3d = Vector3(p.x, y, -p.y)

		# Calculate direction for perpendicular offset
		var direction: Vector2
		if i == 0:
			# First point: use direction to next point
			direction = (path[i + 1] - path[i]).normalized()
		elif i == path.size() - 1:
			# Last point: use direction from previous point
			direction = (path[i] - path[i - 1]).normalized()
		else:
			# Middle points: average direction (smooth curves)
			var dir_prev = (path[i] - path[i - 1]).normalized()
			var dir_next = (path[i + 1] - path[i]).normalized()
			direction = (dir_prev + dir_next).normalized()

		# Perpendicular vector (rotate 90 degrees)
		var perpendicular = Vector2(-direction.y, direction.x)

		# Create two vertices for left and right edges
		var left = pos_3d + Vector3(perpendicular.x * half_width, 0, -perpendicular.y * half_width)
		var right = pos_3d + Vector3(-perpendicular.x * half_width, 0, perpendicular.y * half_width)

		vertices.append(left)
		vertices.append(right)

		# Normals point up
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)

		# UVs (simple mapping along path)
		var u = float(i) / float(path.size() - 1)
		uvs.append(Vector2(0, u))
		uvs.append(Vector2(1, u))

	# Create triangles connecting consecutive cross-sections
	for i in range(path.size() - 1):
		var base = i * 2
		# Two triangles per quad (left-right cross-section to next)
		# Triangle 1: bottom-left, top-left, top-right
		indices.append(base)
		indices.append(base + 2)
		indices.append(base + 3)

		# Triangle 2: bottom-left, top-right, bottom-right
		indices.append(base)
		indices.append(base + 3)
		indices.append(base + 1)

	# Create ArrayMesh
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var array_mesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = array_mesh
	mesh_instance.material_override = _get_road_material(road_data)

	return mesh_instance

## Create bridge pillars along entire path
func _create_bridge_pillars_along_path(parent: Node3D, path: Array, road_center: Vector2, _road_width: float, bridge_height: float):
	var pillar_spacing = 20.0  # Place pillars every 20 meters
	var accumulated_distance = 0.0

	for i in range(path.size() - 1):
		var p1 = path[i] - road_center
		var p2 = path[i + 1] - road_center
		var segment_length = p1.distance_to(p2)

		# Place pillars along this segment
		var remaining = segment_length
		while remaining > 0:
			var distance_from_start = segment_length - remaining

			if accumulated_distance + distance_from_start >= pillar_spacing:
				# Place a pillar here
				var t = distance_from_start / segment_length
				var pillar_pos_2d = p1.lerp(p2, t)

				var pillar = CSGBox3D.new()
				pillar.size = Vector3(2.0, bridge_height, 2.0)  # 2m x 2m column
				pillar.position = Vector3(pillar_pos_2d.x, bridge_height / 2.0, -pillar_pos_2d.y)

				# Concrete material
				var material = StandardMaterial3D.new()
				material.albedo_color = Color(0.5, 0.5, 0.5)
				material.roughness = 0.8
				pillar.material = material

				parent.add_child(pillar)

				# Reset distance counter
				accumulated_distance = 0.0
				remaining -= pillar_spacing
			else:
				remaining = 0

		accumulated_distance += segment_length

## Get road material based on OSM surface type
func _get_road_material(road_data: Dictionary) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	var surface_type = road_data.get("surface", "").to_lower()

	match surface_type:
		"asphalt", "":
			# Default asphalt (medium-dark gray, more visible)
			material.albedo_color = Color(0.28, 0.28, 0.3)
			material.roughness = 0.75
			material.metallic = 0.05  # Slight sheen when wet
		"concrete":
			# Lighter gray concrete
			material.albedo_color = Color(0.4, 0.4, 0.42)
			material.roughness = 0.7
			material.metallic = 0.02
		"gravel":
			# Brown gravel
			material.albedo_color = Color(0.45, 0.4, 0.35)
			material.roughness = 1.0
		"dirt", "earth", "ground":
			# Brown dirt
			material.albedo_color = Color(0.4, 0.3, 0.2)
			material.roughness = 0.95
		"paving_stones", "paved", "cobblestone":
			# Light gray paving stones
			material.albedo_color = Color(0.5, 0.45, 0.45)
			material.roughness = 0.75
		"grass":
			# Green grass (for park paths)
			material.albedo_color = Color(0.3, 0.5, 0.2)
			material.roughness = 1.0
		_:
			# Unknown surface - default to asphalt
			material.albedo_color = Color(0.2, 0.2, 0.22)
			material.roughness = 0.8

	return material

# ========================================================================
# PARK GENERATION
# ========================================================================

func _create_park_mesh(footprint: Array, park_data: Dictionary = {}, parent: Node3D = self) -> MeshInstance3D:
	var park_name = park_data.get("name", "unnamed")

	# Validate polygon has enough points
	if footprint.size() < 3:
		return null

	# Calculate center for positioning
	var center = Vector2.ZERO
	for point in footprint:
		center += point
	center /= footprint.size()

	# Create mesh from polygon using PROPER triangulation
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()

	# Convert footprint to local coordinates
	var local_polygon = []
	for point in footprint:
		local_polygon.append(point - center)

	# Use Godot's built-in triangulation (handles concave polygons correctly)
	var indices = PolygonTriangulator.triangulate(local_polygon)

	# Check if triangulation succeeded
	if indices.is_empty():
		push_warning("Failed to triangulate park: " + park_name + " (invalid polygon)")
		return null

	# REVERSE indices for correct winding order (normals facing UP)
	var reversed_indices = PackedInt32Array()
	for i in range(0, indices.size(), 3):
		reversed_indices.append(indices[i + 2])
		reversed_indices.append(indices[i + 1])
		reversed_indices.append(indices[i])
	indices = reversed_indices

	# Create vertices
	for point in local_polygon:
		vertices.append(Vector3(point.x, 0, -point.y))
		normals.append(Vector3.UP)
		uvs.append(Vector2(point.x / 100.0, point.y / 100.0))

	# Create ArrayMesh
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var array_mesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = array_mesh
	mesh_instance.position = Vector3(center.x, 0.0, -center.y)  # Ground level

	# DARK SATURATED green opaque material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.1, 0.5, 0.1)  # DARK GREEN - very visible
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	material.roughness = 0.9
	material.metallic = 0.0
	mesh_instance.material_override = material

	parent.add_child(mesh_instance)

	# Add label
	park_name = park_data.get("name", "")
	var park_type = park_data.get("leisure_type", "park")
	var label_text = park_name if park_name != "" else park_type.capitalize()
	_add_entity_label(Vector3(center.x, 3, -center.y), "PARK: " + label_text, Color(0, 1, 0))

	return mesh_instance

# ========================================================================
# WATER GENERATION
# ========================================================================

func _create_water_mesh(footprint: Array, water_data: Dictionary = {}, parent: Node3D = self) -> MeshInstance3D:
	# Handle linear waterways (streams, rivers, etc.) as paths, not polygons
	var water_type = water_data.get("water_type", "")
	var water_name = water_data.get("name", "unnamed")

	if water_type in ["stream", "river", "canal", "drain", "ditch"]:
		return _create_waterway_path(footprint, water_data, parent)

	# Validate polygon has enough points
	if footprint.size() < 3:
		return null

	# Calculate center for positioning
	var center = Vector2.ZERO
	for point in footprint:
		center += point
	center /= footprint.size()

	# Calculate area to determine if this is a large water body
	var area = _calculate_polygon_area(footprint)
	var is_large_water = area > 50000.0  # > 50k sq meters (e.g., Lake Union)

	# Create mesh from polygon using PROPER triangulation
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()

	# Convert footprint to local coordinates
	var local_polygon = []
	for point in footprint:
		local_polygon.append(point - center)

	# Use Godot's built-in triangulation (handles concave polygons correctly)
	var indices = PolygonTriangulator.triangulate(local_polygon)

	# Check if triangulation succeeded
	if indices.is_empty():
		print("❌ Failed to triangulate water body: ", water_name)
		print("   Points: ", local_polygon.size(), " | Area: ", _calculate_polygon_area(footprint))
		print("   First point: ", local_polygon[0] if local_polygon.size() > 0 else "none")
		print("   Last point: ", local_polygon[local_polygon.size() - 1] if local_polygon.size() > 0 else "none")
		push_warning("Failed to triangulate water body: " + water_name + " (invalid polygon)")
		return null

	# DEBUG: Show triangulation success
	if water_name == "Model Boat Pond":
		print("✅ Model Boat Pond triangulated!")
		print("   Vertices: ", local_polygon.size())
		print("   Indices: ", indices.size(), " (", int(indices.size() / 3.0), " triangles)")
		print("   Material: DARK BLUE")

	# REVERSE indices for correct winding order (normals facing UP)
	var reversed_indices = PackedInt32Array()
	for i in range(0, indices.size(), 3):
		reversed_indices.append(indices[i + 2])
		reversed_indices.append(indices[i + 1])
		reversed_indices.append(indices[i])
	indices = reversed_indices

	# Create vertices
	for point in local_polygon:
		vertices.append(Vector3(point.x, 0, -point.y))
		normals.append(Vector3.UP)
		uvs.append(Vector2(point.x / 100.0, point.y / 100.0))

	# Create ArrayMesh
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var array_mesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = array_mesh

	# Different settings for large vs small water bodies
	if is_large_water:
		# Large lakes: ground level, semi-transparent blue with reflections
		mesh_instance.position = Vector3(center.x, 0.0, -center.y)

		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.1, 0.25, 0.55, 0.85)  # Semi-transparent blue
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.roughness = 0.1  # Smooth for reflections
		material.metallic = 0.6  # Reflective surface
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		mesh_instance.material_override = material
	else:
		# Small water features: elevated, semi-transparent blue with reflections
		mesh_instance.position = Vector3(center.x, 0.1, -center.y)

		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.15, 0.3, 0.65, 0.85)  # Semi-transparent blue
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.roughness = 0.15  # Slightly rough
		material.metallic = 0.5  # Reflective surface
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		mesh_instance.material_override = material

	parent.add_child(mesh_instance)

	# DEBUG: Confirm mesh added
	if water_name == "Model Boat Pond":
		print("✅ Model Boat Pond mesh added to scene at ", mesh_instance.position)
		print("   Mesh instance created: ", mesh_instance != null)
		print("   Has parent: ", mesh_instance.get_parent() != null)

	# Add label
	water_type = water_data.get("water_type", "water")
	var label_text = water_name if water_name != "" else water_type.capitalize()
	_add_entity_label(Vector3(center.x, 3, -center.y), "WATER: " + label_text, Color(0.3, 0.6, 1.0))

	return mesh_instance

## Create linear waterway (stream/river) as an extruded path
func _create_waterway_path(path: Array, water_data: Dictionary, parent: Node3D = self) -> MeshInstance3D:
	if path.size() < 2:
		return null

	var waterway_type = water_data.get("water_type", "stream")
	var center = water_data.get("center", Vector2.ZERO)

	# Determine width based on waterway type
	var width = 3.0  # Default stream width
	match waterway_type:
		"river": width = 8.0
		"canal": width = 6.0
		"stream": width = 3.0
		"drain": width = 2.0
		"ditch": width = 1.5

	# Create mesh similar to roads
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()

	var half_width = width / 2.0
	var y = 0.05  # Slightly above ground

	# Generate geometry along path
	for i in range(path.size()):
		var p = path[i] - center
		var pos_3d = Vector3(p.x, y, -p.y)

		# Calculate direction
		var direction: Vector2
		if i == 0:
			direction = (path[i + 1] - path[i]).normalized()
		elif i == path.size() - 1:
			direction = (path[i] - path[i - 1]).normalized()
		else:
			var dir_prev = (path[i] - path[i - 1]).normalized()
			var dir_next = (path[i + 1] - path[i]).normalized()
			direction = (dir_prev + dir_next).normalized()

		var perpendicular = Vector2(-direction.y, direction.x)
		var left = pos_3d + Vector3(perpendicular.x * half_width, 0, -perpendicular.y * half_width)
		var right = pos_3d + Vector3(-perpendicular.x * half_width, 0, perpendicular.y * half_width)

		vertices.append(left)
		vertices.append(right)
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		uvs.append(Vector2(0, float(i)))
		uvs.append(Vector2(1, float(i)))

	# Create triangles
	for i in range(path.size() - 1):
		var base = i * 2
		indices.append(base)
		indices.append(base + 2)
		indices.append(base + 3)
		indices.append(base)
		indices.append(base + 3)
		indices.append(base + 1)

	# Create mesh
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var array_mesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = array_mesh
	mesh_instance.position = Vector3(center.x, 0, -center.y)

	# Lighter blue for flowing water with reflections
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.45, 0.75, 0.85)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.2  # Slightly rougher for flowing water
	material.metallic = 0.4  # More reflective
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mesh_instance.material_override = material

	parent.add_child(mesh_instance)

	return mesh_instance

# ========================================================================
# UTILITY FUNCTIONS
# ========================================================================

func _calculate_polygon_area(polygon: Array) -> float:
	var area = 0.0
	for i in range(polygon.size()):
		var j = (i + 1) % polygon.size()
		area += polygon[i].x * polygon[j].y
		area -= polygon[j].x * polygon[i].y
	return abs(area) / 2.0

## Create ground plane
func _create_ground():
	var ground = CSGBox3D.new()
	ground.size = Vector3(2000, 1, 2000)
	ground.position = Vector3(0, -0.5, 0)

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.4, 0.3)  # Natural earth/grass tone
	material.roughness = 0.85
	material.metallic = 0.0

	# Add subtle detail through UV scaling (creates tiling effect)
	material.uv1_scale = Vector3(100, 100, 100)  # Tile texture 100x

	ground.material = material

	add_child(ground)

	print("   ✅ Ground plane created (2000m x 2000m)")

## Add a floating label to an entity
func _add_entity_label(label_position: Vector3, text: String, color: Color):
	var label = Label3D.new()
	label.text = text
	label.position = label_position
	label.font_size = 72  # Large, clear text
	label.outline_size = 15  # Thick black outline
	label.modulate = color
	label.outline_modulate = Color(0, 0, 0)  # Black outline
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true  # Always visible through objects
	add_child(label)

# ========================================================================
# CHUNK STREAMING IMPLEMENTATION
# ========================================================================

## Convert world position to chunk key
func _get_chunk_key(world_pos: Vector2) -> Vector2i:
	var chunk_x = int(floor(world_pos.x / chunk_size))
	var chunk_y = int(floor(world_pos.y / chunk_size))
	return Vector2i(chunk_x, chunk_y)

## Get all chunk keys within radius of a position
func _get_chunks_in_radius(center_pos: Vector2, radius: float) -> Array:
	var chunks = []
	var center_chunk = _get_chunk_key(center_pos)
	var chunk_radius = int(ceil(radius / chunk_size))

	for x in range(center_chunk.x - chunk_radius, center_chunk.x + chunk_radius + 1):
		for y in range(center_chunk.y - chunk_radius, center_chunk.y + chunk_radius + 1):
			var chunk_key = Vector2i(x, y)
			var chunk_center = Vector2(x * chunk_size + chunk_size/2, y * chunk_size + chunk_size/2)

			# Check if chunk center is within radius
			if center_pos.distance_to(chunk_center) <= radius + chunk_size * 0.707:  # Add diagonal
				chunks.append(chunk_key)

	return chunks

## Organize all building data into chunks (called at startup)
func _organize_buildings_into_chunks(buildings_data: Array):
	print("📦 Organizing ", buildings_data.size(), " buildings into chunks...")

	for building_data in buildings_data:
		var center = building_data.get("center", Vector2.ZERO)
		var chunk_key = _get_chunk_key(center)

		if not building_data_by_chunk.has(chunk_key):
			building_data_by_chunk[chunk_key] = []

		building_data_by_chunk[chunk_key].append(building_data)

	print("   ✅ Organized into ", building_data_by_chunk.size(), " chunks")

## Organize roads into chunks
func _organize_roads_into_chunks(roads_data: Array):
	print("📦 Organizing ", roads_data.size(), " roads into chunks...")

	for road_data in roads_data:
		var path = road_data.get("path", [])
		if path.size() < 2:
			continue

		# Calculate road center
		var center = Vector2.ZERO
		for point in path:
			center += point
		center /= path.size()

		var chunk_key = _get_chunk_key(center)

		if not road_data_by_chunk.has(chunk_key):
			road_data_by_chunk[chunk_key] = []

		road_data_by_chunk[chunk_key].append(road_data)

	print("   ✅ Organized into ", road_data_by_chunk.size(), " chunks")

## Organize parks into chunks
func _organize_parks_into_chunks(parks_data: Array):
	print("📦 Organizing ", parks_data.size(), " parks into chunks...")

	for park_data in parks_data:
		var center = park_data.get("center", Vector2.ZERO)
		var chunk_key = _get_chunk_key(center)

		if not park_data_by_chunk.has(chunk_key):
			park_data_by_chunk[chunk_key] = []

		park_data_by_chunk[chunk_key].append(park_data)

	print("   ✅ Organized into ", park_data_by_chunk.size(), " chunks")

## Organize water into chunks
func _organize_water_into_chunks(water_data: Array):
	print("📦 Organizing ", water_data.size(), " water features into chunks...")

	for water_feature in water_data:
		var center = water_feature.get("center", Vector2.ZERO)
		var chunk_key = _get_chunk_key(center)

		if not water_data_by_chunk.has(chunk_key):
			water_data_by_chunk[chunk_key] = []

		water_data_by_chunk[chunk_key].append(water_feature)

	print("   ✅ Organized into ", water_data_by_chunk.size(), " chunks")

## Load a chunk (create all buildings/roads/etc in this chunk)
func _load_chunk(chunk_key: Vector2i):
	if active_chunks.has(chunk_key):
		return  # Already loaded

	# Create chunk container
	var chunk_node = Node3D.new()
	chunk_node.name = "Chunk_%d_%d" % [chunk_key.x, chunk_key.y]
	add_child(chunk_node)

	# Load buildings in this chunk
	var buildings_in_chunk = building_data_by_chunk.get(chunk_key, [])
	for building_data in buildings_in_chunk:
		var center = building_data.get("center", Vector2.ZERO)
		var building = BuildingGeneratorMesh.create_building(building_data, chunk_node, true)
		building.position = Vector3(center.x, 0, -center.y)

		# Track for culling system
		buildings.append({
			"node": building,
			"position": building.position
		})

	# Load roads in this chunk
	var roads_in_chunk = road_data_by_chunk.get(chunk_key, [])
	for road_data in roads_in_chunk:
		var path = road_data.get("path", [])
		var highway_type = road_data.get("highway_type", "")

		# Skip service roads and cycleways
		if highway_type in ["cycleway", "service"]:
			continue

		var width = _get_road_width(highway_type)
		var road_node = _create_simple_road(path, width, road_data)

		if road_node:
			chunk_node.add_child(road_node)
			roads.append({
				"node": road_node,
				"path": path,
				"position": road_node.position
			})

	# Load parks in this chunk
	var parks_in_chunk = park_data_by_chunk.get(chunk_key, [])
	for park_data in parks_in_chunk:
		var footprint = park_data.get("footprint", [])
		if footprint.size() >= 3:
			_create_park_mesh(footprint, park_data, chunk_node)

	# Load water in this chunk
	var water_in_chunk = water_data_by_chunk.get(chunk_key, [])
	for water_data in water_in_chunk:
		var footprint = water_data.get("footprint", [])
		if footprint.size() >= 3:
			_create_water_mesh(footprint, water_data, chunk_node)

	# Store chunk reference
	active_chunks[chunk_key] = chunk_node

	var total_features = buildings_in_chunk.size() + roads_in_chunk.size() + parks_in_chunk.size() + water_in_chunk.size()
	if total_features > 0:
		print("   📦 Loaded chunk (", chunk_key.x, ",", chunk_key.y, "): ", buildings_in_chunk.size(), " buildings, ", roads_in_chunk.size(), " roads, ", parks_in_chunk.size(), " parks, ", water_in_chunk.size(), " water")

## Unload a chunk (free all nodes in this chunk)
func _unload_chunk(chunk_key: Vector2i):
	if not active_chunks.has(chunk_key):
		return  # Not loaded

	var chunk_node = active_chunks[chunk_key]

	# Safety check: ensure chunk_node is valid
	if not is_instance_valid(chunk_node):
		push_warning("Chunk node invalid during unload: (" + str(chunk_key.x) + "," + str(chunk_key.y) + ")")
		active_chunks.erase(chunk_key)
		return

	# Remove buildings from tracking array
	var buildings_to_remove = []
	for i in range(buildings.size()):
		var building_entry = buildings[i]
		var building_node = building_entry.get("node")

		# Null safety: check if node exists and is valid
		if not building_node or not is_instance_valid(building_node):
			buildings_to_remove.append(i)
			continue

		# Check if this building belongs to this chunk
		var building_parent = building_node.get_parent()
		if building_parent == chunk_node:
			buildings_to_remove.append(i)

	# Remove in reverse order to preserve indices
	buildings_to_remove.reverse()
	for i in buildings_to_remove:
		buildings.remove_at(i)

	# Remove roads from tracking array
	var roads_to_remove = []
	for i in range(roads.size()):
		var road_entry = roads[i]
		var road_node = road_entry.get("node")

		# Null safety: check if node exists and is valid
		if not road_node or not is_instance_valid(road_node):
			roads_to_remove.append(i)
			continue

		# Check if this road belongs to this chunk
		var road_parent = road_node.get_parent()
		if road_parent == chunk_node:
			roads_to_remove.append(i)

	# Remove in reverse order to preserve indices
	roads_to_remove.reverse()
	for i in roads_to_remove:
		roads.remove_at(i)

	# Free the chunk and all its children
	chunk_node.queue_free()
	active_chunks.erase(chunk_key)

## Update chunk streaming (load/unload based on camera position)
func _update_chunk_streaming():
	var camera_pos_2d = Vector2(camera.global_position.x, -camera.global_position.z)

	# Get chunks that should be loaded
	var chunks_to_load = _get_chunks_in_radius(camera_pos_2d, chunk_load_radius)

	# Filter to only new chunks
	var new_chunks = []
	for chunk_key in chunks_to_load:
		if not active_chunks.has(chunk_key):
			new_chunks.append(chunk_key)

	# Sort by distance (load closest first)
	new_chunks.sort_custom(func(a, b):
		var a_center = Vector2(a.x * chunk_size + chunk_size/2, a.y * chunk_size + chunk_size/2)
		var b_center = Vector2(b.x * chunk_size + chunk_size/2, b.y * chunk_size + chunk_size/2)
		return camera_pos_2d.distance_to(a_center) < camera_pos_2d.distance_to(b_center)
	)

	# Load chunks gradually (max_chunks_per_frame at a time)
	var chunks_loaded = 0
	for chunk_key in new_chunks:
		if chunks_loaded >= max_chunks_per_frame:
			break
		_load_chunk(chunk_key)
		chunks_loaded += 1

	# Unload distant chunks
	var chunks_to_unload = []
	for chunk_key in active_chunks.keys():
		var chunk_center = Vector2(chunk_key.x * chunk_size + chunk_size/2, chunk_key.y * chunk_size + chunk_size/2)
		var distance = camera_pos_2d.distance_to(chunk_center)

		if distance > chunk_unload_radius:
			chunks_to_unload.append(chunk_key)

	# Unload gradually (max_chunks_per_frame at a time)
	var chunks_unloaded = 0
	for chunk_key in chunks_to_unload:
		if chunks_unloaded >= max_chunks_per_frame:
			break
		_unload_chunk(chunk_key)
		chunks_unloaded += 1

	# Update chunk visualization if enabled
	if chunk_viz_enabled:
		_update_chunk_visualization()

	# Load large water bodies at extended distance (2x load radius)
	_load_distant_water(camera_pos_2d, chunk_load_radius * 2.0)

## Load large water bodies from distant chunks (lakes should be visible from far away)
func _load_distant_water(camera_pos: Vector2, extended_radius: float):
	var distant_chunks = _get_chunks_in_radius(camera_pos, extended_radius)

	for chunk_key in distant_chunks:
		# Skip chunks that are already fully loaded
		if active_chunks.has(chunk_key):
			continue

		# Load ONLY large water from this distant chunk
		var water_in_chunk = water_data_by_chunk.get(chunk_key, [])
		for water_data in water_in_chunk:
			var footprint = water_data.get("footprint", [])
			if footprint.size() < 3:
				continue

			# Only load LARGE water bodies (lakes, not ponds)
			var area = _calculate_polygon_area(footprint)
			if area > 50000.0:  # Same threshold as in water creation
				var center = water_data.get("center", Vector2.ZERO)
				var water_name = water_data.get("name", "")

				# Check if this specific water body is already rendered
				var water_id = "DistantWater_" + str(chunk_key.x) + "_" + str(chunk_key.y) + "_" + water_name
				if not has_node(NodePath(water_id)):
					var water_node = _create_water_mesh(footprint, water_data, self)
					if water_node:
						water_node.name = water_id

## Update chunk boundary visualization
func _update_chunk_visualization():
	if not chunk_viz_enabled:
		# Clear all visualization nodes
		for viz_node in chunk_viz_nodes.values():
			if is_instance_valid(viz_node):
				viz_node.queue_free()
		chunk_viz_nodes.clear()
		return

	# Remove viz for unloaded chunks
	var viz_to_remove = []
	for chunk_key in chunk_viz_nodes.keys():
		if not active_chunks.has(chunk_key):
			viz_to_remove.append(chunk_key)

	for chunk_key in viz_to_remove:
		var viz_node = chunk_viz_nodes[chunk_key]
		if is_instance_valid(viz_node):
			viz_node.queue_free()
		chunk_viz_nodes.erase(chunk_key)

	# Add viz for new chunks
	for chunk_key in active_chunks.keys():
		if not chunk_viz_nodes.has(chunk_key):
			_create_chunk_visualization(chunk_key)

## Create visualization wireframe for a chunk
func _create_chunk_visualization(chunk_key: Vector2i):
	var viz_node = MeshInstance3D.new()
	viz_node.name = "ChunkViz_%d_%d" % [chunk_key.x, chunk_key.y]

	# Create wireframe box
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(chunk_size, 10.0, chunk_size)  # Tall box for visibility
	viz_node.mesh = box_mesh

	# Wireframe material
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0, 1, 1, 0.3)  # Cyan semi-transparent
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.disable_receive_shadows = true
	viz_node.material_override = material

	# Position at chunk center
	var chunk_center_x = chunk_key.x * chunk_size + chunk_size / 2.0
	var chunk_center_z = chunk_key.y * chunk_size + chunk_size / 2.0
	viz_node.position = Vector3(chunk_center_x, 5.0, -chunk_center_z)  # 5m above ground

	add_child(viz_node)
	chunk_viz_nodes[chunk_key] = viz_node
