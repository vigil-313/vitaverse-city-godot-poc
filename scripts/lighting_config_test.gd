extends Panel

## Simple test panel to verify UI is working

func _ready():
	print("Test panel _ready() called!")
	custom_minimum_size = Vector2(200, 100)

	var label = Label.new()
	label.text = "TEST PANEL"
	label.position = Vector2(10, 10)
	add_child(label)

	print("Test panel setup complete")
