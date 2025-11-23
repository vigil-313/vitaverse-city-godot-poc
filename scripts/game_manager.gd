extends Node

var inventory = []
var current_interactable = null

signal inventory_updated
signal interaction_prompt_changed(prompt: String)

func add_to_inventory(item_name: String, description: String):
	inventory.append({"name": item_name, "description": description})
	inventory_updated.emit()
	print("Added to inventory: ", item_name)

func get_inventory() -> Array:
	return inventory

func set_interaction_prompt(prompt: String):
	interaction_prompt_changed.emit(prompt)
