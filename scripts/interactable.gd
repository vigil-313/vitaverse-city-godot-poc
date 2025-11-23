extends StaticBody3D
class_name Interactable

@export var interaction_prompt = "Press E to interact"
@export var item_name = "Item"
@export var description = "An interesting object."
@export var can_pick_up = false

signal interacted(interactable)

func get_interaction_prompt() -> String:
	return interaction_prompt

func interact():
	interacted.emit(self)
	if can_pick_up:
		queue_free()
