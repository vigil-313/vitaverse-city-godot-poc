extends StaticBody3D

@export var is_open = false
@export var open_angle = 90.0
@export var auto_open = true
@export var detection_radius = 3.0
@export var interaction_prompt = "Door opens automatically"
@export var item_name = "Door"
@export var description = "A door"
@export var can_pick_up = false

@onready var door_mesh = $DoorMesh

var target_rotation = 0.0
var player_nearby = false
var detection_area: Area3D

signal interacted(interactable)

func _ready():
	setup_detection_area()
	update_prompt()

func setup_detection_area():
	detection_area = get_node_or_null("DetectionArea")
	if not detection_area:
		detection_area = Area3D.new()
		detection_area.name = "DetectionArea"
		add_child(detection_area)

		var collision = CollisionShape3D.new()
		var shape = SphereShape3D.new()
		shape.radius = detection_radius
		collision.shape = shape
		detection_area.add_child(collision)

	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.name == "Player" and auto_open:
		player_nearby = true
		open_door()

func _on_body_exited(body):
	if body.name == "Player" and auto_open:
		player_nearby = false
		close_door()

func open_door():
	is_open = true
	target_rotation = open_angle
	update_prompt()

func close_door():
	is_open = false
	target_rotation = 0.0
	update_prompt()

func get_interaction_prompt() -> String:
	return interaction_prompt

func update_prompt():
	if auto_open:
		interaction_prompt = "Door opens automatically"
	else:
		interaction_prompt = "Press E to close" if is_open else "Press E to open"

func interact():
	if not auto_open:
		is_open = not is_open
		target_rotation = open_angle if is_open else 0.0
		update_prompt()
		interacted.emit(self)

func _process(delta):
	if door_mesh:
		door_mesh.rotation.y = lerp_angle(door_mesh.rotation.y, deg_to_rad(target_rotation), 5.0 * delta)
