extends Camera3D

## Simple third-person camera that follows the player
var player: Node3D = null
var camera_distance = 3.0  # Distance behind player
var camera_height = 1.5    # Height above player

func _ready():
	# Find the player node
	player = get_parent().get_node("Player")
	if player:
		print("📷 Third-person camera following player")
		print("  → Use mouse scroll to adjust camera distance")
	else:
		print("ERROR: Could not find Player node!")

func _process(_delta):
	if not player:
		return

	# Position camera behind and above the player
	var player_pos = player.global_position
	position = Vector3(player_pos.x - camera_distance, player_pos.y + camera_height, player_pos.z)

	# Look at the player
	look_at(player_pos + Vector3(0, 1, 0), Vector3.UP)

func _unhandled_input(event):
	# Scroll wheel to adjust camera distance
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = max(camera_distance - 0.5, 1.0)
			print("Camera distance: ", camera_distance)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = min(camera_distance + 0.5, 10.0)
			print("Camera distance: ", camera_distance)
