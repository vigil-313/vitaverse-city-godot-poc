extends Node
class_name EnvironmentManager

## Environment Manager
##
## Manages scene environment setup including:
## - Directional light (sun)
## - WorldEnvironment (sky, fog, SSAO, glow)
## - Ground plane (fallback)
## - Anti-aliasing settings
##
## Extracted from CityRenderer to reduce god object pattern.

# ========================================================================
# SIGNALS
# ========================================================================

signal environment_ready(directional_light: DirectionalLight3D, world_environment: WorldEnvironment)

# ========================================================================
# CONFIGURATION
# ========================================================================

## Performance mode reduces visual quality for better FPS
@export var performance_mode: bool = false

# ========================================================================
# STATE
# ========================================================================

var directional_light: DirectionalLight3D
var world_environment: WorldEnvironment
var ground_plane: MeshInstance3D

# ========================================================================
# PUBLIC API
# ========================================================================

## Setup entire environment and add to parent
func setup(parent: Node) -> void:
	_setup_directional_light(parent)
	_setup_world_environment(parent)
	_create_ground_plane(parent)

	environment_ready.emit(directional_light, world_environment)
	print("[EnvironmentManager] Environment setup complete")

## Setup anti-aliasing on viewport
func setup_anti_aliasing(viewport: Viewport) -> void:
	# Enable anti-aliasing (balanced - not too blurry)
	viewport.msaa_3d = Viewport.MSAA_4X  # Multi-sample AA for geometry edges
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED  # Disabled FXAA (too blurry)
	viewport.use_taa = false  # Disabled TAA (causes blur)
	print("   ✨ Anti-aliasing: MSAA 4x only (balanced)")

## Toggle performance mode at runtime
func set_performance_mode(enabled: bool) -> void:
	performance_mode = enabled
	_update_quality_settings()

# ========================================================================
# PRIVATE SETUP
# ========================================================================

func _setup_directional_light(parent: Node) -> void:
	directional_light = DirectionalLight3D.new()
	directional_light.name = "Sun"
	directional_light.position = Vector3(0, 100, 0)
	directional_light.rotation_degrees = Vector3(-45, -30, 0)
	directional_light.shadow_enabled = true
	directional_light.light_energy = 1.5
	directional_light.light_color = Color(1.0, 1.0, 0.98)  # Pure white with slight warmth

	if performance_mode:
		# PERFORMANCE: Simple 2-split shadows (much faster)
		directional_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		directional_light.directional_shadow_max_distance = 300.0
		print("   ⚡ Performance mode: 2-split shadows, 300m distance")
	else:
		# QUALITY: High-quality 4-split shadows (slower)
		directional_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		directional_light.directional_shadow_split_1 = 0.05
		directional_light.directional_shadow_split_2 = 0.15
		directional_light.directional_shadow_split_3 = 0.35
		directional_light.directional_shadow_max_distance = 500.0

	directional_light.shadow_bias = 0.02
	directional_light.shadow_normal_bias = 1.0

	parent.add_child(directional_light)

func _setup_world_environment(parent: Node) -> void:
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY

	# Sky - VIBRANT for flat/low-poly
	var sky = Sky.new()
	var sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color.html("#87CEEB")  # Bright sky blue
	sky_material.sky_horizon_color = Color.html("#E0F7FF")  # Very light blue
	sky_material.ground_bottom_color = Color(0.4, 0.4, 0.4)
	sky_material.ground_horizon_color = Color(0.7, 0.7, 0.7)
	sky.sky_material = sky_material
	env.sky = sky

	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9

	# Fog - LIGHT for atmospheric depth
	env.fog_enabled = true
	env.fog_light_color = Color.html("#E0F7FF")
	env.fog_light_energy = 1.2
	env.fog_density = 0.0004

	if performance_mode:
		env.ssao_enabled = false
		print("   ⚡ Performance mode: SSAO disabled")
	else:
		env.ssao_enabled = true
		env.ssao_radius = 2.0
		env.ssao_intensity = 1.5
		env.ssao_power = 2.0
		env.ssao_detail = 0.5

	if performance_mode:
		env.glow_enabled = false
		print("   ⚡ Performance mode: Glow/Bloom disabled")
	else:
		env.glow_enabled = true
		env.glow_intensity = 0.3
		env.glow_strength = 0.8
		env.glow_bloom = 0.2
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	world_environment = WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = env
	parent.add_child(world_environment)

## Create deep fallback ground plane (beneath terrain)
## Only visible if terrain has gaps - normally not seen
func _create_ground_plane(parent: Node) -> void:
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(12000, 12000)
	plane_mesh.subdivide_width = 4
	plane_mesh.subdivide_depth = 4

	ground_plane = MeshInstance3D.new()
	ground_plane.name = "GroundPlane"
	ground_plane.mesh = plane_mesh
	ground_plane.position = Vector3(0, -50, 0)

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.1, 0.08, 0.06)
	material.roughness = 1.0
	material.metallic = 0.0

	ground_plane.material_override = material
	ground_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	parent.add_child(ground_plane)

## Update quality settings when performance mode changes
func _update_quality_settings() -> void:
	if not world_environment or not directional_light:
		return

	var env = world_environment.environment
	if not env:
		return

	if performance_mode:
		directional_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		directional_light.directional_shadow_max_distance = 300.0
		env.ssao_enabled = false
		env.glow_enabled = false
	else:
		directional_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		directional_light.directional_shadow_max_distance = 500.0
		env.ssao_enabled = true
		env.glow_enabled = true
