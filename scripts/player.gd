extends CharacterBody3D

@export var walk_speed = 5.0
@export var sprint_speed = 40.0  # 4x faster (was 10.0)
@export var jump_velocity = 4.5
@export var mouse_sensitivity = 0.003
@export var camera_distance = 25.0  # Further out (was 15.0)
@export var camera_height = 12.0  # Higher camera (was 8.0)
@export var min_camera_distance = 5.0  # Minimum zoom
@export var max_camera_distance = 100.0  # Much further max zoom (was 40.0)
@export var zoom_speed = 2.0  # Zoom sensitivity

@onready var camera_pivot = $CameraPivot
@onready var camera = $CameraPivot/Camera3D
@onready var interaction_ray = $CameraPivot/Camera3D/InteractionRay
@onready var mesh_root = $MeshRoot

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera_rotation = Vector2.ZERO
var target_camera_distance = 25.0  # Target distance for smooth zooming

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	target_camera_distance = camera_distance
	camera.position = Vector3(0, camera_height, camera_distance)

func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		camera_rotation.x -= event.relative.y * mouse_sensitivity
		camera_rotation.y -= event.relative.x * mouse_sensitivity
		camera_rotation.x = clamp(camera_rotation.x, -PI/3, PI/3)

	# Scroll wheel and trackpad zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_camera_distance = clamp(target_camera_distance - zoom_speed, min_camera_distance, max_camera_distance)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_camera_distance = clamp(target_camera_distance + zoom_speed, min_camera_distance, max_camera_distance)

	# Trackpad pinch/scroll zoom (MacBook support)
	if event is InputEventPanGesture:
		target_camera_distance = clamp(target_camera_distance + event.delta.y * zoom_speed * 2, min_camera_distance, max_camera_distance)
	elif event is InputEventMagnifyGesture:
		target_camera_distance = clamp(target_camera_distance / event.factor, min_camera_distance, max_camera_distance)

	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	camera_pivot.rotation.x = camera_rotation.x
	camera_pivot.rotation.y = camera_rotation.y

	# Smooth camera zoom
	camera_distance = lerp(camera_distance, target_camera_distance, 10.0 * delta)
	camera.position = Vector3(0, camera_height, camera_distance)

	if not is_on_floor():
		velocity.y -= gravity * delta

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (camera_pivot.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var current_speed = sprint_speed if Input.is_action_pressed("sprint") else walk_speed

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed

		var target_rotation = atan2(direction.x, direction.z)
		mesh_root.rotation.y = lerp_angle(mesh_root.rotation.y, target_rotation, 10.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()
	check_interaction()
	animate_character(delta)

func animate_character(delta):
	var is_moving = velocity.length() > 0.1
	if is_moving:
		var anim_time = Time.get_ticks_msec() * 0.01
		var anim_speed = 1.5 if Input.is_action_pressed("sprint") else 1.0
		$MeshRoot/LeftLeg.rotation.x = sin(anim_time * anim_speed) * 0.4
		$MeshRoot/RightLeg.rotation.x = -sin(anim_time * anim_speed) * 0.4
		$MeshRoot/LeftArm.rotation.x = -sin(anim_time * anim_speed) * 0.3
		$MeshRoot/RightArm.rotation.x = sin(anim_time * anim_speed) * 0.3
		mesh_root.position.y = sin(anim_time * anim_speed * 2) * 0.05
	else:
		$MeshRoot/LeftLeg.rotation.x = lerp($MeshRoot/LeftLeg.rotation.x, 0.0, 10.0 * delta)
		$MeshRoot/RightLeg.rotation.x = lerp($MeshRoot/RightLeg.rotation.x, 0.0, 10.0 * delta)
		$MeshRoot/LeftArm.rotation.x = lerp($MeshRoot/LeftArm.rotation.x, 0.0, 10.0 * delta)
		$MeshRoot/RightArm.rotation.x = lerp($MeshRoot/RightArm.rotation.x, 0.0, 10.0 * delta)
		mesh_root.position.y = lerp(mesh_root.position.y, 0.0, 10.0 * delta)

func check_interaction():
	if interaction_ray.is_colliding():
		var collider = interaction_ray.get_collider()
		if collider.has_method("get_interaction_prompt"):
			var prompt = collider.get_interaction_prompt()
			GameManager.set_interaction_prompt(prompt)
			if Input.is_action_just_pressed("interact"):
				if collider.can_pick_up:
					GameManager.add_to_inventory(collider.item_name, collider.description)
				collider.interact()
		else:
			GameManager.set_interaction_prompt("")
	else:
		GameManager.set_interaction_prompt("")
