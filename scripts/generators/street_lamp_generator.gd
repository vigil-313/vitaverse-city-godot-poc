extends RefCounted
class_name StreetLampGenerator

## Street Lamp Generator
## Creates street lights along roads for urban lighting

## Lamp placement settings
const LAMP_SPACING = 200.0  # Place lamp every 200m (fewer for performance, buildings have interior lights)
const CURB_WIDTH = 0.25  # 25cm curb width (must match road_generator.gd)
const LAMP_SETBACK = 1.0  # 1m setback from curb edge onto sidewalk
const LAMP_HEIGHT = 5.0  # 5m tall lamp posts
const POLE_RADIUS = 0.15  # 15cm radius pole

## Add street lamps along a road path
static func add_lamps_along_road(road_path: Array, parent: Node3D, road_data: Dictionary = {}) -> void:
	if road_path.size() < 2:
		return

	# Get road width from road data
	var highway_type = road_data.get("highway_type", "residential")
	var road_width = _get_road_width(highway_type)

	# Calculate sidewalk lamp offset: half road width + curb width + setback
	var lamp_offset = (road_width / 2.0) + CURB_WIDTH + LAMP_SETBACK

	# Calculate total road length and place lamps at intervals
	var distance_along_road = 0.0
	var lamp_count = 0

	for i in range(road_path.size() - 1):
		var p1 = road_path[i]
		var p2 = road_path[i + 1]
		var segment_length = p1.distance_to(p2)
		var direction = (p2 - p1).normalized()

		# Calculate perpendicular direction (to the right of the road)
		var perpendicular = Vector2(-direction.y, direction.x)

		# Place lamps along this segment
		var offset_on_segment = 0.0

		# Start from previous distance to maintain spacing
		var next_lamp_distance = LAMP_SPACING - fmod(distance_along_road, LAMP_SPACING)

		while offset_on_segment + next_lamp_distance < segment_length:
			offset_on_segment += next_lamp_distance

			# Calculate lamp position at road center
			var t = offset_on_segment / segment_length
			var lamp_pos_2d = p1.lerp(p2, t)

			# Alternate sides for each lamp (left/right of road)
			var side = 1 if (lamp_count % 2 == 0) else -1
			lamp_pos_2d += perpendicular * lamp_offset * side

			# Create lamp
			_create_street_lamp(parent, lamp_pos_2d, lamp_count)

			lamp_count += 1
			next_lamp_distance = LAMP_SPACING

		distance_along_road += segment_length

	# Only print if lamps were created
	if lamp_count > 0:
		print("🔦 Created ", lamp_count, " lamps for ", highway_type, " road (", "%.0f" % distance_along_road, "m)")

## Get road width based on highway type (mirrors road_generator.gd)
static func _get_road_width(highway_type: String) -> float:
	match highway_type:
		"motorway", "trunk":
			return 20.0  # 4-6 lanes
		"primary":
			return 14.0  # 3-4 lanes
		"secondary":
			return 12.0  # 2-3 lanes
		"tertiary":
			return 10.0  # 2 lanes
		"residential", "unclassified":
			return 8.0   # 2 lanes
		"service":
			return 6.0   # 1-2 lanes
		"footway", "path", "cycleway", "steps":
			return 3.0   # Pedestrian/bike
		_:
			return 8.0   # Default residential width

## Create a single street lamp at position
static func _create_street_lamp(parent: Node3D, pos_2d: Vector2, lamp_id: int) -> void:
	# Load the StreetLamp script
	var street_lamp_script = load("res://scripts/components/street_lamp.gd")

	var lamp = Node3D.new()
	lamp.name = "StreetLamp_" + str(lamp_id)
	lamp.position = Vector3(pos_2d.x, 0, -pos_2d.y)

	# Create pole (cylinder)
	var pole = MeshInstance3D.new()
	pole.name = "Pole"

	var cylinder = CylinderMesh.new()
	cylinder.top_radius = POLE_RADIUS
	cylinder.bottom_radius = POLE_RADIUS
	cylinder.height = LAMP_HEIGHT
	pole.mesh = cylinder

	# Position pole center at half height
	pole.position.y = LAMP_HEIGHT / 2.0

	# Dark gray metal material
	var pole_material = StandardMaterial3D.new()
	pole_material.albedo_color = Color(0.2, 0.2, 0.22)
	pole_material.roughness = 0.7
	pole_material.metallic = 0.6
	pole.material_override = pole_material

	lamp.add_child(pole)

	# Create light fixture (large sphere for wide, soft glow)
	var fixture = MeshInstance3D.new()
	fixture.name = "Fixture"

	# Use sphere instead of box for softer, more diffuse glow
	var sphere = SphereMesh.new()
	sphere.radius = 0.8  # Large soft glow (was 0.3 box)
	sphere.height = 1.6
	fixture.mesh = sphere
	fixture.position.y = LAMP_HEIGHT

	# Load shader for time-of-day control
	var shader = load("res://shaders/street_lamp_bulb.gdshader")
	var fixture_material = ShaderMaterial.new()
	fixture_material.shader = shader
	fixture.material_override = fixture_material

	lamp.add_child(fixture)

	# Create SpotLight3D pointing down
	var light = SpotLight3D.new()
	light.name = "Light"
	light.position.y = LAMP_HEIGHT
	# Rotate to point straight down (SpotLight points along -Z by default)
	# -90° around X rotates -Z to -Y (downward)
	light.rotation_degrees = Vector3(-90, 0, 0)  # Point straight down

	# Light properties - fewer lamps (150m apart), make each VERY strong
	light.spot_range = 60.0  # Large range to cover 150m spacing
	light.spot_angle = 85.0  # Very wide cone
	light.light_color = Color(1.0, 0.95, 0.85)  # Warm street light
	light.light_energy = 25.0  # Very bright to compensate for spacing
	light.light_indirect_energy = 2.5  # Strong bounce light
	light.light_specular = 1.0  # Maximum specular
	light.light_volumetric_fog_energy = 2.5  # Visible in fog
	light.shadow_enabled = false  # Disable shadows for performance (too many lamps)
	light.shadow_bias = 0.1

	lamp.add_child(light)

	parent.add_child(lamp)

	# Attach the script AFTER all children are added and lamp is in the tree
	lamp.set_script(street_lamp_script)

	# Manually call initialize() since _ready() won't fire when script is attached to existing node
	if lamp.has_method("initialize"):
		lamp.initialize()
	else:
		push_error("[StreetLampGenerator] ERROR: lamp doesn't have initialize() method!")

	# Debug (disabled to reduce spam)
	# print("  🔦 Street lamp placed at (", pos_2d.x, ", ", pos_2d.y, ")")

## Enable shadows on nearest N lamps to camera (performance optimization)
static func update_lamp_shadows(lamps: Array, camera_pos: Vector3, max_shadowed: int = 10) -> void:
	# Sort lamps by distance to camera
	var lamp_distances = []
	for lamp in lamps:
		if not is_instance_valid(lamp):
			continue
		var distance = camera_pos.distance_to(lamp.global_position)
		lamp_distances.append({"lamp": lamp, "distance": distance})

	lamp_distances.sort_custom(func(a, b): return a["distance"] < b["distance"])

	# Enable shadows on closest lamps only
	for i in range(lamp_distances.size()):
		var lamp_node = lamp_distances[i]["lamp"]
		var light = lamp_node.find_child("Light")

		if light and light is SpotLight3D:
			light.shadow_enabled = (i < max_shadowed)
