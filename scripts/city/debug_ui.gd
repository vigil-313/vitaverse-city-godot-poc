extends Node
class_name DebugUI

## Debug UI Controller
##
## Manages HUD, debug panel (F3), and chunk visualization (F4).
## Displays real-time stats and allows runtime configuration.

const UIHelpers = preload("res://scripts/city/ui_helpers.gd")

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

	var hud_panel = PanelContainer.new()
	hud_panel.position = Vector2(10, 10)
	hud_panel.add_theme_stylebox_override("panel", UIHelpers.create_hud_style())
	canvas.add_child(hud_panel)

	hud_label = UIHelpers.create_label("", 12, Color(0.9, 0.9, 0.9))
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
	debug_panel.add_theme_stylebox_override("panel", UIHelpers.create_panel_style())
	canvas.add_child(debug_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	debug_panel.add_child(vbox)

	# Title
	vbox.add_child(UIHelpers.create_label("DEBUG (F3)", 11, Color(1, 0.9, 0.3)))

	# === MOVEMENT SPEED SECTION ===
	var speed_content = UIHelpers.create_collapsible_section("Movement Speed", vbox, true)
	speed_content.add_child(UIHelpers.create_labeled_input("Multiplier:", "SpeedInput", "1.0", 60))
	var speeds_label = UIHelpers.create_label("Normal: 20 | Fast: 100", 7, Color(0.6, 0.6, 0.6))
	speeds_label.name = "SpeedsLabel"
	speed_content.add_child(speeds_label)

	# === CHUNK STREAMING SECTION ===
	var chunk_content = UIHelpers.create_collapsible_section("Chunk Streaming", vbox, true)
	chunk_content.add_child(UIHelpers.create_labeled_input("Load (m):", "LoadInput", "1000"))
	chunk_content.add_child(UIHelpers.create_labeled_input("Unload (m):", "UnloadInput", "1500"))

	# === INTERIOR LIGHTING SECTION ===
	var lighting_content = UIHelpers.create_collapsible_section("Interior Lighting", vbox, false)
	_build_lighting_controls(lighting_content)

	# Settings buttons
	var settings_btn_hbox = HBoxContainer.new()
	settings_btn_hbox.add_theme_constant_override("separation", 3)
	vbox.add_child(settings_btn_hbox)

	var apply_btn = UIHelpers.create_button("Apply Settings")
	apply_btn.pressed.connect(_on_apply_pressed)
	settings_btn_hbox.add_child(apply_btn)

	var reset_btn = UIHelpers.create_button("Reset")
	reset_btn.pressed.connect(_on_reset_pressed)
	settings_btn_hbox.add_child(reset_btn)

	# Status and stats labels
	var status_label = UIHelpers.create_label("", 7, Color(0.3, 1, 0.3))
	status_label.name = "StatusLabel"
	vbox.add_child(status_label)

	var stats_label = UIHelpers.create_label("", 7, Color(0.7, 0.7, 0.7))
	stats_label.name = "StatsLabel"
	vbox.add_child(stats_label)

## Build the interior lighting controls subsection
func _build_lighting_controls(parent: VBoxContainer):
	# Light Color
	UIHelpers.create_slider_input(parent, "Color R", 0.0, 1.0, 1.0, "ColorR", "ColorRSlider")
	UIHelpers.create_slider_input(parent, "Color G", 0.0, 1.0, 0.95, "ColorG", "ColorGSlider")
	UIHelpers.create_slider_input(parent, "Color B", 0.0, 1.0, 0.85, "ColorB", "ColorBSlider")

	# Light Energy & Range
	UIHelpers.create_slider_input(parent, "Energy", 0.1, 50.0, 10.0, "LightEnergy", "EnergySlider")
	UIHelpers.create_slider_input(parent, "Range (m)", 5.0, 100.0, 40.0, "LightRange", "RangeSlider")

	# Shadows checkbox
	var shadow_hbox = HBoxContainer.new()
	parent.add_child(shadow_hbox)
	var shadow_check = CheckBox.new()
	shadow_check.button_pressed = true
	shadow_check.name = "ShadowsEnabled"
	shadow_check.custom_minimum_size = Vector2(14, 14)
	shadow_hbox.add_child(shadow_check)
	shadow_hbox.add_child(UIHelpers.create_label("Shadows", 7))

	# Shadow parameters
	UIHelpers.create_slider_input(parent, "Shadow Opacity", 0.0, 1.0, 1.0, "ShadowOpacity", "ShadowOpacitySlider")
	UIHelpers.create_slider_input(parent, "Shadow Bias", 0.0, 2.0, 0.1, "ShadowBias", "ShadowBiasSlider")
	UIHelpers.create_slider_input(parent, "Shadow Normal", 0.0, 10.0, 2.0, "ShadowNormalBias", "ShadowNormalSlider")
	UIHelpers.create_slider_input(parent, "Shadow Blur", 0.0, 5.0, 1.5, "ShadowBlur", "ShadowBlurSlider")

	# Buttons
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 3)
	parent.add_child(btn_hbox)

	var apply_btn = UIHelpers.create_button("Apply")
	apply_btn.pressed.connect(_on_apply_lighting_pressed)
	btn_hbox.add_child(apply_btn)

	var save_btn = UIHelpers.create_button("Save")
	save_btn.pressed.connect(_on_save_lighting_config)
	btn_hbox.add_child(save_btn)

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
