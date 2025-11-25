extends Node
class_name PostProcessingStack

## Modular post-processing effects pipeline
## Manages shader effects with configurable blend and intensity

signal effects_changed()

## Scene references
var camera: Camera3D
var world_environment: WorldEnvironment
var environment: Environment

## Effect layers (can be individually toggled)
var enable_color_grading: bool = true
var enable_dithering: bool = false
var enable_palette_quantization: bool = false
var enable_vignette: bool = true
var enable_bloom: bool = true
var enable_ssao: bool = true

## Stylization intensity (0.0 = clean PBR, 1.0 = full stylized)
var stylization_intensity: float = 0.0

## Color grading settings
var color_grading_preset: String = "neutral"
const COLOR_GRADING_PRESETS = {
	"neutral": {"saturation": 1.0, "contrast": 1.0, "brightness": 1.0, "warmth": 0.0},
	"warm": {"saturation": 1.1, "contrast": 1.05, "brightness": 1.0, "warmth": 0.1},
	"cool": {"saturation": 1.1, "contrast": 1.05, "brightness": 1.0, "warmth": -0.1},
	"vibrant": {"saturation": 1.3, "contrast": 1.15, "brightness": 1.05, "warmth": 0.05},
	"muted": {"saturation": 0.7, "contrast": 0.95, "brightness": 0.98, "warmth": 0.0},
	"cinematic": {"saturation": 0.9, "contrast": 1.2, "brightness": 0.95, "warmth": 0.05},
	"retro": {"saturation": 1.2, "contrast": 1.1, "brightness": 1.0, "warmth": 0.15}
}

## Dithering settings
var dithering_strength: float = 0.3  # Subtle by default
var use_bayer_8x8: bool = true

## Palette settings
var palette_name: String = "extended_256"
var palette_size: int = 256

## Vignette settings
var vignette_intensity: float = 0.2  # Subtle vignette
var vignette_smoothness: float = 0.5

## Shader material for post-processing (if using SubViewport approach)
var post_process_material: ShaderMaterial

func initialize(p_camera: Camera3D, p_world_env: WorldEnvironment) -> void:
	"""Initialize with scene references"""
	camera = p_camera
	world_environment = p_world_env

	if world_environment:
		environment = world_environment.environment

	print("[PostProcessingStack] Initialized")
	print("  - Camera: ", camera != null)
	print("  - Environment: ", environment != null)

	# Set initial effects
	_apply_environment_effects()

func _apply_environment_effects() -> void:
	"""Apply effects that use WorldEnvironment settings"""
	if not environment:
		return

	# SSAO (Screen-Space Ambient Occlusion)
	if enable_ssao:
		environment.ssao_enabled = true
		environment.ssao_radius = 2.0
		environment.ssao_intensity = lerp(1.0, 0.5, stylization_intensity)  # Reduce for stylized
		environment.ssao_detail = 0.5
	else:
		environment.ssao_enabled = false

	# Bloom (glow)
	if enable_bloom:
		environment.glow_enabled = true
		environment.glow_intensity = lerp(0.3, 0.6, stylization_intensity)  # More glow for stylized
		environment.glow_strength = 0.8
		environment.glow_bloom = 0.1
		environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	else:
		environment.glow_enabled = false

	# Adjust based on stylization intensity
	if environment.adjustment_enabled:
		var grading = COLOR_GRADING_PRESETS[color_grading_preset]
		environment.adjustment_saturation = grading["saturation"]
		environment.adjustment_contrast = grading["contrast"]
		environment.adjustment_brightness = grading["brightness"]
	else:
		# Enable adjustments
		environment.adjustment_enabled = enable_color_grading
		var grading = COLOR_GRADING_PRESETS[color_grading_preset]
		environment.adjustment_saturation = grading["saturation"]
		environment.adjustment_contrast = grading["contrast"]
		environment.adjustment_brightness = grading["brightness"]

func set_stylization_intensity(value: float) -> void:
	"""Set overall stylization intensity (0.0 to 1.0)"""
	stylization_intensity = clamp(value, 0.0, 1.0)

	# Update dithering strength based on stylization
	dithering_strength = stylization_intensity * 0.5  # Max 0.5 for subtlety

	# Update effects
	_apply_environment_effects()
	effects_changed.emit()

	print("[PostProcessingStack] Stylization intensity: ", stylization_intensity)

func set_color_grading_preset(preset_name: String) -> void:
	"""Set color grading preset"""
	if COLOR_GRADING_PRESETS.has(preset_name):
		color_grading_preset = preset_name
		_apply_environment_effects()
		print("[PostProcessingStack] Color grading: ", preset_name)
	else:
		print("[PostProcessingStack] Unknown preset: ", preset_name)

func enable_effect(effect_name: String, enabled: bool) -> void:
	"""Enable or disable a specific effect"""
	match effect_name:
		"color_grading":
			enable_color_grading = enabled
		"dithering":
			enable_dithering = enabled
		"palette_quantization":
			enable_palette_quantization = enabled
		"vignette":
			enable_vignette = enabled
		"bloom":
			enable_bloom = enabled
		"ssao":
			enable_ssao = enabled
		_:
			print("[PostProcessingStack] Unknown effect: ", effect_name)
			return

	_apply_environment_effects()
	effects_changed.emit()

func set_vignette(intensity: float, smoothness: float) -> void:
	"""Set vignette parameters"""
	vignette_intensity = clamp(intensity, 0.0, 1.0)
	vignette_smoothness = clamp(smoothness, 0.0, 1.0)
	effects_changed.emit()

func apply_settings(settings: Dictionary) -> void:
	"""Apply post-processing settings from dictionary"""
	if settings.has("stylization_intensity"):
		set_stylization_intensity(settings["stylization_intensity"])
	if settings.has("color_grading_preset"):
		set_color_grading_preset(settings["color_grading_preset"])
	if settings.has("enable_color_grading"):
		enable_color_grading = settings["enable_color_grading"]
	if settings.has("enable_dithering"):
		enable_dithering = settings["enable_dithering"]
	if settings.has("enable_palette_quantization"):
		enable_palette_quantization = settings["enable_palette_quantization"]
	if settings.has("enable_vignette"):
		enable_vignette = settings["enable_vignette"]
	if settings.has("enable_bloom"):
		enable_bloom = settings["enable_bloom"]
	if settings.has("enable_ssao"):
		enable_ssao = settings["enable_ssao"]
	if settings.has("vignette_intensity"):
		vignette_intensity = settings["vignette_intensity"]
	if settings.has("dithering_strength"):
		dithering_strength = settings["dithering_strength"]

	_apply_environment_effects()

func get_current_settings() -> Dictionary:
	"""Get current post-processing settings"""
	return {
		"stylization_intensity": stylization_intensity,
		"color_grading_preset": color_grading_preset,
		"enable_color_grading": enable_color_grading,
		"enable_dithering": enable_dithering,
		"enable_palette_quantization": enable_palette_quantization,
		"enable_vignette": enable_vignette,
		"enable_bloom": enable_bloom,
		"enable_ssao": enable_ssao,
		"vignette_intensity": vignette_intensity,
		"dithering_strength": dithering_strength
	}

func get_preset_subtle_retro() -> Dictionary:
	"""Get preset for subtle retro look"""
	return {
		"stylization_intensity": 0.3,
		"color_grading_preset": "retro",
		"enable_color_grading": true,
		"enable_dithering": true,
		"enable_palette_quantization": false,
		"enable_vignette": true,
		"enable_bloom": true,
		"enable_ssao": true,
		"vignette_intensity": 0.25,
		"dithering_strength": 0.2
	}

func get_preset_painterly() -> Dictionary:
	"""Get preset for painterly look"""
	return {
		"stylization_intensity": 0.5,
		"color_grading_preset": "vibrant",
		"enable_color_grading": true,
		"enable_dithering": false,
		"enable_palette_quantization": false,
		"enable_vignette": true,
		"enable_bloom": true,
		"enable_ssao": true,
		"vignette_intensity": 0.15,
		"dithering_strength": 0.0
	}

func get_preset_clean_modern() -> Dictionary:
	"""Get preset for clean modern look"""
	return {
		"stylization_intensity": 0.0,
		"color_grading_preset": "neutral",
		"enable_color_grading": true,
		"enable_dithering": false,
		"enable_palette_quantization": false,
		"enable_vignette": false,
		"enable_bloom": true,
		"enable_ssao": true,
		"vignette_intensity": 0.0,
		"dithering_strength": 0.0
	}

func get_preset_cinematic() -> Dictionary:
	"""Get preset for cinematic look"""
	return {
		"stylization_intensity": 0.2,
		"color_grading_preset": "cinematic",
		"enable_color_grading": true,
		"enable_dithering": false,
		"enable_palette_quantization": false,
		"enable_vignette": true,
		"enable_bloom": true,
		"enable_ssao": true,
		"vignette_intensity": 0.35,
		"dithering_strength": 0.0
	}
