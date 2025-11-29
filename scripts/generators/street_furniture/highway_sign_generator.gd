extends RefCounted
class_name HighwaySignGenerator

## Highway Sign Generator
## Creates green directional signs for major roads with destinations.
## Uses OSM destination tags when available, otherwise generates contextual signs.

const TerrainPathSmoother = preload("res://scripts/terrain/terrain_path_smoother.gd")

## Sign dimensions
const SIGN_HEIGHT: float = 1.2       # 1.2m tall signs
const SIGN_WIDTH_PER_CHAR: float = 0.15
const SIGN_MIN_WIDTH: float = 2.0
const SIGN_MAX_WIDTH: float = 4.0
const POLE_HEIGHT: float = 5.0       # Tall poles for highway signs
const POLE_RADIUS: float = 0.08
const SIGN_ELEVATION: float = 4.5    # Height of sign above ground

## Placement
const MAX_SIGNS_PER_CHUNK: int = 15
const MIN_DISTANCE_BETWEEN: float = 100.0

## Road types that get highway signs
const HIGHWAY_ROADS = ["motorway", "trunk", "primary", "motorway_link", "trunk_link", "primary_link"]

## Common Seattle area destinations for contextual signs
const SEATTLE_DESTINATIONS = [
	"Downtown Seattle",
	"Seattle Center",
	"University District",
	"Capitol Hill",
	"Fremont",
	"Ballard",
	"West Seattle",
	"Bellevue",
	"Tacoma",
	"Sea-Tac Airport",
	"I-5 North",
	"I-5 South",
	"SR 99",
	"I-90 East"
]


## Generate highway signs for a chunk
static func create_chunk_signs(
	road_network,
	chunk_key: Vector2i,
	chunk_size: float,
	heightmap,
	parent: Node = null
) -> Node3D:
	var signs_node = Node3D.new()
	signs_node.name = "HighwaySigns_%d_%d" % [chunk_key.x, chunk_key.y]

	var sign_count = 0
	var placed_positions: Array = []

	# Get segments in chunk
	var segments = road_network.get_segments_in_chunk(chunk_key, chunk_size)
	var intersections = road_network.get_intersections_in_chunk(chunk_key, chunk_size)

	# Place directional signs at highway intersections
	for intersection in intersections:
		if sign_count >= MAX_SIGNS_PER_CHUNK:
			break

		var sign = _place_intersection_highway_sign(intersection, heightmap, placed_positions)
		if sign:
			signs_node.add_child(sign)
			sign_count += 1

	# Place overhead signs along highway segments
	for segment in segments:
		if sign_count >= MAX_SIGNS_PER_CHUNK:
			break

		if segment.highway_type in HIGHWAY_ROADS:
			var sign = _place_segment_highway_sign(segment, heightmap, placed_positions)
			if sign:
				signs_node.add_child(sign)
				sign_count += 1

	if parent:
		parent.add_child(signs_node)

	return signs_node


## Place directional sign at highway intersection
static func _place_intersection_highway_sign(intersection, heightmap, placed_positions: Array) -> Node3D:
	# Only at intersections involving highways
	var has_highway = false
	var highway_segment = null

	for connection in intersection.connections:
		var segment = connection.get("segment")
		if segment and segment.highway_type in HIGHWAY_ROADS:
			has_highway = true
			highway_segment = segment
			break

	if not has_highway:
		return null

	# Need at least 3 connections for a meaningful directional sign
	if intersection.connections.size() < 3:
		return null

	# Get elevation
	var elevation = 0.0
	if heightmap:
		elevation = TerrainPathSmoother.get_smoothed_elevation(
			intersection.position, heightmap, 5.0
		)

	var sign_pos_3d = Vector3(intersection.position.x, elevation, -intersection.position.y)

	# Check distance from existing signs
	for existing in placed_positions:
		if sign_pos_3d.distance_to(existing) < MIN_DISTANCE_BETWEEN:
			return null

	placed_positions.append(sign_pos_3d)

	# Get destination text
	var destinations = _get_destinations_for_intersection(intersection, highway_segment)
	if destinations.is_empty():
		return null

	return _create_overhead_sign(sign_pos_3d, destinations, 0.0)


## Place highway sign along segment
static func _place_segment_highway_sign(segment, heightmap, placed_positions: Array) -> Node3D:
	# Only on longer highway segments
	if segment.length < 200.0:
		return null

	# Use hash for deterministic but sparse placement
	var seg_hash = hash(segment.segment_id)
	if seg_hash % 8 != 0:  # ~12% of eligible segments
		return null

	# Position at middle of segment
	var path = segment.path
	if path.size() < 2:
		return null

	var mid_idx = path.size() / 2
	var sign_pos_2d = path[mid_idx]

	# Get elevation
	var elevation = 0.0
	if heightmap:
		elevation = heightmap.get_elevation(sign_pos_2d.x, -sign_pos_2d.y)

	var sign_pos_3d = Vector3(sign_pos_2d.x, elevation, -sign_pos_2d.y)

	# Check distance
	for existing in placed_positions:
		if sign_pos_3d.distance_to(existing) < MIN_DISTANCE_BETWEEN:
			return null

	placed_positions.append(sign_pos_3d)

	# Get destinations
	var destinations = _get_destinations_for_segment(segment)

	# Calculate road direction for sign orientation
	var dir = Vector2.RIGHT
	if mid_idx > 0 and mid_idx < path.size() - 1:
		dir = (path[mid_idx + 1] - path[mid_idx - 1]).normalized()

	var rotation = atan2(dir.x, -dir.y)

	return _create_overhead_sign(sign_pos_3d, destinations, rotation)


## Get destination text for intersection
static func _get_destinations_for_intersection(intersection, highway_segment) -> Array:
	var destinations: Array = []

	# Check OSM destination tags
	if highway_segment and highway_segment.all_tags.has("destination"):
		var dest = highway_segment.all_tags.get("destination")
		destinations.append(dest)

	if highway_segment and highway_segment.all_tags.has("destination:ref"):
		var ref = highway_segment.all_tags.get("destination:ref")
		destinations.append(ref)

	# If no OSM data, generate contextual destinations
	if destinations.is_empty():
		var rng = RandomNumberGenerator.new()
		rng.seed = hash(str(intersection.node_id))

		# Pick 1-2 random Seattle destinations
		var num_dest = rng.randi_range(1, 2)
		var shuffled = SEATTLE_DESTINATIONS.duplicate()
		shuffled.shuffle()
		for i in range(mini(num_dest, shuffled.size())):
			destinations.append(shuffled[i])

	return destinations


## Get destination text for segment
static func _get_destinations_for_segment(segment) -> Array:
	var destinations: Array = []

	# Check OSM tags
	if segment.all_tags.has("destination"):
		destinations.append(segment.all_tags.get("destination"))

	if segment.all_tags.has("destination:ref"):
		destinations.append(segment.all_tags.get("destination:ref"))

	# Check for route ref (like "I-5", "SR 99")
	if segment.all_tags.has("ref"):
		destinations.append(segment.all_tags.get("ref"))

	# Generate if empty
	if destinations.is_empty():
		var rng = RandomNumberGenerator.new()
		rng.seed = hash(segment.segment_id)

		var idx = rng.randi() % SEATTLE_DESTINATIONS.size()
		destinations.append(SEATTLE_DESTINATIONS[idx])

	return destinations


## Create overhead highway sign
static func _create_overhead_sign(position: Vector3, destinations: Array, rotation: float) -> Node3D:
	var sign_node = Node3D.new()
	sign_node.name = "HighwaySign"
	sign_node.position = position
	sign_node.rotation.y = rotation

	# Create support poles (two poles for overhead sign)
	var pole_spacing = 3.0
	var pole1 = _create_pole_mesh()
	pole1.position.x = -pole_spacing / 2.0
	sign_node.add_child(pole1)

	var pole2 = _create_pole_mesh()
	pole2.position.x = pole_spacing / 2.0
	sign_node.add_child(pole2)

	# Create horizontal beam
	var beam = _create_beam_mesh(pole_spacing)
	beam.position.y = POLE_HEIGHT
	sign_node.add_child(beam)

	# Create sign panel
	var panel = _create_sign_panel(destinations)
	panel.position.y = SIGN_ELEVATION
	sign_node.add_child(panel)

	return sign_node


## Create support pole
static func _create_pole_mesh() -> MeshInstance3D:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var segments = 6
	for i in range(segments):
		var angle1 = TAU * i / segments
		var angle2 = TAU * (i + 1) / segments

		var x1 = cos(angle1) * POLE_RADIUS
		var z1 = sin(angle1) * POLE_RADIUS
		var x2 = cos(angle2) * POLE_RADIUS
		var z2 = sin(angle2) * POLE_RADIUS

		st.add_vertex(Vector3(x1, 0, z1))
		st.add_vertex(Vector3(x2, 0, z2))
		st.add_vertex(Vector3(x2, POLE_HEIGHT, z2))

		st.add_vertex(Vector3(x1, 0, z1))
		st.add_vertex(Vector3(x2, POLE_HEIGHT, z2))
		st.add_vertex(Vector3(x1, POLE_HEIGHT, z1))

	st.generate_normals()
	var mesh = st.commit()

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.3, 0.3)
	material.metallic = 0.4
	material.roughness = 0.6
	mesh.surface_set_material(0, material)

	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	return instance


## Create horizontal beam between poles
static func _create_beam_mesh(width: float) -> MeshInstance3D:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var beam_height = 0.15
	var beam_depth = 0.1
	var hw = width / 2.0

	# Simple box for beam
	var vertices = [
		Vector3(-hw, 0, -beam_depth/2), Vector3(hw, 0, -beam_depth/2),
		Vector3(hw, beam_height, -beam_depth/2), Vector3(-hw, beam_height, -beam_depth/2),
		Vector3(-hw, 0, beam_depth/2), Vector3(hw, 0, beam_depth/2),
		Vector3(hw, beam_height, beam_depth/2), Vector3(-hw, beam_height, beam_depth/2)
	]

	# Front face
	st.add_vertex(vertices[0]); st.add_vertex(vertices[1]); st.add_vertex(vertices[2])
	st.add_vertex(vertices[0]); st.add_vertex(vertices[2]); st.add_vertex(vertices[3])

	# Back face
	st.add_vertex(vertices[5]); st.add_vertex(vertices[4]); st.add_vertex(vertices[7])
	st.add_vertex(vertices[5]); st.add_vertex(vertices[7]); st.add_vertex(vertices[6])

	# Top face
	st.add_vertex(vertices[3]); st.add_vertex(vertices[2]); st.add_vertex(vertices[6])
	st.add_vertex(vertices[3]); st.add_vertex(vertices[6]); st.add_vertex(vertices[7])

	# Bottom face
	st.add_vertex(vertices[4]); st.add_vertex(vertices[5]); st.add_vertex(vertices[1])
	st.add_vertex(vertices[4]); st.add_vertex(vertices[1]); st.add_vertex(vertices[0])

	st.generate_normals()
	var mesh = st.commit()

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.3, 0.3)
	material.metallic = 0.4
	mesh.surface_set_material(0, material)

	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	return instance


## Create green sign panel with destinations
static func _create_sign_panel(destinations: Array) -> Node3D:
	var panel_node = Node3D.new()

	# Calculate sign width based on longest destination
	var max_len = 10
	for dest in destinations:
		if dest.length() > max_len:
			max_len = dest.length()

	var sign_width = clampf(max_len * SIGN_WIDTH_PER_CHAR, SIGN_MIN_WIDTH, SIGN_MAX_WIDTH)
	var sign_height = SIGN_HEIGHT * mini(destinations.size(), 3)

	# Create green backing
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var hw = sign_width / 2.0
	var hh = sign_height / 2.0

	st.set_normal(Vector3(0, 0, 1))
	st.add_vertex(Vector3(-hw, -hh, 0))
	st.add_vertex(Vector3(hw, -hh, 0))
	st.add_vertex(Vector3(hw, hh, 0))

	st.add_vertex(Vector3(-hw, -hh, 0))
	st.add_vertex(Vector3(hw, hh, 0))
	st.add_vertex(Vector3(-hw, hh, 0))

	# Back face
	st.set_normal(Vector3(0, 0, -1))
	st.add_vertex(Vector3(hw, -hh, -0.05))
	st.add_vertex(Vector3(-hw, -hh, -0.05))
	st.add_vertex(Vector3(-hw, hh, -0.05))

	st.add_vertex(Vector3(hw, -hh, -0.05))
	st.add_vertex(Vector3(-hw, hh, -0.05))
	st.add_vertex(Vector3(hw, hh, -0.05))

	var mesh = st.commit()

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.0, 0.35, 0.15)  # Highway green
	material.roughness = 0.7
	mesh.surface_set_material(0, material)

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	panel_node.add_child(mesh_instance)

	# Add destination text labels
	var y_offset = hh - 0.3
	for i in range(mini(destinations.size(), 3)):
		var label = Label3D.new()
		label.text = destinations[i].to_upper()
		label.font_size = 48
		label.modulate = Color(1, 1, 1)  # White text
		label.outline_size = 0
		label.pixel_size = 0.004
		label.position = Vector3(0, y_offset - i * 0.4, 0.02)
		label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		panel_node.add_child(label)

	return panel_node
