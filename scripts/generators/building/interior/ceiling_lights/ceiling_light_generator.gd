extends Node
class_name CeilingLightGenerator

## Generates interior ceiling lights visible through windows
## Creates LODLightProxy instances that manage OmniLight3D based on LOD tier

const LODLightProxy = preload("res://scripts/generators/building/interior/ceiling_lights/lod_light_proxy.gd")

static var total_lights_created = 0  # Debug counter
static var lights_by_type = {}  # Track lights per building type

const CEILING_OFFSET = 0.5      # 50cm below ceiling for visibility
const WALL_INSET = 1.5          # 1.5m inset from walls (keep lights inside)
const LIGHT_WIDTH = 2.0         # 2m wide light panels (larger for visibility)
const LIGHT_DEPTH = 0.8         # 80cm deep light panels
const LIGHT_SPACING = 4.0       # 4m spacing between lights

## Floor lighting chance - only 40% of floors get lights to reduce total count
## This allows more distant buildings to have active lights in NEAR/MID tiers
const FLOOR_LIGHT_CHANCE = 0.40

## Main entry point - generates ceiling lights for all floors
## Returns Array of LODLightProxy nodes (one per lit floor)
static func generate_ceiling_lights(
	context,
	glass_surface,
	floor_emissions: Array  # Array of emission colors per floor
) -> Array:
	if not context.detailed:
		return []

	# Different light chances based on building type
	var light_chance = _get_light_chance_for_type(context.building_type)
	if randf() >= light_chance:
		return []

	# Create lights for a random subset of floors (40% by default)
	# This reduces total light count, allowing more distant buildings to have active lights
	var lights = []

	# Determine which floors get lights (random selection)
	for floor_num in range(context.levels):
		var emission = floor_emissions[floor_num] if floor_num < floor_emissions.size() else Color.BLACK
		if emission.a > 0.01:  # Floor has lit windows
			# Only 40% of floors get dynamic lights to reduce total count
			if randf() < FLOOR_LIGHT_CHANCE:
				var light = _create_floor_light(context, floor_num, emission)
				lights.append(light)
				total_lights_created += 1

				# Track by type
				if not lights_by_type.has(context.building_type):
					lights_by_type[context.building_type] = 0
				lights_by_type[context.building_type] += 1

				if total_lights_created % 500 == 0:
					print("💡 Created ", total_lights_created, " lights | By type: ", lights_by_type)

	return lights

## Get light chance based on building type
static func _get_light_chance_for_type(building_type: String) -> float:
	match building_type:
		"commercial", "retail", "office", "shop":
			return 0.95  # 95% of commercial buildings lit
		"industrial", "warehouse":
			return 0.85  # 85% of industrial buildings lit
		"residential", "apartments", "house":
			return 0.40  # 40% of residential buildings lit
		_:
			return 0.60  # 60% default

## Add ceiling lights for a single floor
static func _add_floor_ceiling_lights(
	context,
	floor_num: int,
	emission: Color,
	glass_surface
) -> void:
	var floor_bottom = floor_num * context.floor_height
	var ceiling_y = floor_bottom + context.floor_height - CEILING_OFFSET

	# Calculate bounding box from footprint
	var bounds = _calculate_bounds(context.footprint, context.center)

	# Inset bounds from walls
	var inset_bounds = {
		"min": bounds.min + Vector2(WALL_INSET, WALL_INSET),
		"max": bounds.max - Vector2(WALL_INSET, WALL_INSET)
	}

	# Calculate grid dimensions
	var width = inset_bounds.max.x - inset_bounds.min.x
	var depth = inset_bounds.max.y - inset_bounds.min.y

	if width < LIGHT_WIDTH or depth < LIGHT_DEPTH:
		return  # Building too small for ceiling lights

	# Generate light panels in a grid
	var num_lights_x = max(1, int(width / LIGHT_SPACING))
	var num_lights_z = max(1, int(depth / LIGHT_SPACING))

	for lx in range(num_lights_x):
		for lz in range(num_lights_z):
			var t_x = (lx + 0.5) / float(num_lights_x) if num_lights_x > 0 else 0.5
			var t_z = (lz + 0.5) / float(num_lights_z) if num_lights_z > 0 else 0.5

			var center_x = inset_bounds.min.x + width * t_x
			var center_z = inset_bounds.min.y + depth * t_z

			_add_light_panel(
				Vector2(center_x, center_z),
				ceiling_y,
				emission,
				glass_surface
			)

## Add a single rectangular light panel
static func _add_light_panel(
	center: Vector2,
	y_pos: float,
	emission: Color,
	glass_surface
) -> void:
	var half_width = LIGHT_WIDTH / 2.0
	var half_depth = LIGHT_DEPTH / 2.0

	# Create rectangle facing UP (positive Y normal) for visibility from outside
	var base_idx = glass_surface.vertices.size()

	# Four corners of the light panel (reversed winding for upward face)
	var v0 = Vector3(center.x - half_width, y_pos, center.y - half_depth)
	var v1 = Vector3(center.x - half_width, y_pos, center.y + half_depth)
	var v2 = Vector3(center.x + half_width, y_pos, center.y + half_depth)
	var v3 = Vector3(center.x + half_width, y_pos, center.y - half_depth)

	var normal = Vector3(0, 1, 0)  # Facing UP for visibility

	# Add vertices
	glass_surface.vertices.append(v0)
	glass_surface.vertices.append(v1)
	glass_surface.vertices.append(v2)
	glass_surface.vertices.append(v3)

	# Add normals
	for i in range(4):
		glass_surface.normals.append(normal)

	# Add UVs
	glass_surface.uvs.append(Vector2(0, 0))
	glass_surface.uvs.append(Vector2(0, 1))
	glass_surface.uvs.append(Vector2(1, 1))
	glass_surface.uvs.append(Vector2(1, 0))

	# DEBUG: Pure white for testing visibility
	var boosted_emission = Color(1.0, 1.0, 1.0, 1.0)

	# Add emission colors (same for all vertices)
	for i in range(4):
		glass_surface.colors.append(boosted_emission)

	# Add indices (two triangles)
	glass_surface.indices.append(base_idx + 0)
	glass_surface.indices.append(base_idx + 1)
	glass_surface.indices.append(base_idx + 2)

	glass_surface.indices.append(base_idx + 0)
	glass_surface.indices.append(base_idx + 2)
	glass_surface.indices.append(base_idx + 3)

## Calculate bounding box from footprint
static func _calculate_bounds(footprint: Array, center: Vector2) -> Dictionary:
	if footprint.is_empty():
		return {"min": Vector2.ZERO, "max": Vector2.ZERO}

	var min_x = INF
	var max_x = -INF
	var min_z = INF
	var max_z = -INF

	for point in footprint:
		var local_point = point - center
		min_x = min(min_x, local_point.x)
		max_x = max(max_x, local_point.x)
		min_z = min(min_z, local_point.y)
		max_z = max(max_z, local_point.y)

	return {
		"min": Vector2(min_x, min_z),
		"max": Vector2(max_x, max_z)
	}

## Create a LODLightProxy for a specific floor
## The proxy manages the actual OmniLight3D based on LOD tier
static func _create_floor_light(context, floor_num: int, emission: Color) -> Node3D:
	var proxy = LODLightProxy.new()
	proxy.name = "InteriorLight_Floor" + str(floor_num)

	# Position at mid-floor height
	var floor_bottom = floor_num * context.floor_height
	var floor_mid = floor_bottom + context.floor_height * 0.5
	proxy.position = Vector3(0, floor_mid, 0)

	# Calculate light parameters
	# Use warm white color (no more debug green!)
	var light_color = Color(1.0, 0.95, 0.85)  # Warm white

	# If emission has meaningful color, use it
	if emission.a > 0.5 and (emission.r > 0.1 or emission.g > 0.1 or emission.b > 0.1):
		light_color = Color(emission.r, emission.g, emission.b)

	# Good interior brightness (was 20.0 debug, 3.0 too dim)
	var light_energy = 10.0  # Visible interior light

	# Range - larger for better city coverage
	var building_size = max(30.0, min(50.0, context.height * 2.0))
	var light_range = building_size

	# Linear attenuation
	var attenuation = 1.0

	# Setup the proxy with light parameters
	proxy.setup(light_energy, light_range, light_color, attenuation)

	return proxy
