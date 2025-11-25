extends Node3D
class_name StreetLamp

## Controls a street lamp's light based on time of day
## Connects to LightingController signal instead of polling every frame

## Class-level debug counter (limit debug output)
static var debug_lamp_count: int = 0
const MAX_DEBUG_LAMPS: int = 3

## Light reference
var spot_light: SpotLight3D
var base_light_energy: float = 20.0  # Maximum energy at night
var should_debug: bool = false  # Only first few lamps print debug

## Initialize lamp (called after script is attached)
func initialize() -> void:
	# Determine if this lamp should print debug
	if debug_lamp_count < MAX_DEBUG_LAMPS:
		should_debug = true
		debug_lamp_count += 1

	# Find the SpotLight3D child using get_node (more reliable than find_child)
	spot_light = get_node_or_null("Light") as SpotLight3D
	if not spot_light:
		push_error("[StreetLamp] No SpotLight3D child named 'Light' found!")
		return

	# Store base energy
	base_light_energy = spot_light.light_energy

	# Find LightingController in the scene tree
	var lighting_controller = _find_lighting_controller()
	if not lighting_controller:
		push_warning("[StreetLamp] Could not find LightingController - light won't respond to time")
		return

	# Connect to time change signal
	if lighting_controller.has_signal("time_of_day_changed"):
		lighting_controller.time_of_day_changed.connect(_on_time_changed)
		if should_debug:
			print("[StreetLamp #", debug_lamp_count, "] Connected to LightingController")
			print("  Position: ", global_position)
			print("  Base energy: ", base_light_energy)

	# Get initial time and update
	var current_time = lighting_controller.current_time
	_on_time_changed(current_time)

## Find LightingController by searching up the tree
func _find_lighting_controller():
	# Try common paths first
	var paths = [
		"/root/Main/LightingController",
		"/root/CityRenderer/LightingController"
	]

	for path in paths:
		var node = get_node_or_null(path)
		if node:
			return node

	# Search recursively from root
	var root = get_tree().root
	return _search_for_type(root, "LightingController")

## Recursively search for node of specific type
func _search_for_type(node: Node, type_name: String):
	if node.get_class() == type_name or (node.get_script() and node.get_script().get_global_name() == type_name):
		return node

	for child in node.get_children():
		var result = _search_for_type(child, type_name)
		if result:
			return result

	return null

## Called when time of day changes
func _on_time_changed(hour: float) -> void:
	if not spot_light:
		return

	# Calculate time fade (matches shader logic)
	var time_fade = _get_time_fade(hour)

	# Update light energy
	var new_energy = base_light_energy * time_fade
	spot_light.light_energy = new_energy

	if should_debug:
		print("[StreetLamp] Time: ", "%.1f" % hour, " | Fade: ", "%.2f" % time_fade, " | Energy: ", "%.1f" % new_energy)

## Calculate fade based on time (mirrors shader logic)
func _get_time_fade(hour: float) -> float:
	if hour >= 19.0 or hour <= 5.0:
		# Night (7pm - 5am): full brightness
		return 1.0
	elif hour > 17.0 and hour < 19.0:
		# Evening transition (5pm - 7pm): fade in
		return (hour - 17.0) / 2.0
	elif hour > 5.0 and hour < 6.0:
		# Morning transition (5am - 6am): fade out
		return 1.0 - (hour - 5.0)
	else:
		# Day (6am - 5pm): off
		return 0.0
