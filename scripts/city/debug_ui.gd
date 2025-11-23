extends Node
class_name DebugUI

## Debug UI Controller
##
## Manages HUD, debug panel (F3), and chunk visualization (F4).
## Displays real-time stats and allows runtime configuration.

# ========================================================================
# SIGNALS
# ========================================================================

signal settings_apply_requested(load_radius: float, unload_radius: float, speed_multiplier: float)
signal settings_reset_requested()
signal chunk_viz_toggled(enabled: bool)

# ========================================================================
# STATE
# ========================================================================

## Main HUD label
var hud_label: Label

## Debug panel container
var debug_panel: Control

## Whether debug panel is visible
var debug_visible: bool = false

## Whether chunk visualization is enabled
var chunk_viz_enabled: bool = false

## Chunk visualization nodes
var chunk_viz_nodes: Dictionary = {}  # Vector2i → Node3D

## Reference to scene root for adding viz nodes
var scene_root: Node3D

## Chunk manager reference for visualization
var chunk_manager = null  # ChunkManager instance

# ========================================================================
# INITIALIZATION
# ========================================================================

func setup(parent: Node3D, p_chunk_manager):
	scene_root = parent
	chunk_manager = p_chunk_manager

	_create_hud(parent)
	_create_debug_panel(parent)

	print("🐛 Debug UI created (F3 for panel, F4 for chunk viz)")

# ========================================================================
# HUD
# ========================================================================

func _create_hud(parent: Node3D):
	var canvas = CanvasLayer.new()
	parent.add_child(canvas)

	hud_label = Label.new()
	hud_label.position = Vector2(20, 20)
	hud_label.add_theme_font_size_override("font_size", 14)
	hud_label.add_theme_color_override("font_color", Color(1, 1, 0))  # Yellow
	hud_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hud_label.add_theme_constant_override("outline_size", 2)
	canvas.add_child(hud_label)

	print("📊 HUD created")

func update_hud(camera_pos: Vector3, heading_info: Dictionary, current_speed: float, chunk_stats: Dictionary):
	if not hud_label:
		return

	var hud_text = ""
	hud_text += "POSITION: (%.0f, %.0f, %.0f)\n" % [camera_pos.x, camera_pos.y, camera_pos.z]
	hud_text += "HEADING: %s (%.0f°)\n" % [heading_info["compass"], heading_info["angle"]]
	hud_text += "SPEED: %.0f m/s\n" % current_speed
	hud_text += "\n"
	hud_text += "TARGETS:\n"
	hud_text += "  Lake Union: (319, 0, -1544)\n"
	hud_text += "  Model Boat Pond: (92, 0, -54)\n"
	hud_text += "  Seattle Center: (-965, 0, 458)\n"
	hud_text += "\n"
	hud_text += "Active Chunks: %d | Buildings: %d | Roads: %d\n" % [
		chunk_stats.get("active_chunks", 0),
		chunk_stats.get("buildings", 0),
		chunk_stats.get("roads", 0)
	]
	hud_text += "FPS: %d" % Engine.get_frames_per_second()

	hud_label.text = hud_text

	# Update debug panel stats if visible
	if debug_visible and debug_panel:
		var stats_label = debug_panel.find_child("StatsLabel")
		if stats_label:
			stats_label.text = "Active Chunks: %d\nBuildings: %d\nRoads: %d" % [
				chunk_stats.get("active_chunks", 0),
				chunk_stats.get("buildings", 0),
				chunk_stats.get("roads", 0)
			]

# ========================================================================
# DEBUG PANEL
# ========================================================================

func _create_debug_panel(parent: Node3D):
	var canvas = CanvasLayer.new()
	parent.add_child(canvas)

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

	# Load Radius
	var load_hbox = HBoxContainer.new()
	vbox.add_child(load_hbox)

	var load_label = Label.new()
	load_label.text = "Load Radius (m):"
	load_label.custom_minimum_size = Vector2(120, 0)
	load_hbox.add_child(load_label)

	var load_input = LineEdit.new()
	load_input.text = "1000"
	load_input.custom_minimum_size = Vector2(80, 0)
	load_input.name = "LoadInput"
	load_hbox.add_child(load_input)

	# Unload Radius
	var unload_hbox = HBoxContainer.new()
	vbox.add_child(unload_hbox)

	var unload_label = Label.new()
	unload_label.text = "Unload Radius (m):"
	unload_label.custom_minimum_size = Vector2(120, 0)
	unload_hbox.add_child(unload_label)

	var unload_input = LineEdit.new()
	unload_input.text = "1500"
	unload_input.custom_minimum_size = Vector2(80, 0)
	unload_input.name = "UnloadInput"
	unload_hbox.add_child(unload_input)

	# Chunk Size (Read-only)
	var size_hbox = HBoxContainer.new()
	vbox.add_child(size_hbox)

	var size_label = Label.new()
	size_label.text = "Chunk Size: 500m (fixed)"
	size_label.custom_minimum_size = Vector2(250, 0)
	size_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	size_hbox.add_child(size_label)

	# Buttons
	var apply_button = Button.new()
	apply_button.text = "Apply Changes"
	apply_button.pressed.connect(_on_apply_pressed)
	vbox.add_child(apply_button)

	var reset_button = Button.new()
	reset_button.text = "Reset to Defaults"
	reset_button.pressed.connect(_on_reset_pressed)
	vbox.add_child(reset_button)

	# Status
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

func _on_apply_pressed():
	var load_input = debug_panel.find_child("LoadInput", true, false) as LineEdit
	var unload_input = debug_panel.find_child("UnloadInput", true, false) as LineEdit
	var speed_input = debug_panel.find_child("SpeedInput", true, false) as LineEdit

	if load_input and unload_input and speed_input:
		settings_apply_requested.emit(
			load_input.text.to_float(),
			unload_input.text.to_float(),
			speed_input.text.to_float()
		)

func _on_reset_pressed():
	settings_reset_requested.emit()

func update_speeds_display(normal_speed: float, fast_speed: float):
	if debug_panel:
		var speeds_label = debug_panel.find_child("SpeedsLabel", true, false) as Label
		if speeds_label:
			speeds_label.text = "Normal: " + str(int(normal_speed)) + " m/s | Fast: " + str(int(fast_speed)) + " m/s"

func show_status(message: String, is_error: bool = false):
	if debug_panel:
		var status_label = debug_panel.find_child("StatusLabel", true, false) as Label
		if status_label:
			status_label.text = message
			var color = Color(1, 0, 0) if is_error else Color(0, 1, 0)
			status_label.add_theme_color_override("font_color", color)

# ========================================================================
# INPUT HANDLING
# ========================================================================

func handle_input(event: InputEvent):
	if event is InputEventKey:
		# F3 to toggle debug panel
		if event.keycode == KEY_F3 and event.pressed:
			debug_visible = not debug_visible
			if debug_panel:
				debug_panel.visible = debug_visible

		# F4 to toggle chunk visualization
		if event.keycode == KEY_F4 and event.pressed:
			chunk_viz_enabled = not chunk_viz_enabled
			update_chunk_visualization()
			chunk_viz_toggled.emit(chunk_viz_enabled)
			print("🔲 Chunk visualization: ", "ON" if chunk_viz_enabled else "OFF")

# ========================================================================
# CHUNK VISUALIZATION
# ========================================================================

func update_chunk_visualization():
	if not chunk_viz_enabled or not chunk_manager:
		# Clear all visualization nodes
		for viz_node in chunk_viz_nodes.values():
			if is_instance_valid(viz_node):
				viz_node.queue_free()
		chunk_viz_nodes.clear()
		return

	var active_chunks = chunk_manager.active_chunks

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

func _create_chunk_visualization(chunk_key: Vector2i):
	if not chunk_manager:
		return

	var chunk_size = chunk_manager.chunk_size

	var viz_node = MeshInstance3D.new()
	viz_node.name = "ChunkViz_%d_%d" % [chunk_key.x, chunk_key.y]

	# Create wireframe box
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(chunk_size, 10.0, chunk_size)
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
	viz_node.position = Vector3(chunk_center_x, 5.0, -chunk_center_z)

	scene_root.add_child(viz_node)
	chunk_viz_nodes[chunk_key] = viz_node
