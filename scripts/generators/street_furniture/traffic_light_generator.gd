extends RefCounted
class_name TrafficLightGenerator

## Traffic Light Generator - Realistic US Mast Arm Style
## Creates proper traffic signals at major intersections.
## Mast arm extends over travel lanes with signal heads facing oncoming traffic.
## Supports time-based cycling with coordinated intersection phases.

const TerrainPathSmoother = preload("res://scripts/terrain/terrain_path_smoother.gd")

## Light states
enum LightState { RED, YELLOW, GREEN }

## Cycle timing (in seconds)
const CYCLE_GREEN_DURATION: float = 12.0
const CYCLE_YELLOW_DURATION: float = 3.0
const CYCLE_RED_DURATION: float = 15.0  # Green + Yellow of other direction
const FULL_CYCLE: float = 30.0  # Total cycle time

## Realistic US traffic light dimensions
const POLE_HEIGHT: float = 7.0          # 7m (~23 ft) vertical pole
const POLE_RADIUS: float = 0.15         # 15cm pole diameter
const MAST_ARM_LENGTH: float = 6.0      # 6m arm extending over road
const MAST_ARM_HEIGHT: float = 0.25     # Rectangular arm cross-section
const MAST_ARM_DEPTH: float = 0.20

## Signal head dimensions (realistic 12" signals)
const SIGNAL_HEAD_WIDTH: float = 0.45
const SIGNAL_HEAD_HEIGHT: float = 1.1   # 3 lights + housing
const SIGNAL_HEAD_DEPTH: float = 0.08   # Very thin backplate
const LIGHT_DIAMETER: float = 0.30      # 12" lights
const LIGHT_SPACING: float = 0.32

## Visor/hood dimensions - minimal
const VISOR_LENGTH: float = 0.12
const VISOR_WIDTH: float = 0.32

## Placement parameters
const MAX_LIGHTS_PER_CHUNK: int = 30    # Allow more lights per chunk
const CORNER_OFFSET: float = 3.0        # Distance from road edge
const MIN_SPACING: float = 12.0         # Between lights at same intersection


## Generate traffic lights for a chunk
static func create_chunk_lights(
	road_network,
	chunk_key: Vector2i,
	chunk_size: float,
	heightmap,
	parent: Node = null
) -> Node3D:
	var lights_node = Node3D.new()
	lights_node.name = "TrafficLights_%d_%d" % [chunk_key.x, chunk_key.y]

	var light_count = 0
	var placed_positions: Array = []

	var intersections = road_network.get_intersections_in_chunk(chunk_key, chunk_size)

	for intersection in intersections:
		if light_count >= MAX_LIGHTS_PER_CHUNK:
			break

		# Only at major intersections
		if not intersection.should_have_traffic_lights():
			continue

		# Need proper intersection geometry
		if intersection.connections.size() < 3:
			continue

		# Get elevation
		var elevation = 0.0
		if heightmap:
			elevation = TerrainPathSmoother.get_smoothed_elevation(
				intersection.position, heightmap, 5.0
			)

		# Place one mast arm per approach (incoming road direction)
		var lights_placed = _place_intersection_lights(
			intersection, elevation, placed_positions, lights_node
		)
		light_count += lights_placed

	if parent:
		parent.add_child(lights_node)

	return lights_node


## Place traffic lights at an intersection - one per major approach
static func _place_intersection_lights(
	intersection,
	elevation: float,
	placed_positions: Array,
	parent: Node3D
) -> int:
	var count = 0

	# Collect major road connections (primary, secondary, tertiary)
	var major_connections: Array = []
	for conn in intersection.connections:
		var segment = conn.get("segment")
		if segment and segment.highway_type in ["primary", "secondary", "tertiary", "trunk"]:
			major_connections.append(conn)

	# If no major roads, use all driveable connections
	if major_connections.is_empty():
		for conn in intersection.connections:
			var segment = conn.get("segment")
			if segment and segment.is_driveable():
				major_connections.append(conn)

	# Get intersection phase for synchronized timing
	var intersection_phase = _get_intersection_phase(intersection.position)

	# Place a traffic light for each approach (max 4)
	for i in range(mini(major_connections.size(), 4)):
		var conn = major_connections[i]
		var segment = conn.get("segment")
		if segment == null or segment.path.size() < 2:
			continue

		# Calculate direction traffic travels TOWARD the intersection
		# Use segment path endpoints for robust calculation
		var is_start = conn.get("is_start", false)
		var other_end: Vector2
		if is_start:
			other_end = segment.path[segment.path.size() - 1]
		else:
			other_end = segment.path[0]

		# Traffic direction: from other_end toward intersection
		var traffic_dir = (intersection.position - other_end).normalized()
		var road_width = segment.calculated_width

		# Right perpendicular (US: pole on far-right corner from driver's perspective)
		var right_perp = Vector2(traffic_dir.y, -traffic_dir.x)

		# Pole position: far side of intersection + to the right
		var max_road_width = intersection.get_max_road_width()
		var far_offset = max_road_width / 2.0 + CORNER_OFFSET
		var side_offset = road_width / 2.0 + CORNER_OFFSET

		var pole_pos_2d = intersection.position + traffic_dir * far_offset + right_perp * side_offset
		var pole_pos_3d = Vector3(pole_pos_2d.x, elevation, -pole_pos_2d.y)

		# Check spacing
		var too_close = false
		for existing in placed_positions:
			if pole_pos_3d.distance_to(existing) < MIN_SPACING:
				too_close = true
				break

		if too_close:
			continue

		placed_positions.append(pole_pos_3d)

		# Determine light state based on direction index (for coordinated cycling)
		var light_state = _get_light_state_for_direction(intersection_phase, i)

		# Mast arm extends LEFT from pole (over the road)
		var arm_extends_dir = -right_perp
		# Signal faces BACK toward approaching traffic
		var signal_faces_dir = -traffic_dir
		var light_assembly = _create_mast_arm_light(pole_pos_3d, arm_extends_dir, signal_faces_dir, road_width, light_state)
		parent.add_child(light_assembly)
		count += 1

	return count


## Create a realistic mast arm traffic light
## arm_dir: direction the mast arm extends (2D)
## signal_dir: direction the signal heads should face (2D) - toward oncoming traffic
## light_state: current state of this light (RED, YELLOW, GREEN)
static func _create_mast_arm_light(position: Vector3, arm_dir: Vector2, signal_dir: Vector2, road_width: float, light_state: int = LightState.GREEN) -> Node3D:
	var assembly = Node3D.new()
	assembly.name = "MastArmLight"
	assembly.position = position

	# Convert 2D directions to 3D (y -> -z)
	var arm_vec_3d = Vector3(arm_dir.x, 0, -arm_dir.y).normalized()
	var signal_vec_3d = Vector3(signal_dir.x, 0, -signal_dir.y).normalized()

	# Create vertical pole
	var pole = _create_pole()
	assembly.add_child(pole)

	# Create horizontal mast arm
	var arm_length = minf(MAST_ARM_LENGTH, road_width * 0.8)
	var mast_arm = _create_mast_arm(arm_length)
	mast_arm.position.y = POLE_HEIGHT
	# Orient arm using look_at style - arm extends in its local +Z
	mast_arm.basis = _basis_looking_at(arm_vec_3d)
	assembly.add_child(mast_arm)

	# Primary signal at end of arm
	var primary_signal = _create_signal_head(light_state)
	primary_signal.position = Vector3(0, POLE_HEIGHT - 0.3, 0) + arm_vec_3d * (arm_length - 0.5)
	# Orient signal to face toward traffic (lights on -Z face, so look opposite)
	primary_signal.basis = _basis_looking_at(-signal_vec_3d)
	assembly.add_child(primary_signal)

	# Secondary signal midway on arm (for wide roads)
	if road_width > 8.0:
		var secondary_signal = _create_signal_head(light_state)
		secondary_signal.position = Vector3(0, POLE_HEIGHT - 0.3, 0) + arm_vec_3d * (arm_length * 0.5)
		secondary_signal.basis = _basis_looking_at(-signal_vec_3d)
		assembly.add_child(secondary_signal)

	# Pole-mounted signal
	var pole_signal = _create_signal_head(light_state)
	pole_signal.position = Vector3(0, POLE_HEIGHT - 1.5, 0) + arm_vec_3d * 0.4
	pole_signal.basis = _basis_looking_at(-signal_vec_3d)
	assembly.add_child(pole_signal)

	return assembly


## Create a basis that looks in the given direction (for horizontal objects)
static func _basis_looking_at(direction: Vector3) -> Basis:
	var forward = direction.normalized()
	var up = Vector3.UP
	# Handle case where direction is parallel to up
	if abs(forward.dot(up)) > 0.99:
		up = Vector3.FORWARD
	var right = up.cross(forward).normalized()
	var actual_up = forward.cross(right).normalized()
	return Basis(right, actual_up, forward)


## Create vertical support pole
static func _create_pole() -> MeshInstance3D:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Tapered pole - wider at base
	var segments = 8
	var height_steps = 4
	var base_radius = POLE_RADIUS * 1.2
	var top_radius = POLE_RADIUS

	for h in range(height_steps):
		var y0 = POLE_HEIGHT * h / height_steps
		var y1 = POLE_HEIGHT * (h + 1) / height_steps
		var r0 = lerpf(base_radius, top_radius, float(h) / height_steps)
		var r1 = lerpf(base_radius, top_radius, float(h + 1) / height_steps)

		for i in range(segments):
			var angle1 = TAU * i / segments
			var angle2 = TAU * (i + 1) / segments

			var x1_0 = cos(angle1) * r0
			var z1_0 = sin(angle1) * r0
			var x2_0 = cos(angle2) * r0
			var z2_0 = sin(angle2) * r0

			var x1_1 = cos(angle1) * r1
			var z1_1 = sin(angle1) * r1
			var x2_1 = cos(angle2) * r1
			var z2_1 = sin(angle2) * r1

			st.add_vertex(Vector3(x1_0, y0, z1_0))
			st.add_vertex(Vector3(x2_0, y0, z2_0))
			st.add_vertex(Vector3(x2_1, y1, z2_1))

			st.add_vertex(Vector3(x1_0, y0, z1_0))
			st.add_vertex(Vector3(x2_1, y1, z2_1))
			st.add_vertex(Vector3(x1_1, y1, z1_1))

	st.generate_normals()
	var mesh = st.commit()

	# Dark gray/black powder-coated steel
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.15, 0.15, 0.15)
	material.metallic = 0.6
	material.roughness = 0.4
	mesh.surface_set_material(0, material)

	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	return instance


## Create horizontal mast arm (extends in +Z direction)
static func _create_mast_arm(length: float) -> MeshInstance3D:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Tapered arm - thicker at pole, thinner at end
	var segments = 8
	var length_steps = 3
	var base_radius = MAST_ARM_HEIGHT / 2.0
	var tip_radius = base_radius * 0.6

	for l in range(length_steps):
		var z0 = length * l / length_steps
		var z1 = length * (l + 1) / length_steps
		var r0 = lerpf(base_radius, tip_radius, float(l) / length_steps)
		var r1 = lerpf(base_radius, tip_radius, float(l + 1) / length_steps)

		for i in range(segments):
			var angle1 = TAU * i / segments
			var angle2 = TAU * (i + 1) / segments

			var x1_0 = cos(angle1) * r0
			var y1_0 = sin(angle1) * r0
			var x2_0 = cos(angle2) * r0
			var y2_0 = sin(angle2) * r0

			var x1_1 = cos(angle1) * r1
			var y1_1 = sin(angle1) * r1
			var x2_1 = cos(angle2) * r1
			var y2_1 = sin(angle2) * r1

			st.add_vertex(Vector3(x1_0, y1_0, z0))
			st.add_vertex(Vector3(x2_0, y2_0, z0))
			st.add_vertex(Vector3(x2_1, y2_1, z1))

			st.add_vertex(Vector3(x1_0, y1_0, z0))
			st.add_vertex(Vector3(x2_1, y2_1, z1))
			st.add_vertex(Vector3(x1_1, y1_1, z1))

	st.generate_normals()
	var mesh = st.commit()

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.15, 0.15, 0.15)
	material.metallic = 0.6
	material.roughness = 0.4
	mesh.surface_set_material(0, material)

	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	return instance


## Create signal head using simple built-in primitives
## Lights face LOCAL -Z direction (front of signal)
## state: LightState.RED, LightState.YELLOW, or LightState.GREEN
static func _create_signal_head(state: int) -> Node3D:
	var head = Node3D.new()
	head.name = "SignalHead"

	# Create black housing box (open front) that holds all three lights
	var housing = MeshInstance3D.new()
	var housing_mesh = BoxMesh.new()
	housing_mesh.size = Vector3(SIGNAL_HEAD_WIDTH, SIGNAL_HEAD_HEIGHT, LIGHT_DIAMETER + 0.1)
	housing.mesh = housing_mesh

	var housing_mat = StandardMaterial3D.new()
	housing_mat.albedo_color = Color(0.08, 0.08, 0.08)  # Dark black
	housing_mat.roughness = 0.8
	housing.material_override = housing_mat
	housing.position = Vector3(0, 0, 0)
	head.add_child(housing)

	# Yellow backplate behind housing
	var backplate = MeshInstance3D.new()
	var backplate_mesh = BoxMesh.new()
	backplate_mesh.size = Vector3(SIGNAL_HEAD_WIDTH + 0.08, SIGNAL_HEAD_HEIGHT + 0.08, 0.03)
	backplate.mesh = backplate_mesh

	var backplate_mat = StandardMaterial3D.new()
	backplate_mat.albedo_color = Color(0.85, 0.65, 0.0)  # Safety yellow
	backplate_mat.roughness = 0.7
	backplate.material_override = backplate_mat
	backplate.position = Vector3(0, 0, (LIGHT_DIAMETER + 0.1) / 2.0 + 0.02)
	head.add_child(backplate)

	# Determine which light is lit based on state
	var red_lit = (state == LightState.RED)
	var yellow_lit = (state == LightState.YELLOW)
	var green_lit = (state == LightState.GREEN)

	# Create three lights recessed into the housing
	var light_configs = [
		{"color": Color(1.0, 0.1, 0.1), "lit": red_lit, "y": LIGHT_SPACING},      # Red - top
		{"color": Color(1.0, 0.8, 0.0), "lit": yellow_lit, "y": 0.0},              # Yellow - middle
		{"color": Color(0.1, 1.0, 0.2), "lit": green_lit, "y": -LIGHT_SPACING}     # Green - bottom
	]

	for config in light_configs:
		# Black cylinder housing for each light (open front)
		var light_housing = MeshInstance3D.new()
		var cylinder_mesh = CylinderMesh.new()
		cylinder_mesh.top_radius = LIGHT_DIAMETER / 2.0 + 0.03
		cylinder_mesh.bottom_radius = LIGHT_DIAMETER / 2.0 + 0.03
		cylinder_mesh.height = LIGHT_DIAMETER * 0.6
		cylinder_mesh.radial_segments = 16
		light_housing.mesh = cylinder_mesh
		light_housing.rotation.x = PI / 2.0  # Point forward
		light_housing.position = Vector3(0, config.y, -0.02)

		var cylinder_mat = StandardMaterial3D.new()
		cylinder_mat.albedo_color = Color(0.05, 0.05, 0.05)
		light_housing.material_override = cylinder_mat
		head.add_child(light_housing)

		# Light sphere (hemisphere visible from front)
		var light_sphere = MeshInstance3D.new()
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = LIGHT_DIAMETER / 2.0
		sphere_mesh.height = LIGHT_DIAMETER
		sphere_mesh.radial_segments = 16
		sphere_mesh.rings = 8
		light_sphere.mesh = sphere_mesh
		light_sphere.position = Vector3(0, config.y, -LIGHT_DIAMETER / 2.0 + 0.02)

		var light_mat = StandardMaterial3D.new()
		if config.lit:
			light_mat.albedo_color = config.color
			light_mat.emission_enabled = true
			light_mat.emission = config.color
			light_mat.emission_energy_multiplier = 8.0
			light_mat.roughness = 0.1
		else:
			light_mat.albedo_color = config.color * 0.3
			light_mat.roughness = 0.6
		light_sphere.material_override = light_mat
		head.add_child(light_sphere)

	return head


## Calculate light state based on intersection phase and direction index
## Opposite directions (0,2) and (1,3) get the same state
## Perpendicular directions get opposite states
static func _get_light_state_for_direction(intersection_phase: float, direction_index: int) -> int:
	# Normalize phase to 0-1 range within cycle
	var cycle_pos = fmod(intersection_phase, FULL_CYCLE) / FULL_CYCLE

	# Directions 0,2 are one group, 1,3 are another
	var is_primary_direction = (direction_index % 2 == 0)

	# Offset secondary directions by half cycle
	if not is_primary_direction:
		cycle_pos = fmod(cycle_pos + 0.5, 1.0)

	# Determine state based on position in cycle
	# 0.0-0.4: Green, 0.4-0.5: Yellow, 0.5-1.0: Red
	if cycle_pos < 0.4:
		return LightState.GREEN
	elif cycle_pos < 0.5:
		return LightState.YELLOW
	else:
		return LightState.RED


## Get a stable phase offset for an intersection based on its position
## This ensures consistent behavior and allows for "green wave" coordination
static func _get_intersection_phase(intersection_pos: Vector2) -> float:
	# Use position hash for stable random offset, plus current time
	var pos_hash = hash(Vector2i(int(intersection_pos.x / 50), int(intersection_pos.y / 50)))
	var phase_offset = float(pos_hash % 1000) / 1000.0 * FULL_CYCLE

	# Get current time (use Engine time for consistency)
	var current_time = Time.get_ticks_msec() / 1000.0

	return current_time + phase_offset


## Helper to add a quad
static func _add_quad(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3) -> void:
	st.add_vertex(v0)
	st.add_vertex(v1)
	st.add_vertex(v2)

	st.add_vertex(v0)
	st.add_vertex(v2)
	st.add_vertex(v3)
