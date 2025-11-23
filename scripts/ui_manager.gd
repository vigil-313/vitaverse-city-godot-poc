extends CanvasLayer

@onready var interaction_label = $InteractionPrompt
@onready var inventory_panel = $InventoryPanel
@onready var inventory_list = $InventoryPanel/VBoxContainer/ItemList
@onready var controls_label = $ControlsLabel

func _ready():
	GameManager.interaction_prompt_changed.connect(_on_interaction_prompt_changed)
	GameManager.inventory_updated.connect(_on_inventory_updated)
	inventory_panel.visible = false
	interaction_label.text = ""

func _input(event):
	if event.is_action_pressed("toggle_inventory"):
		inventory_panel.visible = not inventory_panel.visible

func _on_interaction_prompt_changed(prompt: String):
	interaction_label.text = prompt

func _on_inventory_updated():
	inventory_list.clear()
	for item in GameManager.get_inventory():
		inventory_list.add_item(item.name)
