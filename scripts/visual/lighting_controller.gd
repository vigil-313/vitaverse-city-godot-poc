extends Node
class_name LightingController

## Controls lighting, time-of-day, weather, and atmospheric effects
## Provides dynamic lighting presets and smooth transitions

signal time_of_day_changed(hour: float)
signal weather_changed(weather_state: String)

## Static flag to prevent duplicate global parameter registration
static var _global_param_registered: bool = false

## Scene references
var world_environment: WorldEnvironment
var directional_light: DirectionalLight3D
var environment: Environment

## Time of day (0.0 to 24.0)
var current_time: float = 14.0  # Default: 2 PM
var time_speed: float = 0.0  # 0 = static, 1.0 = 1 hour per minute
var auto_cycle: bool = false

## Weather states
enum Weather {CLEAR, OVERCAST, RAINY, FOGGY, SUNSET, NIGHT}
var current_weather: Weather = Weather.CLEAR

## Lighting presets by time of day
const TIME_PRESETS = {
	"dawn": {
		"hour": 6.0,
		"sun_color": Color(1.0, 0.8, 0.6),
		"sun_energy": 0.8,
		"sun_angle": 15.0,
		"ambient_color": Color(0.5, 0.6, 0.7),
		"ambient_energy": 0.3,
		"sky_color": Color(0.7, 0.5, 0.4),
		"fog_color": Color(0.8, 0.75, 0.7),
		"fog_density": 0.0015
	},
	"morning": {
		"hour": 9.0,
		"sun_color": Color(1.0, 0.95, 0.9),
		"sun_energy": 1.2,
		"sun_angle": 35.0,
		"ambient_color": Color(0.6, 0.65, 0.7),
		"ambient_energy": 0.4,
		"sky_color": Color(0.5, 0.7, 1.0),
		"fog_color": Color(0.85, 0.87, 0.9),
		"fog_density": 0.0008
	},
	"noon": {
		"hour": 12.0,
		"sun_color": Color(1.0, 1.0, 0.98),
		"sun_energy": 1.5,
		"sun_angle": 60.0,
		"ambient_color": Color(0.65, 0.7, 0.75),
		"ambient_energy": 0.5,
		"sky_color": Color(0.4, 0.6, 1.0),
		"fog_color": Color(0.88, 0.9, 0.92),
		"fog_density": 0.0005
	},
	"afternoon": {
		"hour": 15.0,
		"sun_color": Color(1.0, 0.98, 0.92),
		"sun_energy": 1.3,
		"sun_angle": 45.0,
		"ambient_color": Color(0.65, 0.68, 0.72),
		"ambient_energy": 0.45,
		"sky_color": Color(0.5, 0.65, 0.95),
		"fog_color": Color(0.87, 0.88, 0.9),
		"fog_density": 0.0006
	},
	"sunset": {
		"hour": 19.0,
		"sun_color": Color(1.0, 0.6, 0.3),
		"sun_energy": 0.9,
		"sun_angle": 10.0,
		"ambient_color": Color(0.7, 0.5, 0.4),
		"ambient_energy": 0.35,
		"sky_color": Color(0.8, 0.4, 0.3),
		"fog_color": Color(0.85, 0.7, 0.6),
		"fog_density": 0.0012
	},
	"dusk": {
		"hour": 20.5,
		"sun_color": Color(0.6, 0.4, 0.5),
		"sun_energy": 0.4,
		"sun_angle": 0.0,
		"ambient_color": Color(0.4, 0.35, 0.5),
		"ambient_energy": 0.25,
		"sky_color": Color(0.3, 0.25, 0.4),
		"fog_color": Color(0.5, 0.5, 0.6),
		"fog_density": 0.002
	},
	"night": {
		"hour": 23.0,
		"sun_color": Color(0.3, 0.35, 0.5),
		"sun_energy": 0.1,
		"sun_angle": -30.0,
		"ambient_color": Color(0.2, 0.22, 0.3),
		"ambient_energy": 0.15,
		"sky_color": Color(0.05, 0.08, 0.15),
		"fog_color": Color(0.25, 0.27, 0.35),
		"fog_density": 0.0025
	}
}

## Weather modifiers
const WEATHER_MODIFIERS = {
	Weather.CLEAR: {
		"sun_energy_mult": 1.0,
		"fog_density_mult": 1.0,
		"ambient_energy_mult": 1.0
	},
	Weather.OVERCAST: {
		"sun_energy_mult": 0.6,
		"fog_density_mult": 1.8,
		"ambient_energy_mult": 1.2,
		"sky_color_override": Color(0.6, 0.6, 0.65)
	},
	Weather.RAINY: {
		"sun_energy_mult": 0.4,
		"fog_density_mult": 2.5,
		"ambient_energy_mult": 0.8,
		"sky_color_override": Color(0.5, 0.52, 0.55),
		"fog_color_tint": Color(0.7, 0.7, 0.75)
	},
	Weather.FOGGY: {
		"sun_energy_mult": 0.5,
		"fog_density_mult": 5.0,
		"ambient_energy_mult": 0.9,
		"fog_color_override": Color(0.82, 0.82, 0.84)
	}
}

func initialize(p_world_env: WorldEnvironment, p_light: DirectionalLight3D) -> void:
	"""Initialize with scene references"""
	world_environment = p_world_env
	directional_light = p_light

	if world_environment:
		environment = world_environment.environment

	print("[LightingController] Initialized")
	print("  - Environment: ", environment != null)
	print("  - DirectionalLight: ", directional_light != null)

	# Register global shader parameter for window emission (once per game session)
	# Must be done BEFORE any window materials are created
	if not _global_param_registered:
		RenderingServer.global_shader_parameter_add("time_of_day", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, current_time)
		_global_param_registered = true
		print("  - Registered global shader parameter: time_of_day = ", current_time)

	# Set initial lighting (this will also update the global shader parameter)
	set_time_of_day(current_time)

func set_time_of_day(hour: float) -> void:
	"""Set time of day (0.0 to 24.0) with smooth interpolation"""
	current_time = fmod(hour, 24.0)

	# Update global shader parameter for window emission control
	# This updates all window materials automatically
	RenderingServer.global_shader_parameter_set("time_of_day", current_time)

	# Find the two nearest time presets to interpolate between
	var preset_times = []
	for preset_name in TIME_PRESETS.keys():
		preset_times.append({"name": preset_name, "hour": TIME_PRESETS[preset_name]["hour"]})

	# Sort by hour
	preset_times.sort_custom(func(a, b): return a["hour"] < b["hour"])

	# Find bracketing presets
	var prev_preset = preset_times[-1]  # Wrap to last
	var next_preset = preset_times[0]

	for i in range(preset_times.size()):
		if preset_times[i]["hour"] <= current_time:
			prev_preset = preset_times[i]
			next_preset = preset_times[(i + 1) % preset_times.size()]
		else:
			break

	# Calculate interpolation factor
	var prev_hour = prev_preset["hour"]
	var next_hour = next_preset["hour"]
	if next_hour < prev_hour:  # Wrap around midnight
		next_hour += 24.0
	var current_adjusted = current_time if current_time >= prev_hour else current_time + 24.0

	var t = 0.0
	if next_hour > prev_hour:
		t = (current_adjusted - prev_hour) / (next_hour - prev_hour)

	# Interpolate between presets
	var prev_data = TIME_PRESETS[prev_preset["name"]]
	var next_data = TIME_PRESETS[next_preset["name"]]

	_apply_interpolated_lighting(prev_data, next_data, t)

	time_of_day_changed.emit(current_time)

func _apply_interpolated_lighting(prev: Dictionary, next: Dictionary, t: float) -> void:
	"""Apply interpolated lighting between two presets"""
	if not directional_light or not environment:
		return

	# Interpolate sun properties
	var sun_color = prev["sun_color"].lerp(next["sun_color"], t)
	var sun_energy = lerp(prev["sun_energy"], next["sun_energy"], t)
	var sun_angle = lerp(prev["sun_angle"], next["sun_angle"], t)

	# Interpolate ambient
	var ambient_color = prev["ambient_color"].lerp(next["ambient_color"], t)
	var ambient_energy = lerp(prev["ambient_energy"], next["ambient_energy"], t)

	# Interpolate sky and fog
	var sky_color = prev["sky_color"].lerp(next["sky_color"], t)
	var fog_color = prev["fog_color"].lerp(next["fog_color"], t)
	var fog_density = lerp(prev["fog_density"], next["fog_density"], t)

	# Apply weather modifiers
	var weather_mod = WEATHER_MODIFIERS[current_weather]
	sun_energy *= weather_mod["sun_energy_mult"]
	fog_density *= weather_mod["fog_density_mult"]
	ambient_energy *= weather_mod["ambient_energy_mult"]

	if weather_mod.has("sky_color_override"):
		sky_color = weather_mod["sky_color_override"]
	if weather_mod.has("fog_color_override"):
		fog_color = weather_mod["fog_color_override"]
	elif weather_mod.has("fog_color_tint"):
		fog_color = fog_color * weather_mod["fog_color_tint"]

	# Apply to directional light
	directional_light.light_color = sun_color
	directional_light.light_energy = sun_energy
	directional_light.rotation_degrees.x = -sun_angle

	# Apply to environment
	if environment.background_mode == Environment.BG_SKY:
		var sky = environment.sky
		if sky and sky.sky_material is ProceduralSkyMaterial:
			var sky_mat = sky.sky_material as ProceduralSkyMaterial
			sky_mat.sky_top_color = sky_color
			sky_mat.sky_horizon_color = sky_color.lightened(0.2)

	# Apply ambient light
	environment.ambient_light_color = ambient_color
	environment.ambient_light_energy = ambient_energy
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR

	# Apply fog
	if environment.fog_enabled:
		environment.fog_light_color = fog_color
		environment.fog_density = fog_density

func set_weather(weather_name: String) -> void:
	"""Set weather state by name"""
	match weather_name.to_lower():
		"clear":
			current_weather = Weather.CLEAR
		"overcast", "cloudy":
			current_weather = Weather.OVERCAST
		"rainy", "rain":
			current_weather = Weather.RAINY
		"foggy", "fog":
			current_weather = Weather.FOGGY
		_:
			print("[LightingController] Unknown weather: ", weather_name)
			return

	# Reapply current time with new weather
	set_time_of_day(current_time)
	weather_changed.emit(weather_name)
	print("[LightingController] Weather set to: ", weather_name)

func set_preset(preset_name: String) -> void:
	"""Jump to a named time preset"""
	if TIME_PRESETS.has(preset_name):
		set_time_of_day(TIME_PRESETS[preset_name]["hour"])
		print("[LightingController] Applied preset: ", preset_name)
	else:
		print("[LightingController] Unknown preset: ", preset_name)

func update_dynamic_effects(delta: float) -> void:
	"""Update time-based effects (call from _process if auto_cycle enabled)"""
	if auto_cycle and time_speed > 0:
		current_time += (delta * time_speed * 60.0) / 3600.0  # Convert to hours
		set_time_of_day(current_time)

func set_shadow_quality(quality: int) -> void:
	"""Set shadow quality (0=off, 1=low, 2=medium, 3=high)"""
	if not directional_light:
		return

	match quality:
		0:  # Off
			directional_light.shadow_enabled = false
		1:  # Low
			directional_light.shadow_enabled = true
			directional_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			directional_light.directional_shadow_max_distance = 100.0
		2:  # Medium
			directional_light.shadow_enabled = true
			directional_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			directional_light.directional_shadow_max_distance = 200.0
		3:  # High
			directional_light.shadow_enabled = true
			directional_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			directional_light.directional_shadow_max_distance = 500.0

	print("[LightingController] Shadow quality set to: ", quality)

func set_fog_density(density: float) -> void:
	"""Manually set fog density"""
	if environment:
		environment.fog_density = density

func apply_settings(settings: Dictionary) -> void:
	"""Apply lighting settings from dictionary"""
	if settings.has("time_of_day"):
		set_time_of_day(settings["time_of_day"])
	if settings.has("weather"):
		set_weather(settings["weather"])
	if settings.has("auto_cycle"):
		auto_cycle = settings["auto_cycle"]
	if settings.has("time_speed"):
		time_speed = settings["time_speed"]
	if settings.has("shadow_quality"):
		set_shadow_quality(settings["shadow_quality"])
	if settings.has("fog_density"):
		set_fog_density(settings["fog_density"])

func get_current_settings() -> Dictionary:
	"""Get current lighting settings"""
	return {
		"time_of_day": current_time,
		"weather": Weather.keys()[current_weather],
		"auto_cycle": auto_cycle,
		"time_speed": time_speed,
		"shadow_quality": 2  # Default medium
	}
