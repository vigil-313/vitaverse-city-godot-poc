extends Node
class_name EnvironmentPresets

## Manages visual environment presets and configuration persistence
## Provides built-in presets and save/load functionality

const PRESETS_DIR = "user://visual_presets/"
const BUILTIN_PRESETS_FILE = "res://scripts/visual/builtin_presets.json"

var visual_manager  # VisualManager (no type hint to avoid circular dependency)
var builtin_presets: Dictionary = {}
var user_presets: Dictionary = {}

func initialize(p_visual_manager) -> void:
	"""Initialize with reference to VisualManager"""
	visual_manager = p_visual_manager
	print("[EnvironmentPresets] Initialized")

	# Create presets directory if it doesn't exist
	var dir = DirAccess.open("user://")
	if dir and not dir.dir_exists("visual_presets"):
		dir.make_dir("visual_presets")

	# Load built-in presets
	_load_builtin_presets()

	# Load user presets
	_load_user_presets()

	print("[EnvironmentPresets] Loaded ", builtin_presets.size(), " built-in presets")
	print("[EnvironmentPresets] Loaded ", user_presets.size(), " user presets")

func _load_builtin_presets() -> void:
	"""Load built-in visual presets"""
	# Define built-in presets directly in code for now
	builtin_presets = {
		"default": {
			"description": "Default balanced look with realistic lighting",
			"stylization_blend": 0.0,
			"lighting": {
				"time_of_day": 14.0,
				"weather": "clear",
				"shadow_quality": 2,
				"auto_cycle": false
			},
			"post_processing": {
				"stylization_intensity": 0.0,
				"color_grading_preset": "neutral",
				"enable_color_grading": true,
				"enable_dithering": false,
				"enable_vignette": false,
				"enable_bloom": true,
				"enable_ssao": true
			},
			"materials": {
				"stylization_factor": 0.0,
				"enable_color_variation": true,
				"color_variation_amount": 0.15
			}
		},

		"subtle_retro": {
			"description": "Subtle retro aesthetic with warm tones and light dithering",
			"stylization_blend": 0.3,
			"lighting": {
				"time_of_day": 15.0,
				"weather": "clear",
				"shadow_quality": 2
			},
			"post_processing": {
				"stylization_intensity": 0.3,
				"color_grading_preset": "retro",
				"enable_color_grading": true,
				"enable_dithering": true,
				"enable_vignette": true,
				"enable_bloom": true,
				"enable_ssao": true,
				"vignette_intensity": 0.25,
				"dithering_strength": 0.2
			},
			"materials": {
				"stylization_factor": 0.3,
				"enable_color_variation": true,
				"color_variation_amount": 0.2
			}
		},

		"painterly": {
			"description": "Artistic painterly look with vibrant colors",
			"stylization_blend": 0.5,
			"lighting": {
				"time_of_day": 14.0,
				"weather": "clear",
				"shadow_quality": 2
			},
			"post_processing": {
				"stylization_intensity": 0.5,
				"color_grading_preset": "vibrant",
				"enable_color_grading": true,
				"enable_dithering": false,
				"enable_vignette": true,
				"enable_bloom": true,
				"enable_ssao": true,
				"vignette_intensity": 0.15
			},
			"materials": {
				"stylization_factor": 0.5,
				"enable_color_variation": true,
				"color_variation_amount": 0.25
			}
		},

		"clean_modern": {
			"description": "Clean modern look with crisp lighting",
			"stylization_blend": 0.0,
			"lighting": {
				"time_of_day": 12.0,
				"weather": "clear",
				"shadow_quality": 3
			},
			"post_processing": {
				"stylization_intensity": 0.0,
				"color_grading_preset": "neutral",
				"enable_color_grading": true,
				"enable_dithering": false,
				"enable_vignette": false,
				"enable_bloom": true,
				"enable_ssao": true
			},
			"materials": {
				"stylization_factor": 0.0,
				"enable_color_variation": true,
				"color_variation_amount": 0.1
			}
		},

		"cinematic": {
			"description": "Cinematic look with dramatic lighting and contrast",
			"stylization_blend": 0.2,
			"lighting": {
				"time_of_day": 17.0,
				"weather": "clear",
				"shadow_quality": 3
			},
			"post_processing": {
				"stylization_intensity": 0.2,
				"color_grading_preset": "cinematic",
				"enable_color_grading": true,
				"enable_dithering": false,
				"enable_vignette": true,
				"enable_bloom": true,
				"enable_ssao": true,
				"vignette_intensity": 0.35
			},
			"materials": {
				"stylization_factor": 0.2,
				"enable_color_variation": true,
				"color_variation_amount": 0.12
			}
		},

		"golden_hour": {
			"description": "Warm golden hour lighting with soft shadows",
			"stylization_blend": 0.15,
			"lighting": {
				"time_of_day": 18.5,
				"weather": "clear",
				"shadow_quality": 2
			},
			"post_processing": {
				"stylization_intensity": 0.15,
				"color_grading_preset": "warm",
				"enable_color_grading": true,
				"enable_dithering": false,
				"enable_vignette": true,
				"enable_bloom": true,
				"enable_ssao": true,
				"vignette_intensity": 0.2
			},
			"materials": {
				"stylization_factor": 0.15,
				"enable_color_variation": true,
				"color_variation_amount": 0.15
			}
		},

		"overcast": {
			"description": "Soft overcast lighting with muted colors",
			"stylization_blend": 0.1,
			"lighting": {
				"time_of_day": 13.0,
				"weather": "overcast",
				"shadow_quality": 1
			},
			"post_processing": {
				"stylization_intensity": 0.1,
				"color_grading_preset": "muted",
				"enable_color_grading": true,
				"enable_dithering": false,
				"enable_vignette": false,
				"enable_bloom": false,
				"enable_ssao": true
			},
			"materials": {
				"stylization_factor": 0.1,
				"enable_color_variation": true,
				"color_variation_amount": 0.12
			}
		},

		"night_city": {
			"description": "Night time with atmospheric fog",
			"stylization_blend": 0.25,
			"lighting": {
				"time_of_day": 22.0,
				"weather": "foggy",
				"shadow_quality": 1
			},
			"post_processing": {
				"stylization_intensity": 0.25,
				"color_grading_preset": "cool",
				"enable_color_grading": true,
				"enable_dithering": true,
				"enable_vignette": true,
				"enable_bloom": true,
				"enable_ssao": true,
				"vignette_intensity": 0.4,
				"dithering_strength": 0.15
			},
			"materials": {
				"stylization_factor": 0.25,
				"enable_color_variation": true,
				"color_variation_amount": 0.15
			}
		}
	}

func _load_user_presets() -> void:
	"""Load user-saved presets from disk"""
	var dir = DirAccess.open(PRESETS_DIR)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".json"):
			var preset_name = file_name.trim_suffix(".json")
			var preset_data = _load_preset_file(PRESETS_DIR + file_name)
			if preset_data:
				user_presets[preset_name] = preset_data
		file_name = dir.get_next()

	dir.list_dir_end()

func _load_preset_file(file_path: String) -> Dictionary:
	"""Load a single preset file"""
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {}

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)

	if error == OK:
		return json.data
	else:
		print("[EnvironmentPresets] Error parsing preset file: ", file_path)
		return {}

func get_preset(preset_name: String) -> Dictionary:
	"""Get a preset by name (checks built-in first, then user presets)"""
	if builtin_presets.has(preset_name):
		return builtin_presets[preset_name]
	elif user_presets.has(preset_name):
		return user_presets[preset_name]
	else:
		print("[EnvironmentPresets] Preset not found: ", preset_name)
		return {}

func get_all_preset_names() -> Array:
	"""Get list of all available preset names"""
	var names = []
	names.append_array(builtin_presets.keys())
	names.append_array(user_presets.keys())
	return names

func get_builtin_preset_names() -> Array:
	"""Get list of built-in preset names"""
	return builtin_presets.keys()

func get_user_preset_names() -> Array:
	"""Get list of user preset names"""
	return user_presets.keys()

func save_config(config_name: String, config_data: Dictionary) -> void:
	"""Save a configuration as a user preset"""
	var file_path = PRESETS_DIR + config_name + ".json"
	var file = FileAccess.open(file_path, FileAccess.WRITE)

	if not file:
		print("[EnvironmentPresets] Error: Could not save preset to ", file_path)
		return

	var json_string = JSON.stringify(config_data, "\t")
	file.store_string(json_string)
	file.close()

	# Add to user presets dictionary
	user_presets[config_name] = config_data

	print("[EnvironmentPresets] Saved preset: ", config_name)

func load_config(config_name: String) -> Dictionary:
	"""Load a user configuration"""
	if user_presets.has(config_name):
		return user_presets[config_name]

	var file_path = PRESETS_DIR + config_name + ".json"
	var preset_data = _load_preset_file(file_path)

	if preset_data:
		user_presets[config_name] = preset_data

	return preset_data

func delete_user_preset(preset_name: String) -> bool:
	"""Delete a user preset"""
	if not user_presets.has(preset_name):
		print("[EnvironmentPresets] User preset not found: ", preset_name)
		return false

	var file_path = PRESETS_DIR + preset_name + ".json"
	var dir = DirAccess.open(PRESETS_DIR)

	if dir and dir.file_exists(file_path):
		dir.remove(file_path)
		user_presets.erase(preset_name)
		print("[EnvironmentPresets] Deleted preset: ", preset_name)
		return true

	return false

func get_preset_description(preset_name: String) -> String:
	"""Get description of a preset"""
	var preset = get_preset(preset_name)
	if preset and preset.has("description"):
		return preset["description"]
	return "No description available"
