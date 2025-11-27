extends Node
class_name RooftopEquipment

## Rooftop equipment generator
## Creates AC units, vents, and chimneys on building roofs

const GeometryUtils = preload("res://scripts/generators/building/core/geometry_utils.gd")

## Equipment dimensions
const AC_UNIT_SIZE = Vector3(1.0, 0.7, 0.6)      # W, H, D
const VENT_SIZE = Vector3(0.4, 0.5, 0.4)         # W, H, D
const CHIMNEY_SIZE = Vector3(0.5, 1.2, 0.5)      # W, H, D

## Placement parameters
const MIN_ROOF_AREA = 20.0        # Minimum roof area for equipment
const EQUIPMENT_INSET = 1.5       # Distance from roof edge
const AC_UNIT_CHANCE = 0.7        # 70% chance for AC on commercial
const CHIMNEY_CHANCE = 0.5        # 50% chance for chimney on residential
const VENT_CHANCE = 0.6           # 60% chance for vents

## Commercial building types
const COMMERCIAL_TYPES = ["commercial", "retail", "office", "shop", "supermarket", "mall", "store"]

## Main entry point - generates rooftop equipment
static func generate(
	context,
	wall_surface
) -> void:
	# Calculate roof area
	var roof_area = _calculate_polygon_area(context.footprint, context.center)
	if roof_area < MIN_ROOF_AREA:
		return

	var roof_y = context.height + 0.05  # Match flat roof height

	# Determine equipment type based on building
	var is_commercial = _is_commercial(context.building_type)

	# Generate equipment based on building type
	var rng = RandomNumberGenerator.new()
	rng.seed = context.building_id

	if is_commercial:
		# Commercial: AC units
		if rng.randf() < AC_UNIT_CHANCE:
			_generate_ac_units(context.footprint, context.center, roof_y, rng, wall_surface)
	else:
		# Residential: chimneys
		if rng.randf() < CHIMNEY_CHANCE:
			_generate_chimney(context.footprint, context.center, roof_y, rng, wall_surface)

	# All buildings can have vents
	if rng.randf() < VENT_CHANCE:
		_generate_vents(context.footprint, context.center, roof_y, rng, wall_surface)

## Generate AC units for commercial buildings
static func _generate_ac_units(
	footprint: Array,
	center: Vector2,
	roof_y: float,
	rng: RandomNumberGenerator,
	wall_surface
) -> void:
	var bounds = GeometryUtils.calculate_bounding_box(footprint)
	var local_center = Vector2(bounds.position.x + bounds.size.x / 2.0, bounds.position.y + bounds.size.y / 2.0) - center

	# Place 1-3 AC units
	var num_units = rng.randi_range(1, 3)

	for i in range(num_units):
		var offset_x = rng.randf_range(-bounds.size.x * 0.3, bounds.size.x * 0.3)
		var offset_z = rng.randf_range(-bounds.size.y * 0.3, bounds.size.y * 0.3)

		var pos = Vector3(local_center.x + offset_x, roof_y, -(local_center.y + offset_z))
		_add_box(pos, AC_UNIT_SIZE, wall_surface)

## Generate chimney for residential buildings
static func _generate_chimney(
	footprint: Array,
	center: Vector2,
	roof_y: float,
	rng: RandomNumberGenerator,
	wall_surface
) -> void:
	var bounds = GeometryUtils.calculate_bounding_box(footprint)
	var local_center = Vector2(bounds.position.x + bounds.size.x / 2.0, bounds.position.y + bounds.size.y / 2.0) - center

	# Place chimney off-center (typically near edge)
	var offset_x = rng.randf_range(bounds.size.x * 0.1, bounds.size.x * 0.35)
	var offset_z = rng.randf_range(-bounds.size.y * 0.2, bounds.size.y * 0.2)

	if rng.randf() > 0.5:
		offset_x = -offset_x

	var pos = Vector3(local_center.x + offset_x, roof_y, -(local_center.y + offset_z))
	_add_box(pos, CHIMNEY_SIZE, wall_surface)

## Generate vents
static func _generate_vents(
	footprint: Array,
	center: Vector2,
	roof_y: float,
	rng: RandomNumberGenerator,
	wall_surface
) -> void:
	var bounds = GeometryUtils.calculate_bounding_box(footprint)
	var local_center = Vector2(bounds.position.x + bounds.size.x / 2.0, bounds.position.y + bounds.size.y / 2.0) - center

	# Place 1-2 vents
	var num_vents = rng.randi_range(1, 2)

	for i in range(num_vents):
		var offset_x = rng.randf_range(-bounds.size.x * 0.25, bounds.size.x * 0.25)
		var offset_z = rng.randf_range(-bounds.size.y * 0.25, bounds.size.y * 0.25)

		var pos = Vector3(local_center.x + offset_x, roof_y, -(local_center.y + offset_z))
		_add_box(pos, VENT_SIZE, wall_surface)

## Add a box at position
static func _add_box(
	pos: Vector3,
	size: Vector3,
	surface
) -> void:
	var half_w = size.x / 2.0
	var half_d = size.z / 2.0
	var height = size.y

	# Box vertices
	var v = [
		pos + Vector3(-half_w, 0, -half_d),      # 0: bottom front left
		pos + Vector3(half_w, 0, -half_d),       # 1: bottom front right
		pos + Vector3(half_w, 0, half_d),        # 2: bottom back right
		pos + Vector3(-half_w, 0, half_d),       # 3: bottom back left
		pos + Vector3(-half_w, height, -half_d), # 4: top front left
		pos + Vector3(half_w, height, -half_d),  # 5: top front right
		pos + Vector3(half_w, height, half_d),   # 6: top back right
		pos + Vector3(-half_w, height, half_d),  # 7: top back left
	]

	# Add faces
	_add_quad(v[0], v[1], v[5], v[4], Vector3.FORWARD, surface)  # Front
	_add_quad(v[2], v[3], v[7], v[6], Vector3.BACK, surface)     # Back
	_add_quad(v[3], v[0], v[4], v[7], Vector3.LEFT, surface)     # Left
	_add_quad(v[1], v[2], v[6], v[5], Vector3.RIGHT, surface)    # Right
	_add_quad(v[4], v[5], v[6], v[7], Vector3.UP, surface)       # Top

## Helper: Add a quad
static func _add_quad(
	v1: Vector3, v2: Vector3, v3: Vector3, v4: Vector3,
	normal: Vector3,
	surface
) -> void:
	var base_index = surface.vertices.size()

	surface.vertices.append(v1)
	surface.vertices.append(v2)
	surface.vertices.append(v3)
	surface.vertices.append(v4)

	for i in range(4):
		surface.normals.append(normal)

	surface.uvs.append(Vector2(0, 0))
	surface.uvs.append(Vector2(1, 0))
	surface.uvs.append(Vector2(1, 1))
	surface.uvs.append(Vector2(0, 1))

	surface.indices.append(base_index + 0)
	surface.indices.append(base_index + 1)
	surface.indices.append(base_index + 2)
	surface.indices.append(base_index + 0)
	surface.indices.append(base_index + 2)
	surface.indices.append(base_index + 3)

## Calculate polygon area
static func _calculate_polygon_area(footprint: Array, center: Vector2) -> float:
	if footprint.size() < 3:
		return 0.0

	var area = 0.0
	var n = footprint.size()

	for i in range(n):
		var p1 = footprint[i] - center
		var p2 = footprint[(i + 1) % n] - center
		area += p1.x * p2.y - p2.x * p1.y

	return abs(area) / 2.0

## Check if building type is commercial
static func _is_commercial(building_type: String) -> bool:
	var type_lower = building_type.to_lower()
	for commercial in COMMERCIAL_TYPES:
		if type_lower.contains(commercial):
			return true
	return false
