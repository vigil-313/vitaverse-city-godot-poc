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

## Visual manager reference for visual controls
var visual_manager = null  # VisualManager instance

## Lighting LOD manager reference for stats
var lighting_lod_manager = null  # LightingLODManager instance

# ========================================================================
# INITIALIZATION
# ========================================================================

func setup(parent: Node3D, p_chunk_manager, p_visual_manager = null, p_lighting_lod_manager = null):
	scene_root = parent
	chunk_manager = p_chunk_manager
	visual_manager = p_visual_manager
	lighting_lod_manager = p_lighting_lod_manager

	_create_hud(parent)
	_create_debug_panel(parent)

	print("🐛 Debug UI created (F3 for panel, F4 for chunk viz, F5/F6 for visuals)")

# ========================================================================
# HUD
# ========================================================================

func _create_hud(parent: Node3D):
	var canvas = CanvasLayer.new()
	parent.add_child(canvas)

	# Create background panel
	var hud_panel = PanelContainer.new()
	hud_panel.position = Vector2(10, 10)
	canvas.add_child(hud_panel)

	# Style the panel with translucent background
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0, 0, 0, 0.6)  # Black with 60% opacity
	style_box.border_color = Color(0.3, 0.3, 0.3, 0.8)
	style_box.border_width_left = 1
	style_box.border_width_right = 1
	style_box.border_width_top = 1
	style_box.border_width_bottom = 1
	style_box.corner_radius_top_left = 4
	style_box.corner_radius_top_right = 4
	style_box.corner_radius_bottom_left = 4
	style_box.corner_radius_bottom_right = 4
	style_box.content_margin_left = 8
	style_box.content_margin_right = 8
	style_box.content_margin_top = 6
	style_box.content_margin_bottom = 6
	hud_panel.add_theme_stylebox_override("panel", style_box)

	hud_label = Label.new()
	hud_label.add_theme_font_size_override("font_size", 12)  # Smaller font
	hud_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))  # Light gray instead of yellow
	hud_panel.add_child(hud_label)

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
	hud_text += "FPS: %d\n" % Engine.get_frames_per_second()

	# Light LOD stats
	if lighting_lod_manager:
		var lod_stats = lighting_lod_manager.get_stats()
		hud_text += "Lights: %d/%d active (%d shadowed) | NEAR:%d MID:%d FAR:%d\n" % [
			lod_stats.get("active_count", 0),
			lod_stats.get("total_registered", 0),
			lod_stats.get("shadowed_count", 0),
			lod_stats.get("near_count", 0),
			lod_stats.get("mid_count", 0),
			lod_stats.get("far_count", 0)
		]

	# Visual system info
	if visual_manager:
		hud_text += "\n"
		hud_text += "VISUALS (F5=Preset F6=Time F7=Style+):\n"
		hud_text += "  Preset: %s\n" % visual_manager.current_preset
		if visual_manager.lighting_controller:
			var time = visual_manager.lighting_controller.current_time
			var weather = visual_manager.lighting_controller.Weather.keys()[visual_manager.lighting_controller.current_weather]
			hud_text += "  Time: %.1fh (%s) | Weather: %s\n" % [time, _get_time_label(time), weather]
		hud_text += "  Stylization: %.0f%%" % (visual_manager.stylization_blend * 100)

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
	debug_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	debug_panel.position = Vector2(-10, 10)
	debug_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	debug_panel.visible = false
	canvas.add_child(debug_panel)

	# Style the panel
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	style_box.border_color = Color(0.3, 0.3, 0.3, 0.9)
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.corner_radius_top_left = 6
	style_box.corner_radius_top_right = 6
	style_box.corner_radius_bottom_left = 6
	style_box.corner_radius_bottom_right = 6
	style_box.content_margin_left = 10
	style_box.content_margin_right = 10
	style_box.content_margin_top = 8
	style_box.content_margin_bottom = 8
	debug_panel.add_theme_stylebox_override("panel", style_box)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	debug_panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "DEBUG (F3)"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	vbox.add_child(title)

	# Helper to create collapsible section
	var create_collapsible_section = func(section_title: String, container: VBoxContainer):
		var section_vbox = VBoxContainer.new()
		section_vbox.add_theme_constant_override("separation", 2)
		container.add_child(section_vbox)

		var header_hbox = HBoxContainer.new()
		section_vbox.add_child(header_hbox)

		var collapse_btn = Button.new()
		collapse_btn.text = "▼"
		collapse_btn.custom_minimum_size = Vector2(18, 18)
		collapse_btn.add_theme_font_size_override("font_size", 8)
		header_hbox.add_child(collapse_btn)

		var section_label = Label.new()
		section_label.text = section_title
		section_label.add_theme_font_size_override("font_size", 9)
		section_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		header_hbox.add_child(section_label)

		var content_vbox = VBoxContainer.new()
		content_vbox.add_theme_constant_override("separation", 2)
		content_vbox.name = section_title.replace(" ", "") + "Content"
		section_vbox.add_child(content_vbox)

		collapse_btn.pressed.connect(func():
			content_vbox.visible = !content_vbox.visible
			collapse_btn.text = "▶" if !content_vbox.visible else "▼"
		)

		return content_vbox

	# === MOVEMENT SPEED SECTION ===
	var speed_content = create_collapsible_section.call("Movement Speed", vbox)
	speed_content.visible = false  # Start collapsed

	var speed_hbox = HBoxContainer.new()
	speed_content.add_child(speed_hbox)

	var speed_label = Label.new()
	speed_label.text = "Multiplier:"
	speed_label.custom_minimum_size = Vector2(60, 0)
	speed_label.add_theme_font_size_override("font_size", 8)
	speed_hbox.add_child(speed_label)

	var speed_input = LineEdit.new()
	speed_input.text = "1.0"
	speed_input.custom_minimum_size = Vector2(40, 16)
	speed_input.name = "SpeedInput"
	speed_input.add_theme_font_size_override("font_size", 8)
	speed_hbox.add_child(speed_input)

	var speeds_label = Label.new()
	speeds_label.text = "Normal: 20 | Fast: 100"
	speeds_label.name = "SpeedsLabel"
	speeds_label.add_theme_font_size_override("font_size", 7)
	speeds_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	speed_content.add_child(speeds_label)

	# === CHUNK STREAMING SECTION ===
	var chunk_content = create_collapsible_section.call("Chunk Streaming", vbox)
	chunk_content.visible = false  # Start collapsed

	# Load Radius
	var load_hbox = HBoxContainer.new()
	chunk_content.add_child(load_hbox)

	var load_label = Label.new()
	load_label.text = "Load (m):"
	load_label.custom_minimum_size = Vector2(55, 0)
	load_label.add_theme_font_size_override("font_size", 8)
	load_hbox.add_child(load_label)

	var load_input = LineEdit.new()
	load_input.text = "1000"
	load_input.custom_minimum_size = Vector2(45, 16)
	load_input.name = "LoadInput"
	load_input.add_theme_font_size_override("font_size", 8)
	load_hbox.add_child(load_input)

	# Unload Radius
	var unload_hbox = HBoxContainer.new()
	chunk_content.add_child(unload_hbox)

	var unload_label = Label.new()
	unload_label.text = "Unload (m):"
	unload_label.custom_minimum_size = Vector2(55, 0)
	unload_label.add_theme_font_size_override("font_size", 8)
	unload_hbox.add_child(unload_label)

	var unload_input = LineEdit.new()
	unload_input.text = "1500"
	unload_input.custom_minimum_size = Vector2(45, 16)
	unload_input.name = "UnloadInput"
	unload_input.add_theme_font_size_override("font_size", 8)
	unload_hbox.add_child(unload_input)

	# === INTERIOR LIGHTING SECTION ===
	var lighting_content = create_collapsible_section.call("Interior Lighting", vbox)

	# Helper for slider + input pairs
	var create_slider_input = func(parent: VBoxContainer, label_text: String, min_val: float, max_val: float, default_val: float, input_name: String, slider_name: String):
		var row_vbox = VBoxContainer.new()
		row_vbox.add_theme_constant_override("separation", 1)
		parent.add_child(row_vbox)

		var label_hbox = HBoxContainer.new()
		row_vbox.add_child(label_hbox)

		var label = Label.new()
		label.text = label_text
		label.add_theme_font_size_override("font_size", 7)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label_hbox.add_child(label)

		var input = LineEdit.new()
		input.text = str(default_val)
		input.custom_minimum_size = Vector2(35, 14)
		input.name = input_name
		input.add_theme_font_size_override("font_size", 7)
		label_hbox.add_child(input)

		var slider = HSlider.new()
		slider.min_value = min_val
		slider.max_value = max_val
		slider.value = default_val
		slider.step = (max_val - min_val) / 100.0
		slider.custom_minimum_size = Vector2(0, 12)
		slider.name = slider_name
		row_vbox.add_child(slider)

		# Sync slider and input
		slider.value_changed.connect(func(val): input.text = "%.2f" % val)
		input.text_changed.connect(func(text):
			var val = text.to_float()
			if val >= min_val and val <= max_val:
				slider.value = val
		)

	# Light Color
	create_slider_input.call(lighting_content, "Color R", 0.0, 1.0, 1.0, "ColorR", "ColorRSlider")
	create_slider_input.call(lighting_content, "Color G", 0.0, 1.0, 0.95, "ColorG", "ColorGSlider")
	create_slider_input.call(lighting_content, "Color B", 0.0, 1.0, 0.85, "ColorB", "ColorBSlider")

	# Light Energy & Range
	create_slider_input.call(lighting_content, "Energy", 0.1, 50.0, 10.0, "LightEnergy", "EnergySlider")
	create_slider_input.call(lighting_content, "Range (m)", 5.0, 100.0, 40.0, "LightRange", "RangeSlider")

	# Shadows checkbox
	var shadow_hbox = HBoxContainer.new()
	lighting_content.add_child(shadow_hbox)
	var shadow_check = CheckBox.new()
	shadow_check.button_pressed = true
	shadow_check.name = "ShadowsEnabled"
	shadow_check.custom_minimum_size = Vector2(14, 14)
	shadow_hbox.add_child(shadow_check)
	var shadow_label = Label.new()
	shadow_label.text = "Shadows"
	shadow_label.add_theme_font_size_override("font_size", 7)
	shadow_hbox.add_child(shadow_label)

	# Shadow parameters
	create_slider_input.call(lighting_content, "Shadow Opacity", 0.0, 1.0, 1.0, "ShadowOpacity", "ShadowOpacitySlider")
	create_slider_input.call(lighting_content, "Shadow Bias", 0.0, 2.0, 0.1, "ShadowBias", "ShadowBiasSlider")
	create_slider_input.call(lighting_content, "Shadow Normal", 0.0, 10.0, 2.0, "ShadowNormalBias", "ShadowNormalSlider")
	create_slider_input.call(lighting_content, "Shadow Blur", 0.0, 5.0, 1.5, "ShadowBlur", "ShadowBlurSlider")

	# Buttons
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 3)
	lighting_content.add_child(btn_hbox)

	var apply_btn = Button.new()
	apply_btn.text = "Apply"
	apply_btn.add_theme_font_size_override("font_size", 7)
	apply_btn.custom_minimum_size = Vector2(0, 18)
	apply_btn.pressed.connect(_on_apply_lighting_pressed)
	btn_hbox.add_child(apply_btn)

	var save_btn = Button.new()
	save_btn.text = "Save"
	save_btn.add_theme_font_size_override("font_size", 7)
	save_btn.custom_minimum_size = Vector2(0, 18)
	save_btn.pressed.connect(_on_save_lighting_config)
	btn_hbox.add_child(save_btn)

	# Add apply/reset buttons for speed/chunk settings
	var settings_btn_hbox = HBoxContainer.new()
	settings_btn_hbox.add_theme_constant_override("separation", 3)
	vbox.add_child(settings_btn_hbox)

	var apply_settings_btn = Button.new()
	apply_settings_btn.text = "Apply Settings"
	apply_settings_btn.add_theme_font_size_override("font_size", 7)
	apply_settings_btn.custom_minimum_size = Vector2(0, 18)
	apply_settings_btn.pressed.connect(_on_apply_pressed)
	settings_btn_hbox.add_child(apply_settings_btn)

	var reset_btn = Button.new()
	reset_btn.text = "Reset"
	reset_btn.add_theme_font_size_override("font_size", 7)
	reset_btn.custom_minimum_size = Vector2(0, 18)
	reset_btn.pressed.connect(_on_reset_pressed)
	settings_btn_hbox.add_child(reset_btn)

	# Status
	var status_label = Label.new()
	status_label.text = ""
	status_label.name = "StatusLabel"
	status_label.add_theme_font_size_override("font_size", 7)
	status_label.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
	vbox.add_child(status_label)

	# Stats
	var stats_label = Label.new()
	stats_label.text = ""
	stats_label.name = "StatsLabel"
	stats_label.add_theme_font_size_override("font_size", 7)
	stats_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
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

func _on_apply_lighting_pressed():
	# Get all inputs
	var color_r = (debug_panel.find_child("ColorR", true, false) as LineEdit).text.to_float()
	var color_g = (debug_panel.find_child("ColorG", true, false) as LineEdit).text.to_float()
	var color_b = (debug_panel.find_child("ColorB", true, false) as LineEdit).text.to_float()
	var energy = (debug_panel.find_child("LightEnergy", true, false) as LineEdit).text.to_float()
	var range_val = (debug_panel.find_child("LightRange", true, false) as LineEdit).text.to_float()
	var shadows_enabled = (debug_panel.find_child("ShadowsEnabled", true, false) as CheckBox).button_pressed
	var shadow_opacity = (debug_panel.find_child("ShadowOpacity", true, false) as LineEdit).text.to_float()
	var shadow_bias = (debug_panel.find_child("ShadowBias", true, false) as LineEdit).text.to_float()
	var shadow_normal_bias = (debug_panel.find_child("ShadowNormalBias", true, false) as LineEdit).text.to_float()
	var shadow_blur = (debug_panel.find_child("ShadowBlur", true, false) as LineEdit).text.to_float()

	var light_color = Color(color_r, color_g, color_b)

	# Find all LODLightProxy instances (interior lights)
	var proxies = _find_all_light_proxies(scene_root)
	print("💡 Updating ", proxies.size(), " interior light proxies...")

	for proxy in proxies:
		# Update proxy base parameters
		proxy.base_color = light_color
		proxy.base_energy = energy
		proxy.base_range = range_val

		# Update the actual OmniLight3D if it exists (NEAR/MID tier)
		if proxy.omni_light:
			proxy.omni_light.light_color = light_color
			proxy.omni_light.omni_range = range_val
			proxy.omni_light.shadow_enabled = shadows_enabled and (proxy.current_tier == 0)
			proxy.omni_light.shadow_opacity = shadow_opacity
			proxy.omni_light.shadow_bias = shadow_bias
			proxy.omni_light.shadow_normal_bias = shadow_normal_bias
			proxy.omni_light.shadow_blur = shadow_blur
			# Recalculate energy with time fade
			var tier_mult = 1.0 if proxy.current_tier == 0 else 0.85
			proxy.omni_light.light_energy = energy * tier_mult * proxy.time_fade

	show_status("✓ Updated %d lights" % proxies.size())

func _on_save_lighting_config():
	# Get all current values
	var color_r = (debug_panel.find_child("ColorR", true, false) as LineEdit).text
	var color_g = (debug_panel.find_child("ColorG", true, false) as LineEdit).text
	var color_b = (debug_panel.find_child("ColorB", true, false) as LineEdit).text
	var energy = (debug_panel.find_child("LightEnergy", true, false) as LineEdit).text
	var range_val = (debug_panel.find_child("LightRange", true, false) as LineEdit).text
	var shadows_enabled = (debug_panel.find_child("ShadowsEnabled", true, false) as CheckBox).button_pressed
	var shadow_opacity = (debug_panel.find_child("ShadowOpacity", true, false) as LineEdit).text
	var shadow_bias = (debug_panel.find_child("ShadowBias", true, false) as LineEdit).text
	var shadow_normal_bias = (debug_panel.find_child("ShadowNormalBias", true, false) as LineEdit).text
	var shadow_blur = (debug_panel.find_child("ShadowBlur", true, false) as LineEdit).text

	# Print config in copy-pasteable format
	print("\n" + "=".repeat(60))
	print("INTERIOR LIGHTING CONFIG - Copy to ceiling_light_generator.gd")
	print("=".repeat(60))
	print("light.light_color = Color(%s, %s, %s)" % [color_r, color_g, color_b])
	print("light.light_energy = %s" % energy)
	print("light.omni_range = %s" % range_val)
	print("light.shadow_enabled = %s" % str(shadows_enabled).to_lower())
	print("light.shadow_opacity = %s" % shadow_opacity)
	print("light.shadow_bias = %s" % shadow_bias)
	print("light.shadow_normal_bias = %s" % shadow_normal_bias)
	print("light.shadow_blur = %s" % shadow_blur)
	print("=".repeat(60) + "\n")

	show_status("✓ Config saved to console")

func _find_all_light_proxies(node: Node) -> Array:
	var proxies = []

	# Check if this node is a LODLightProxy (by name pattern)
	if node.name.begins_with("InteriorLight_"):
		proxies.append(node)

	# Recursively search children
	for child in node.get_children():
		proxies.append_array(_find_all_light_proxies(child))

	return proxies

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

		# Visual system controls
		if visual_manager:
			# F5: Cycle through presets
			if event.keycode == KEY_F5 and event.pressed:
				_cycle_visual_preset()

			# F6: Change time of day (+2 hours)
			if event.keycode == KEY_F6 and event.pressed:
				_change_time_of_day(2.0)

			# F7: Increase stylization
			if event.keycode == KEY_F7 and event.pressed:
				_adjust_stylization(0.1)

			# F8: Decrease stylization
			if event.keycode == KEY_F8 and event.pressed:
				_adjust_stylization(-0.1)

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

# ========================================================================
# VISUAL SYSTEM CONTROLS
# ========================================================================

func _cycle_visual_preset():
	if not visual_manager or not visual_manager.environment_presets:
		return

	var presets = visual_manager.environment_presets.get_builtin_preset_names()
	var current_index = presets.find(visual_manager.current_preset)
	var next_index = (current_index + 1) % presets.size()
	var next_preset = presets[next_index]

	visual_manager.apply_preset(next_preset)
	print("🎨 Visual Preset: ", next_preset)

func _change_time_of_day(hours_delta: float):
	if not visual_manager or not visual_manager.lighting_controller:
		return

	var new_time = visual_manager.lighting_controller.current_time + hours_delta
	visual_manager.set_time_of_day(new_time)
	print("⏰ Time: %.1fh (%s)" % [visual_manager.lighting_controller.current_time, _get_time_label(visual_manager.lighting_controller.current_time)])

func _adjust_stylization(delta: float):
	if not visual_manager:
		return

	var new_value = clamp(visual_manager.stylization_blend + delta, 0.0, 1.0)
	visual_manager.set_stylization_blend(new_value)
	print("✨ Stylization: %.0f%%" % (new_value * 100))

func _get_time_label(hour: float) -> String:
	var h = int(hour) % 24
	if h >= 5 and h < 7:
		return "Dawn"
	elif h >= 7 and h < 11:
		return "Morning"
	elif h >= 11 and h < 14:
		return "Noon"
	elif h >= 14 and h < 17:
		return "Afternoon"
	elif h >= 17 and h < 19:
		return "Sunset"
	elif h >= 19 and h < 22:
		return "Dusk"
	else:
		return "Night"
