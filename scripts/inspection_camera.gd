extends Camera3D

## Free inspection camera for scale verification
## Controls:
## - Right-click + drag: Rotate camera
## - WASD: Move camera
## - Q/E: Move up/down
## - Mouse scroll: Zoom (change movement speed)

var camera_speed = 10.0
var rotation_speed = 0.005
var zoom_speed = 2.0

var rotating = false
var last_mouse_position = Vector2.ZERO

# HUD elements
var hud_label: Label

func _ready():
	print("📷 Inspection Camera Controls:")
	print("  → Scroll wheel: Zoom in/out toward player")
	print("  → Right-click + drag: Rotate view")
	print("  → WASD: Move camera around")
	print("  → Q/E: Move up/down")
	print("  → Camera centered on player - scroll to zoom in!")

	# Create HUD
	_create_hud()

func _create_hud():
	var canvas = CanvasLayer.new()
	add_child(canvas)

	hud_label = Label.new()
	hud_label.position = Vector2(20, 20)
	hud_label.add_theme_font_size_override("font_size", 16)
	hud_label.add_theme_color_override("font_color", Color(1, 1, 1))
	hud_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hud_label.add_theme_constant_override("outline_size", 2)
	canvas.add_child(hud_label)

func _unhandled_input(event):
	# Mouse rotation - only when right button is held
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		rotating = event.pressed
		if event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			last_mouse_position = get_viewport().get_mouse_position()
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event is InputEventMouseMotion and rotating:
		var delta_mouse = event.relative

		# Rotate camera based on mouse movement
		rotate_y(-delta_mouse.x * rotation_speed)
		rotate_object_local(Vector3.RIGHT, -delta_mouse.y * rotation_speed)

	# Scroll wheel to zoom (move camera forward/backward)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Move camera forward (zoom in)
			position -= transform.basis.z * 0.5
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Move camera backward (zoom out)
			position += transform.basis.z * 0.5

	# Preset views
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1:  # Overview
				position = Vector3(0, 30, 30)
				rotation_degrees = Vector3(-45, 0, 0)
				print("📷 View 1: Overview")
			KEY_2:  # Player close-up
				position = Vector3(-10, 2, 13)
				look_at(Vector3(-10, 1, 10), Vector3.UP)
				print("📷 View 2: Player close-up")
			KEY_3:  # Building close-up
				position = Vector3(25, 5, 10)
				look_at(Vector3(25, 4.5, 0), Vector3.UP)
				print("📷 View 3: Building close-up")
			KEY_4:  # Road view
				position = Vector3(10, 2, 5)
				look_at(Vector3(0, 0, 0), Vector3.UP)
				print("📷 View 4: Road view")
			KEY_5:  # Side view (for height comparison)
				position = Vector3(-20, 5, 10)
				look_at(Vector3(0, 2, 10), Vector3.UP)
				print("📷 View 5: Side view for height comparison")

func _process(delta):
	# WASD movement
	var movement = Vector3.ZERO

	if Input.is_key_pressed(KEY_W):
		movement -= transform.basis.z
	if Input.is_key_pressed(KEY_S):
		movement += transform.basis.z
	if Input.is_key_pressed(KEY_A):
		movement -= transform.basis.x
	if Input.is_key_pressed(KEY_D):
		movement += transform.basis.x
	if Input.is_key_pressed(KEY_Q):
		movement -= transform.basis.y
	if Input.is_key_pressed(KEY_E):
		movement += transform.basis.y

	position += movement.normalized() * camera_speed * delta

	# Update HUD
	_update_hud()

func _update_hud():
	if not hud_label:
		return

	# Get camera direction (forward vector)
	var forward = -transform.basis.z
	var heading_angle = rad_to_deg(atan2(forward.x, forward.z))
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
	var hud_text = ""
	hud_text += "POSITION: (%.1f, %.1f, %.1f)\n" % [position.x, position.y, position.z]
	hud_text += "HEADING: %s (%.0f°)\n" % [compass, heading_angle]
	hud_text += "SPEED: %.1f m/s\n" % camera_speed
	hud_text += "\n"
	hud_text += "TARGETS:\n"
	hud_text += "  Model Boat Pond: (92, 0, -54)\n"
	hud_text += "  Seattle Center: (-965, 0, 458)"

	hud_label.text = hud_text
