extends Node
class_name CameraController

## Camera Controller
##
## Handles camera movement, rotation, and input.
## Emits signals when camera position changes for chunk streaming.

# ========================================================================
# SIGNALS
# ========================================================================

signal camera_moved(position: Vector3)
signal camera_speed_changed(normal_speed: float, fast_speed: float)

# ========================================================================
# CONFIGURATION
# ========================================================================

## Normal movement speed (m/s)
var camera_speed: float = 20.0

## Fast movement speed with Shift (m/s)
var camera_fast_speed: float = 100.0

## Mouse sensitivity for camera rotation
var camera_sensitivity: float = 0.002

# ========================================================================
# STATE
# ========================================================================

## The camera node
var camera: Camera3D

## Camera rotation (euler angles)
var camera_rotation: Vector2 = Vector2.ZERO

## Whether mouse is captured for rotation
var mouse_captured: bool = false

# ========================================================================
# INITIALIZATION
# ========================================================================

func setup_camera(parent: Node, start_position: Vector3) -> Camera3D:
	"""
	Creates and configures the camera.
	Parent can be CityRenderer (Node3D) or SubViewport (Viewport).
	"""
	camera = Camera3D.new()
	parent.add_child(camera)

	# Position camera
	camera.position = start_position
	camera.look_at(Vector3(start_position.x, 0, start_position.z), Vector3.UP)
	camera.fov = 70

	# Initialize camera rotation to match current orientation
	camera_rotation = Vector2(camera.rotation.x, camera.rotation.y)

	print("📷 Camera positioned at: ", camera.position)

	return camera

# ========================================================================
# UPDATE LOOP
# ========================================================================

func update(delta: float):
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
		var old_pos = camera.global_position
		camera.global_position += input_dir * speed * delta

		# Emit signal if position changed significantly
		if old_pos.distance_to(camera.global_position) > 0.1:
			camera_moved.emit(camera.global_position)

# ========================================================================
# INPUT HANDLING
# ========================================================================

func handle_input(event: InputEvent):
	# Right-click to capture mouse
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				mouse_captured = true
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				mouse_captured = false

		# Scroll wheel to adjust speed
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera_speed = min(camera_speed + 5.0, 100.0)
			camera_fast_speed = min(camera_fast_speed + 20.0, 300.0)
			print("Camera speed: ", camera_speed, "m/s (Shift: ", camera_fast_speed, "m/s)")
			camera_speed_changed.emit(camera_speed, camera_fast_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera_speed = max(camera_speed - 5.0, 5.0)
			camera_fast_speed = max(camera_fast_speed - 20.0, 20.0)
			print("Camera speed: ", camera_speed, "m/s (Shift: ", camera_fast_speed, "m/s)")
			camera_speed_changed.emit(camera_speed, camera_fast_speed)

	# ESC to release mouse
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE and event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			mouse_captured = false

	# Mouse movement for camera rotation
	if event is InputEventMouseMotion and mouse_captured:
		camera_rotation.x -= event.relative.y * camera_sensitivity
		camera_rotation.y -= event.relative.x * camera_sensitivity

		# Clamp vertical rotation to avoid flipping
		camera_rotation.x = clamp(camera_rotation.x, -PI/2, PI/2)

		# Apply rotation to camera
		if camera:
			camera.rotation.x = camera_rotation.x
			camera.rotation.y = camera_rotation.y

# ========================================================================
# UTILITY
# ========================================================================

## Set camera speeds (used by debug UI)
func set_speeds(speed_multiplier: float):
	var base_speed = 20.0
	var base_fast_speed = 100.0
	camera_speed = base_speed * speed_multiplier
	camera_fast_speed = base_fast_speed * speed_multiplier
	camera_speed_changed.emit(camera_speed, camera_fast_speed)

## Get current camera heading
func get_heading_info() -> Dictionary:
	if not camera:
		return {"angle": 0.0, "compass": "N"}

	# Get camera direction (forward vector) - flip Z for correct north
	var forward = -camera.global_transform.basis.z
	var heading_angle = rad_to_deg(atan2(forward.x, -forward.z))
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

	return {
		"angle": heading_angle,
		"compass": compass
	}

## Get current speed (for HUD display)
func get_current_speed() -> float:
	return camera_fast_speed if Input.is_key_pressed(KEY_SHIFT) else camera_speed
