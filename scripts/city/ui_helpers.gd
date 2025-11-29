class_name UIHelpers

## UI Helper Utilities
##
## Common UI creation patterns extracted from DebugUI.
## Reduces code duplication and simplifies panel construction.

# ========================================================================
# STYLE HELPERS
# ========================================================================

## Create a standard panel style
static func create_panel_style(bg_color: Color = Color(0.1, 0.1, 0.1, 0.85), border_color: Color = Color(0.3, 0.3, 0.3, 0.9)) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

## Create HUD panel style (more transparent)
static func create_hud_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.6)
	style.border_color = Color(0.3, 0.3, 0.3, 0.8)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

# ========================================================================
# CONTROL HELPERS
# ========================================================================

## Create a styled label
static func create_label(text: String, font_size: int = 8, color: Color = Color(0.8, 0.8, 0.8)) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

## Create a styled line edit
static func create_line_edit(default_text: String, name: String, width: float = 45, font_size: int = 8) -> LineEdit:
	var input = LineEdit.new()
	input.text = default_text
	input.custom_minimum_size = Vector2(width, 16)
	input.name = name
	input.add_theme_font_size_override("font_size", font_size)
	return input

## Create a styled button
static func create_button(text: String, font_size: int = 7, min_height: float = 18) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", font_size)
	btn.custom_minimum_size = Vector2(0, min_height)
	return btn

## Create a labeled input row (label + input in HBox)
static func create_labeled_input(label_text: String, input_name: String, default_value: String, label_width: float = 55) -> HBoxContainer:
	var hbox = HBoxContainer.new()

	var label = create_label(label_text)
	label.custom_minimum_size = Vector2(label_width, 0)
	hbox.add_child(label)

	var input = create_line_edit(default_value, input_name)
	hbox.add_child(input)

	return hbox

# ========================================================================
# COLLAPSIBLE SECTION
# ========================================================================

## Create a collapsible section with header and content
## Returns the content VBoxContainer where you add controls
static func create_collapsible_section(section_title: String, parent: VBoxContainer, start_collapsed: bool = false) -> VBoxContainer:
	var section_vbox = VBoxContainer.new()
	section_vbox.add_theme_constant_override("separation", 2)
	parent.add_child(section_vbox)

	var header_hbox = HBoxContainer.new()
	section_vbox.add_child(header_hbox)

	var collapse_btn = Button.new()
	collapse_btn.text = "▶" if start_collapsed else "▼"
	collapse_btn.custom_minimum_size = Vector2(18, 18)
	collapse_btn.add_theme_font_size_override("font_size", 8)
	header_hbox.add_child(collapse_btn)

	var section_label = create_label(section_title, 9)
	header_hbox.add_child(section_label)

	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 2)
	content_vbox.name = section_title.replace(" ", "") + "Content"
	content_vbox.visible = not start_collapsed
	section_vbox.add_child(content_vbox)

	collapse_btn.pressed.connect(func():
		content_vbox.visible = !content_vbox.visible
		collapse_btn.text = "▶" if !content_vbox.visible else "▼"
	)

	return content_vbox

# ========================================================================
# SLIDER + INPUT COMBO
# ========================================================================

## Create a slider with synchronized input field
## Returns Dictionary with "slider" and "input" keys
static func create_slider_input(
	parent: VBoxContainer,
	label_text: String,
	min_val: float,
	max_val: float,
	default_val: float,
	input_name: String,
	slider_name: String
) -> Dictionary:
	var row_vbox = VBoxContainer.new()
	row_vbox.add_theme_constant_override("separation", 1)
	parent.add_child(row_vbox)

	var label_hbox = HBoxContainer.new()
	row_vbox.add_child(label_hbox)

	var label = create_label(label_text, 7)
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

	return {"slider": slider, "input": input}
