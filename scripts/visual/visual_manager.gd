extends Node
class_name VisualManager

## Central coordinator for all visual effects and styling
## Provides modular, swappable visual systems with easy configuration

# Preload dependencies
const MaterialLibrary = preload("res://scripts/visual/material_library.gd")
const LightingController = preload("res://scripts/visual/lighting_controller.gd")
const PostProcessingStack = preload("res://scripts/visual/post_processing_stack.gd")
const EnvironmentPresets = preload("res://scripts/visual/environment_presets.gd")

signal visual_preset_changed(preset_name: String)
signal setting_changed(setting_name: String, value: Variant)

## Visual subsystems (injected dependencies)
var lighting_controller: LightingController
var material_library: MaterialLibrary
var post_processing_stack: PostProcessingStack
var environment_presets: EnvironmentPresets

## Current visual configuration
var current_preset: String = "default"
var stylization_blend: float = 0.0  # 0.0 = pure PBR, 1.0 = full stylized

## Visual quality settings
var enable_dynamic_lighting: bool = true
var enable_post_processing: bool = true
var enable_atmospheric_effects: bool = true
var enable_detail_objects: bool = true

## Performance settings
var lod_distance_multiplier: float = 1.0
var shadow_quality: int = 2  # 0=off, 1=low, 2=medium, 3=high
var target_fps: int = 30  # User prioritizes visual quality

## References to scene nodes (set during initialization)
var world_environment: WorldEnvironment
var directional_light: DirectionalLight3D
var camera: Camera3D

func _ready() -> void:
	print("[VisualManager] Initializing visual management system")

func initialize(
	p_world_env: WorldEnvironment,
	p_light: DirectionalLight3D,
	p_camera: Camera3D
) -> void:
	"""Initialize the visual manager with scene references"""
	world_environment = p_world_env
	directional_light = p_light
	camera = p_camera

	print("[VisualManager] Initialized with scene references")
	print("  - World Environment: ", world_environment != null)
	print("  - Directional Light: ", directional_light != null)
	print("  - Camera: ", camera != null)

func inject_subsystems(
	p_lighting: LightingController,
	p_materials: MaterialLibrary,
	p_post_processing: PostProcessingStack,
	p_presets: EnvironmentPresets
) -> void:
	"""Inject visual subsystem dependencies"""
	lighting_controller = p_lighting
	material_library = p_materials
	post_processing_stack = p_post_processing
	environment_presets = p_presets

	print("[VisualManager] Subsystems injected:")
	print("  - LightingController: ", lighting_controller != null)
	print("  - MaterialLibrary: ", material_library != null)
	print("  - PostProcessingStack: ", post_processing_stack != null)
	print("  - EnvironmentPresets: ", environment_presets != null)

	# Initialize subsystems
	if lighting_controller:
		lighting_controller.initialize(world_environment, directional_light)
	if material_library:
		material_library.initialize()
	if post_processing_stack:
		post_processing_stack.initialize(camera, world_environment)
	if environment_presets:
		environment_presets.initialize(self)

func apply_preset(preset_name: String) -> void:
	"""Apply a complete visual preset"""
	if not environment_presets:
		print("[VisualManager] Warning: No EnvironmentPresets available")
		return

	var preset_data = environment_presets.get_preset(preset_name)
	if not preset_data:
		print("[VisualManager] Warning: Preset '", preset_name, "' not found")
		return

	print("[VisualManager] Applying preset: ", preset_name)
	current_preset = preset_name

	# Apply lighting settings
	if lighting_controller and preset_data.has("lighting"):
		lighting_controller.apply_settings(preset_data["lighting"])

	# Apply post-processing settings
	if post_processing_stack and preset_data.has("post_processing"):
		post_processing_stack.apply_settings(preset_data["post_processing"])

	# Apply material settings
	if material_library and preset_data.has("materials"):
		material_library.apply_settings(preset_data["materials"])

	# Apply general visual settings
	if preset_data.has("stylization_blend"):
		stylization_blend = preset_data["stylization_blend"]
		_update_stylization_blend()

	visual_preset_changed.emit(preset_name)
	print("[VisualManager] Preset '", preset_name, "' applied successfully")

func set_stylization_blend(value: float) -> void:
	"""Set the blend between PBR and stylized rendering (0.0 to 1.0)"""
	stylization_blend = clamp(value, 0.0, 1.0)
	_update_stylization_blend()
	setting_changed.emit("stylization_blend", stylization_blend)

func _update_stylization_blend() -> void:
	"""Update all systems with current stylization blend"""
	if post_processing_stack:
		post_processing_stack.set_stylization_intensity(stylization_blend)
	if material_library:
		material_library.set_stylization_factor(stylization_blend)

func set_time_of_day(hour: float) -> void:
	"""Set time of day (0.0 to 24.0)"""
	if lighting_controller:
		lighting_controller.set_time_of_day(hour)

func set_weather_state(weather: String) -> void:
	"""Set weather state (clear, overcast, rainy, foggy)"""
	if lighting_controller:
		lighting_controller.set_weather(weather)

func get_material(material_name: String) -> StandardMaterial3D:
	"""Get a material from the library"""
	if material_library:
		return material_library.get_material(material_name)
	return null

func refresh_all_materials() -> void:
	"""Refresh all materials in the scene (useful after settings change)"""
	if material_library:
		material_library.refresh_all_materials()
	print("[VisualManager] All materials refreshed")

func save_current_config(config_name: String) -> void:
	"""Save current visual configuration to file"""
	if environment_presets:
		var config = _gather_current_config()
		environment_presets.save_config(config_name, config)
		print("[VisualManager] Configuration saved as: ", config_name)

func load_config(config_name: String) -> void:
	"""Load visual configuration from file"""
	if environment_presets:
		var config = environment_presets.load_config(config_name)
		if config:
			_apply_config(config)
			print("[VisualManager] Configuration loaded: ", config_name)

func _gather_current_config() -> Dictionary:
	"""Gather current visual settings into a config dictionary"""
	var config = {
		"preset": current_preset,
		"stylization_blend": stylization_blend,
		"enable_dynamic_lighting": enable_dynamic_lighting,
		"enable_post_processing": enable_post_processing,
		"enable_atmospheric_effects": enable_atmospheric_effects,
		"shadow_quality": shadow_quality,
	}

	if lighting_controller:
		config["lighting"] = lighting_controller.get_current_settings()
	if post_processing_stack:
		config["post_processing"] = post_processing_stack.get_current_settings()
	if material_library:
		config["materials"] = material_library.get_current_settings()

	return config

func _apply_config(config: Dictionary) -> void:
	"""Apply a config dictionary to all systems"""
	if config.has("stylization_blend"):
		set_stylization_blend(config["stylization_blend"])
	if config.has("enable_dynamic_lighting"):
		enable_dynamic_lighting = config["enable_dynamic_lighting"]
	if config.has("enable_post_processing"):
		enable_post_processing = config["enable_post_processing"]
	if config.has("shadow_quality"):
		shadow_quality = config["shadow_quality"]

	if lighting_controller and config.has("lighting"):
		lighting_controller.apply_settings(config["lighting"])
	if post_processing_stack and config.has("post_processing"):
		post_processing_stack.apply_settings(config["post_processing"])
	if material_library and config.has("materials"):
		material_library.apply_settings(config["materials"])

func get_debug_info() -> Dictionary:
	"""Get debug information about current visual state"""
	return {
		"preset": current_preset,
		"stylization_blend": stylization_blend,
		"dynamic_lighting": enable_dynamic_lighting,
		"post_processing": enable_post_processing,
		"atmospheric_effects": enable_atmospheric_effects,
		"shadow_quality": shadow_quality,
		"subsystems_active": {
			"lighting": lighting_controller != null,
			"materials": material_library != null,
			"post_processing": post_processing_stack != null,
			"presets": environment_presets != null,
		}
	}

func _process(_delta: float) -> void:
	# Update time-based effects if enabled
	if enable_dynamic_lighting and lighting_controller:
		lighting_controller.update_dynamic_effects(_delta)
