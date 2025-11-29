extends Node3D
class_name RotatingLabel

## Slowly rotates the label in the sky

const ROTATION_SPEED: float = 0.15  # Radians per second

func _process(delta: float) -> void:
	rotation.y += ROTATION_SPEED * delta
