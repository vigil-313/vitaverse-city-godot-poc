extends RefCounted
class_name TrafficSignGenerator

## Traffic Sign Generator
## Creates stop signs, yield signs, and speed limit signs at appropriate locations.

const TerrainPathSmoother = preload("res://scripts/terrain/terrain_path_smoother.gd")
const StreetFurniturePlacer = preload("res://scripts/generators/street_furniture/street_furniture_placer.gd")

## Sign types
enum SignType {
	STOP,
	YIELD,
	SPEED_25,
	SPEED_30,
	SPEED_35,
	SPEED_45,
	ONE_WAY
}

## Sign dimensions
const POLE_HEIGHT: float = 2.2
const POLE_RADIUS: float = 0.05
const SIGN_SIZE: float = 0.6  # 60cm signs
const SIGN_OFFSET: float = 3.5  # Distance from road center

## Placement limits
const MAX_SIGNS_PER_CHUNK: int = 50

## Road hierarchy for determining who gets stop signs
const MAJOR_ROADS = ["primary", "secondary", "tertiary", "trunk"]
const MINOR_ROADS = ["residential", "unclassified", "living_street", "service"]


## Generate traffic signs for a chunk
static func create_chunk_signs(
	road_network,
	chunk_key: Vector2i,
	chunk_size: float,
	heightmap,
	parent: Node = null
) -> Node3D:
	var signs_node = Node3D.new()
	signs_node.name = "TrafficSigns_%d_%d" % [chunk_key.x, chunk_key.y]

	var sign_count = 0
	var placed_positions: Array = []

	# Get intersections and segments
	var intersections = road_network.get_intersections_in_chunk(chunk_key, chunk_size)
	var segments = road_network.get_segments_in_chunk(chunk_key, chunk_size)

	# Place stop/yield signs at intersections
	for intersection in intersections:
		if sign_count >= MAX_SIGNS_PER_CHUNK:
			break
		var new_signs = _place_intersection_signs(intersection, heightmap, placed_positions)
		for sign in new_signs:
			signs_node.add_child(sign)
			sign_count += 1

	# Place speed limit signs along segments
	for segment in segments:
		if sign_count >= MAX_SIGNS_PER_CHUNK:
			break
		var speed_sign = _place_speed_limit_sign(segment, heightmap, placed_positions)
		if speed_sign:
			signs_node.add_child(speed_sign)
			sign_count += 1

	if parent:
		parent.add_child(signs_node)

	return signs_node


## Place stop/yield signs at intersection based on road hierarchy
static func _place_intersection_signs(intersection, heightmap, placed_positions: Array) -> Array:
	var signs: Array = []

	if intersection.connections.size() < 2:
		return signs

	# Determine which roads are major vs minor
	var major_connections: Array = []
	var minor_connections: Array = []

	for connection in intersection.connections:
		var segment = connection.get("segment")
		if segment == null:
			continue

		if segment.highway_type in MAJOR_ROADS:
			major_connections.append(connection)
		elif segment.highway_type in MINOR_ROADS:
			minor_connections.append(connection)

	# Place stop signs on minor roads at major/minor intersections
	if major_connections.size() > 0 and minor_connections.size() > 0:
		# Use the placement utility for proper positioning
		var placements = StreetFurniturePlacer.get_stop_sign_placements(
			intersection, minor_connections, heightmap
		)
		for placement in placements:
			if not StreetFurniturePlacer.is_position_valid(placement.position, placed_positions, 4.0):
				continue
			placed_positions.append(placement.position)

			var sign_node = _create_sign_mesh(SignType.STOP)
			sign_node.position = placement.position
			sign_node.rotation.y = atan2(placement.facing.x, -placement.facing.y)
			signs.append(sign_node)

	# At 4-way intersections of similar roads, place stop signs on 2 sides
	elif intersection.connections.size() == 4 and minor_connections.size() >= 3:
		var selected_connections: Array = []
		for i in range(0, minor_connections.size(), 2):
			if selected_connections.size() >= 2:
				break
			selected_connections.append(minor_connections[i])

		var placements = StreetFurniturePlacer.get_stop_sign_placements(
			intersection, selected_connections, heightmap
		)
		for placement in placements:
			if not StreetFurniturePlacer.is_position_valid(placement.position, placed_positions, 4.0):
				continue
			placed_positions.append(placement.position)

			var sign_node = _create_sign_mesh(SignType.STOP)
			sign_node.position = placement.position
			sign_node.rotation.y = atan2(placement.facing.x, -placement.facing.y)
			signs.append(sign_node)

	# One-way signs for one-way streets
	for connection in intersection.connections:
		var segment = connection.get("segment")
		if segment and segment.is_oneway:
			var placements = StreetFurniturePlacer.get_stop_sign_placements(
				intersection, [connection], heightmap
			)
			if not placements.is_empty():
				var placement = placements[0]
				if StreetFurniturePlacer.is_position_valid(placement.position, placed_positions, 4.0):
					placed_positions.append(placement.position)

					var sign_node = _create_sign_mesh(SignType.ONE_WAY)
					sign_node.position = placement.position
					sign_node.rotation.y = atan2(placement.facing.x, -placement.facing.y)
					signs.append(sign_node)
			break  # Only one per intersection

	return signs


## Place speed limit sign along a road segment
static func _place_speed_limit_sign(segment, heightmap, placed_positions: Array) -> Node3D:
	# Only place on longer segments, and not too frequently
	if segment.length < 100.0:
		return null

	# Determine speed based on road type
	var sign_type = _get_speed_sign_for_road(segment.highway_type)
	if sign_type == -1:
		return null

	# Use segment hash for deterministic placement
	var seg_hash = hash(segment.segment_id)
	if seg_hash % 5 != 0:  # Only 20% of eligible segments get signs
		return null

	# Use utility to get proper road edge position at 1/3 along segment
	var placement = StreetFurniturePlacer.get_road_edge_position(
		segment, 0.33, "right", heightmap, 2.5
	)
	if placement.is_empty():
		return null

	# Check distance from existing signs
	if not StreetFurniturePlacer.is_position_valid(placement.position, placed_positions, 30.0):
		return null

	placed_positions.append(placement.position)

	var sign_node = _create_sign_mesh(sign_type)
	sign_node.position = placement.position
	sign_node.rotation.y = atan2(placement.direction.x, -placement.direction.y)

	return sign_node


## Get appropriate speed sign for road type
static func _get_speed_sign_for_road(highway_type: String) -> int:
	match highway_type:
		"residential", "living_street":
			return SignType.SPEED_25
		"tertiary", "unclassified":
			return SignType.SPEED_30
		"secondary":
			return SignType.SPEED_35
		"primary", "trunk":
			return SignType.SPEED_45
		_:
			return -1


## Create sign mesh
static func _create_sign_mesh(sign_type: SignType) -> Node3D:
	var sign_node = Node3D.new()
	sign_node.name = "TrafficSign_" + SignType.keys()[sign_type]

	# Create pole
	var pole = _create_pole_mesh()
	sign_node.add_child(pole)

	# Create sign face
	var sign_face = _create_sign_face(sign_type)
	sign_face.position.y = POLE_HEIGHT
	sign_node.add_child(sign_face)

	return sign_node


## Create pole mesh
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
	material.albedo_color = Color(0.4, 0.4, 0.4)  # Gray metal
	material.metallic = 0.3
	material.roughness = 0.7
	mesh.surface_set_material(0, material)

	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	return instance


## Create sign face based on type
static func _create_sign_face(sign_type: SignType) -> Node3D:
	var face_node = Node3D.new()

	# Create backing mesh
	var mesh_instance = MeshInstance3D.new()
	var mesh: ArrayMesh

	match sign_type:
		SignType.STOP:
			mesh = _create_octagon_mesh(SIGN_SIZE / 2.0, Color(0.8, 0.0, 0.0))  # Red
		SignType.YIELD:
			mesh = _create_triangle_mesh(SIGN_SIZE / 2.0, Color(0.8, 0.0, 0.0))  # Red
		SignType.ONE_WAY:
			mesh = _create_rectangle_mesh(SIGN_SIZE * 1.5, SIGN_SIZE * 0.4, Color(0.1, 0.1, 0.1))  # Black
		_:  # Speed limit signs
			mesh = _create_rectangle_mesh(SIGN_SIZE * 0.8, SIGN_SIZE, Color(1.0, 1.0, 1.0))  # White

	mesh_instance.mesh = mesh
	face_node.add_child(mesh_instance)

	# Add text label
	var label = Label3D.new()
	label.position.z = 0.02

	match sign_type:
		SignType.STOP:
			label.text = "STOP"
			label.font_size = 64
			label.modulate = Color(1, 1, 1)
		SignType.YIELD:
			label.text = "YIELD"
			label.font_size = 48
			label.modulate = Color(1, 1, 1)
		SignType.ONE_WAY:
			label.text = "ONE WAY"
			label.font_size = 40
			label.modulate = Color(1, 1, 1)
		SignType.SPEED_25:
			label.text = "25"
			label.font_size = 72
			label.modulate = Color(0, 0, 0)
		SignType.SPEED_30:
			label.text = "30"
			label.font_size = 72
			label.modulate = Color(0, 0, 0)
		SignType.SPEED_35:
			label.text = "35"
			label.font_size = 72
			label.modulate = Color(0, 0, 0)
		SignType.SPEED_45:
			label.text = "45"
			label.font_size = 72
			label.modulate = Color(0, 0, 0)

	label.pixel_size = 0.002
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.no_depth_test = false
	face_node.add_child(label)

	return face_node


## Create octagon mesh (for stop signs)
static func _create_octagon_mesh(radius: float, color: Color) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var center_front = Vector3(0, 0, 0.01)
	var center_back = Vector3(0, 0, -0.01)
	var points_front: Array = []
	var points_back: Array = []

	for i in range(8):
		var angle = TAU * i / 8.0 - PI / 8.0
		points_front.append(Vector3(cos(angle) * radius, sin(angle) * radius, 0.01))
		points_back.append(Vector3(cos(angle) * radius, sin(angle) * radius, -0.01))

	# Front face - counter-clockwise when viewed from +Z
	for i in range(8):
		st.set_normal(Vector3(0, 0, 1))
		st.add_vertex(center_front)
		st.add_vertex(points_front[(i + 1) % 8])
		st.add_vertex(points_front[i])

	# Back face - counter-clockwise when viewed from -Z
	for i in range(8):
		st.set_normal(Vector3(0, 0, -1))
		st.add_vertex(center_back)
		st.add_vertex(points_back[i])
		st.add_vertex(points_back[(i + 1) % 8])

	var mesh = st.commit()

	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.5
	mesh.surface_set_material(0, material)

	return mesh


## Create triangle mesh (for yield signs)
static func _create_triangle_mesh(radius: float, color: Color) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Front face points
	var p1_f = Vector3(0, radius, 0.01)
	var p2_f = Vector3(-radius * 0.866, -radius * 0.5, 0.01)
	var p3_f = Vector3(radius * 0.866, -radius * 0.5, 0.01)

	# Back face points
	var p1_b = Vector3(0, radius, -0.01)
	var p2_b = Vector3(-radius * 0.866, -radius * 0.5, -0.01)
	var p3_b = Vector3(radius * 0.866, -radius * 0.5, -0.01)

	# Front face - CCW when viewed from +Z
	st.set_normal(Vector3(0, 0, 1))
	st.add_vertex(p1_f)
	st.add_vertex(p3_f)
	st.add_vertex(p2_f)

	# Back face - CCW when viewed from -Z
	st.set_normal(Vector3(0, 0, -1))
	st.add_vertex(p1_b)
	st.add_vertex(p2_b)
	st.add_vertex(p3_b)

	var mesh = st.commit()

	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.5
	mesh.surface_set_material(0, material)

	return mesh


## Create rectangle mesh (for speed limit and one-way signs)
static func _create_rectangle_mesh(width: float, height: float, color: Color) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var hw = width / 2.0
	var hh = height / 2.0

	# Front face - CCW when viewed from +Z
	st.set_normal(Vector3(0, 0, 1))
	st.add_vertex(Vector3(-hw, -hh, 0.01))
	st.add_vertex(Vector3(hw, -hh, 0.01))
	st.add_vertex(Vector3(hw, hh, 0.01))

	st.set_normal(Vector3(0, 0, 1))
	st.add_vertex(Vector3(-hw, -hh, 0.01))
	st.add_vertex(Vector3(hw, hh, 0.01))
	st.add_vertex(Vector3(-hw, hh, 0.01))

	# Back face - CCW when viewed from -Z
	st.set_normal(Vector3(0, 0, -1))
	st.add_vertex(Vector3(hw, -hh, -0.01))
	st.add_vertex(Vector3(-hw, -hh, -0.01))
	st.add_vertex(Vector3(-hw, hh, -0.01))

	st.set_normal(Vector3(0, 0, -1))
	st.add_vertex(Vector3(hw, -hh, -0.01))
	st.add_vertex(Vector3(-hw, hh, -0.01))
	st.add_vertex(Vector3(hw, hh, -0.01))

	var mesh = st.commit()

	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.5
	mesh.surface_set_material(0, material)

	return mesh
