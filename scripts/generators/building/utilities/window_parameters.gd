extends Node
class_name WindowParameters

## Calculates window parameters (spacing, size) based on building type

## Get window parameters for building type
static func get_parameters(building_type: String) -> Dictionary:
	match building_type:
		"commercial", "office", "retail":
			return {
				"spacing": 2.5,  # 2.5m between windows
				"width": 2.0,    # 2m wide windows
				"height": 2.5    # 2.5m tall windows
			}
		"residential", "apartments", "house":
			return {
				"spacing": 3.5,  # 3.5m between windows
				"width": 1.2,    # 1.2m wide windows
				"height": 1.8    # 1.8m tall windows
			}
		"industrial", "warehouse":
			return {
				"spacing": 5.0,  # 5m between windows (sparse)
				"width": 1.0,    # 1m wide windows (small)
				"height": 1.5    # 1.5m tall windows
			}
		_:
			# Default/unknown building types
			return {
				"spacing": 3.0,  # 3m between windows
				"width": 1.5,    # 1.5m wide windows
				"height": 2.0    # 2m tall windows
			}
