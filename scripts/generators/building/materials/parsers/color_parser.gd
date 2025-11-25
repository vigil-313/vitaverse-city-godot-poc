extends Node
class_name ColorParser

## Parses OSM color data (hex, named colors, CSS colors)

## Parse OSM color string to Godot Color
static func parse_osm_color(color_string: String) -> Color:
	if color_string == "" or color_string == "yes":
		return Color.TRANSPARENT

	# Hex colors like "#e8ead4"
	if color_string.begins_with("#"):
		return Color.html(color_string)

	# Try HTML/CSS color name (Godot supports many CSS colors)
	var html_color = Color.from_string(color_string, Color.TRANSPARENT)
	if html_color != Color.TRANSPARENT:
		return html_color

	# Fallback named colors
	match color_string.to_lower():
		"red": return Color.RED
		"blue": return Color.BLUE
		"green": return Color.GREEN
		"white": return Color.WHITE
		"gray", "grey": return Color.GRAY
		"brown": return Color(0.6, 0.4, 0.2)
		"tan": return Color(0.8, 0.7, 0.5)
		"yellow": return Color.YELLOW
		"orange": return Color.ORANGE
		_: return Color.TRANSPARENT
