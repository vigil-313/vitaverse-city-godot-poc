extends CanvasLayer

@onready var interaction_label = $InteractionPrompt
@onready var inventory_panel = $InventoryPanel
@onready var inventory_list = $InventoryPanel/VBoxContainer/ItemList
@onready var controls_label = $ControlsLabel

var lighting_config_panel: Panel

func _ready():
	print("UI Manager _ready() called")

	GameManager.interaction_prompt_changed.connect(_on_interaction_prompt_changed)
	GameManager.inventory_updated.connect(_on_inventory_updated)
	inventory_panel.visible = false
	interaction_label.text = ""

	# Create and add lighting config panel (using simple test version)
	print("About to create test panel...")
	var TestPanelScript = load("res://scripts/lighting_config_test.gd")
	if TestPanelScript == null:
		print("ERROR: Failed to load test panel script!")
	else:
		print("Test panel script loaded successfully")
		lighting_config_panel = TestPanelScript.new()
		lighting_config_panel.position = Vector2(20, 150)  # Below controls label
		lighting_config_panel.visible = true  # Start visible for testing
		add_child(lighting_config_panel)
		print("Test panel created and added to UI")

	# Update controls label to include lighting config
	controls_label.text = "WASD - Move\nShift - Sprint\nE - Interact\nTAB - Inventory\nL - Lighting Config\nESC - Mouse"

func _input(event):
	if event.is_action_pressed("toggle_inventory"):
		inventory_panel.visible = not inventory_panel.visible

	# Toggle lighting config panel with L key
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_L:
			lighting_config_panel.visible = not lighting_config_panel.visible
			print("Lighting config panel toggled: ", lighting_config_panel.visible)

func _on_interaction_prompt_changed(prompt: String):
	interaction_label.text = prompt

func _on_inventory_updated():
	inventory_list.clear()
	for item in GameManager.get_inventory():
		inventory_list.add_item(item.name)
