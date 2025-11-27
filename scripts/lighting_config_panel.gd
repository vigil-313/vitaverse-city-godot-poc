extends Panel
class_name LightingConfigPanel

## Collapsible debug menu for real-time light parameter adjustment

# Light parameter defaults (matching ceiling_light_generator.gd)
var light_color := Color(1.0, 0.95, 0.85)  # Warm white
var light_energy := 10.0
var light_range := 40.0
var shadow_opacity := 1.0
var shadow_bias := 0.1
var shadow_normal_bias := 2.0
var shadow_blur := 1.5
var shadows_enabled := true

# UI controls
var color_picker: ColorPickerButton
var energy_slider: HSlider
var range_slider: HSlider
var shadow_opacity_slider: HSlider
var shadow_bias_slider: HSlider
var shadow_normal_bias_slider: HSlider
var shadow_blur_slider: HSlider
var shadows_checkbox: CheckBox
var collapse_button: Button
var content_container: VBoxContainer

var is_collapsed := false

func _ready():
	# Panel setup
	custom_minimum_size = Vector2(320, 0)

	# Create main container
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(main_vbox)

	# Header with collapse button
	var header = HBoxContainer.new()
	main_vbox.add_child(header)

	var title = Label.new()
	title.text = "Lighting Config"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	collapse_button = Button.new()
	collapse_button.text = "▼"
	collapse_button.custom_minimum_size = Vector2(30, 30)
	collapse_button.pressed.connect(_on_collapse_toggled)
	header.add_child(collapse_button)

	# Content container (collapsible)
	content_container = VBoxContainer.new()
	content_container.add_theme_constant_override("separation", 8)
	main_vbox.add_child(content_container)

	# Add separator
	var separator = HSeparator.new()
	content_container.add_child(separator)

	# Color picker
	_add_color_control()

	# Energy/Brightness slider
	_add_slider_control("Brightness", 0.1, 50.0, 0.1, light_energy, func(value):
		light_energy = value
		_update_all_lights()
	)

	# Range slider
	_add_slider_control("Range", 5.0, 100.0, 1.0, light_range, func(value):
		light_range = value
		_update_all_lights()
	)

	# Shadow controls section
	var shadow_label = Label.new()
	shadow_label.text = "Shadow Settings"
	shadow_label.add_theme_font_size_override("font_size", 14)
	content_container.add_child(shadow_label)

	# Shadows enabled checkbox
	var shadow_hbox = HBoxContainer.new()
	content_container.add_child(shadow_hbox)

	var shadow_check_label = Label.new()
	shadow_check_label.text = "Shadows Enabled"
	shadow_check_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shadow_hbox.add_child(shadow_check_label)

	shadows_checkbox = CheckBox.new()
	shadows_checkbox.button_pressed = shadows_enabled
	shadows_checkbox.toggled.connect(func(pressed):
		shadows_enabled = pressed
		_update_all_lights()
	)
	shadow_hbox.add_child(shadows_checkbox)

	# Shadow opacity slider
	_add_slider_control("Shadow Opacity", 0.0, 1.0, 0.05, shadow_opacity, func(value):
		shadow_opacity = value
		_update_all_lights()
	)

	# Shadow bias slider
	_add_slider_control("Shadow Bias", 0.0, 2.0, 0.05, shadow_bias, func(value):
		shadow_bias = value
		_update_all_lights()
	)

	# Shadow normal bias slider
	_add_slider_control("Shadow Normal Bias", 0.0, 5.0, 0.1, shadow_normal_bias, func(value):
		shadow_normal_bias = value
		_update_all_lights()
	)

	# Shadow blur slider
	_add_slider_control("Shadow Blur", 0.0, 5.0, 0.1, shadow_blur, func(value):
		shadow_blur = value
		_update_all_lights()
	)

	# Apply button
	var apply_button = Button.new()
	apply_button.text = "Apply to All Lights"
	apply_button.pressed.connect(_update_all_lights)
	content_container.add_child(apply_button)

	# Stats label
	var stats = Label.new()
	stats.text = "Lights will update in real-time"
	stats.add_theme_font_size_override("font_size", 10)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_container.add_child(stats)

func _add_color_control():
	var hbox = HBoxContainer.new()
	content_container.add_child(hbox)

	var label = Label.new()
	label.text = "Light Color"
	label.custom_minimum_size = Vector2(120, 0)
	hbox.add_child(label)

	color_picker = ColorPickerButton.new()
	color_picker.color = light_color
	color_picker.edit_alpha = false
	color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_picker.color_changed.connect(func(new_color):
		light_color = new_color
		_update_all_lights()
	)
	hbox.add_child(color_picker)

func _add_slider_control(label_text: String, min_val: float, max_val: float, step: float, default_val: float, callback: Callable):
	var hbox = HBoxContainer.new()
	content_container.add_child(hbox)

	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(120, 0)
	hbox.add_child(label)

	var slider = HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.value = default_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(120, 0)
	hbox.add_child(slider)

	var value_label = Label.new()
	value_label.text = "%.2f" % default_val
	value_label.custom_minimum_size = Vector2(50, 0)
	hbox.add_child(value_label)

	slider.value_changed.connect(func(value):
		value_label.text = "%.2f" % value
		callback.call(value)
	)

func _on_collapse_toggled():
	is_collapsed = !is_collapsed
	content_container.visible = !is_collapsed
	collapse_button.text = "▲" if is_collapsed else "▼"

	if is_collapsed:
		custom_minimum_size = Vector2(320, 50)
	else:
		custom_minimum_size = Vector2(320, 0)

func _update_all_lights():
	# Find all interior light proxies in the scene
	var root = get_tree().root
	var proxies = _find_all_light_proxies(root)

	print("Updating ", proxies.size(), " interior light proxies...")

	for proxy in proxies:
		# Update proxy base parameters
		proxy.base_color = light_color
		proxy.base_energy = light_energy
		proxy.base_range = light_range

		# Update the actual OmniLight3D if it exists (NEAR/MID tier)
		if proxy.omni_light:
			proxy.omni_light.light_color = light_color
			proxy.omni_light.omni_range = light_range
			proxy.omni_light.shadow_enabled = shadows_enabled and (proxy.current_tier == 0)  # NEAR only
			proxy.omni_light.shadow_opacity = shadow_opacity
			proxy.omni_light.shadow_bias = shadow_bias
			proxy.omni_light.shadow_normal_bias = shadow_normal_bias
			proxy.omni_light.shadow_blur = shadow_blur
			# Recalculate energy with time fade
			var tier_mult = 1.0 if proxy.current_tier == 0 else 0.85
			proxy.omni_light.light_energy = light_energy * tier_mult * proxy.time_fade

func _find_all_light_proxies(node: Node) -> Array:
	var proxies = []

	# Check if this node is a LODLightProxy (by name pattern)
	if node.name.begins_with("InteriorLight_"):
		proxies.append(node)

	# Recursively search children
	for child in node.get_children():
		proxies.append_array(_find_all_light_proxies(child))

	return proxies
