extends RefCounted
class_name StreetSignGenerator

## Street Sign Generator
## Creates street name signs at intersections using road network data.
## Signs display actual street names from OSM data.

const TerrainPathSmoother = preload("res://scripts/terrain/terrain_path_smoother.gd")
const StreetFurniturePlacer = preload("res://scripts/generators/street_furniture/street_furniture_placer.gd")

## Sign dimensions
const POLE_HEIGHT: float = 2.5          # 2.5m tall pole
const POLE_RADIUS: float = 0.04         # 4cm pole
const SIGN_WIDTH: float = 0.8           # 80cm wide sign
const SIGN_HEIGHT: float = 0.2          # 20cm tall sign
const SIGN_DEPTH: float = 0.02          # 2cm thick

## Placement
const MAX_SIGNS_PER_CHUNK: int = 40
const MIN_INTERSECTION_ROADS: int = 2   # Need at least 2 roads to make a sign


## Generate street signs for a chunk
static func create_chunk_signs(
	road_network,
	chunk_key: Vector2i,
	chunk_size: float,
	heightmap,
	parent: Node = null
) -> Node3D:
	var signs_node = Node3D.new()
	signs_node.name = "StreetSigns_%d_%d" % [chunk_key.x, chunk_key.y]

	var intersections = road_network.get_intersections_in_chunk(chunk_key, chunk_size)
	var sign_count = 0

	for intersection in intersections:
		if sign_count >= MAX_SIGNS_PER_CHUNK:
			break

		# Only create signs at real intersections with named roads
		if intersection.connections.size() < MIN_INTERSECTION_ROADS:
			continue

		# Collect unique street names at this intersection
		var street_names = _get_intersection_street_names(intersection, road_network)
		if street_names.size() < 2:
			continue

		# Get proper corner placement using the utility
		var placement = StreetFurniturePlacer.get_street_sign_placement(
			intersection, heightmap, road_network
		)
		if placement.is_empty():
			continue

		var sign_pos = placement.position
		var sign_node = _create_sign_post(street_names, sign_pos)

		if sign_node:
			signs_node.add_child(sign_node)
			sign_count += 1

	if parent:
		parent.add_child(signs_node)

	return signs_node


## Get unique street names meeting at intersection
static func _get_intersection_street_names(intersection, road_network) -> Array:
	var names: Array = []
	var seen_names: Dictionary = {}

	for connection in intersection.connections:
		var segment = connection.get("segment")
		if segment and segment.name != "" and not seen_names.has(segment.name):
			names.append(segment.name)
			seen_names[segment.name] = true

		# Limit to 2 names (top and bottom of sign)
		if names.size() >= 2:
			break

	return names




## Create a sign post with street name labels
static func _create_sign_post(street_names: Array, position: Vector3) -> Node3D:
	var post = Node3D.new()
	post.name = "SignPost"
	post.position = position

	# Create pole mesh
	var pole_mesh = _create_pole_mesh()
	var pole_instance = MeshInstance3D.new()
	pole_instance.mesh = pole_mesh
	post.add_child(pole_instance)

	# Create sign boards with text
	for i in range(mini(street_names.size(), 2)):
		var sign_board = _create_sign_board(street_names[i], i)
		sign_board.position = Vector3(0, POLE_HEIGHT - 0.1 - i * (SIGN_HEIGHT + 0.05), 0)
		sign_board.rotation.y = PI / 4.0 if i == 0 else -PI / 4.0  # Angle signs
		post.add_child(sign_board)

	return post


## Create the pole mesh
static func _create_pole_mesh() -> ArrayMesh:
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

		# Quad for pole side
		st.add_vertex(Vector3(x1, 0, z1))
		st.add_vertex(Vector3(x2, 0, z2))
		st.add_vertex(Vector3(x2, POLE_HEIGHT, z2))

		st.add_vertex(Vector3(x1, 0, z1))
		st.add_vertex(Vector3(x2, POLE_HEIGHT, z2))
		st.add_vertex(Vector3(x1, POLE_HEIGHT, z1))

	st.generate_normals()
	var mesh = st.commit()

	# Dark metal material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.2, 0.2)
	material.roughness = 0.7
	material.metallic = 0.3
	mesh.surface_set_material(0, material)

	return mesh


## Abbreviate street name to fit on sign
static func _abbreviate_street_name(name: String) -> String:
	var abbreviated = name
	# Common abbreviations
	abbreviated = abbreviated.replace(" Street", " St")
	abbreviated = abbreviated.replace(" Avenue", " Ave")
	abbreviated = abbreviated.replace(" Boulevard", " Blvd")
	abbreviated = abbreviated.replace(" Drive", " Dr")
	abbreviated = abbreviated.replace(" Road", " Rd")
	abbreviated = abbreviated.replace(" Lane", " Ln")
	abbreviated = abbreviated.replace(" Court", " Ct")
	abbreviated = abbreviated.replace(" Place", " Pl")
	abbreviated = abbreviated.replace(" Circle", " Cir")
	abbreviated = abbreviated.replace(" Highway", " Hwy")
	abbreviated = abbreviated.replace(" Parkway", " Pkwy")
	abbreviated = abbreviated.replace(" North", " N")
	abbreviated = abbreviated.replace(" South", " S")
	abbreviated = abbreviated.replace(" East", " E")
	abbreviated = abbreviated.replace(" West", " W")
	abbreviated = abbreviated.replace(" Northeast", " NE")
	abbreviated = abbreviated.replace(" Northwest", " NW")
	abbreviated = abbreviated.replace(" Southeast", " SE")
	abbreviated = abbreviated.replace(" Southwest", " SW")

	# Truncate if still too long
	if abbreviated.length() > 14:
		abbreviated = abbreviated.substr(0, 12) + ".."

	return abbreviated


## Create a sign board with street name
static func _create_sign_board(street_name: String, index: int) -> Node3D:
	var board = Node3D.new()
	var short_name = _abbreviate_street_name(street_name)
	board.name = "SignBoard_" + short_name.substr(0, 10)

	# Create sign backing (green rectangle)
	var backing_mesh = _create_sign_backing()
	var backing_instance = MeshInstance3D.new()
	backing_instance.mesh = backing_mesh
	board.add_child(backing_instance)

	# Create 3D text label - smaller to fit
	var label = Label3D.new()
	label.text = short_name.to_upper()
	label.font_size = 36  # Smaller font
	label.outline_size = 4
	label.modulate = Color(1, 1, 1)  # White text
	label.outline_modulate = Color(0, 0.3, 0, 1)  # Dark green outline
	label.position = Vector3(0, 0, SIGN_DEPTH / 2.0 + 0.01)
	label.pixel_size = 0.002  # Smaller scale to fit sign
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	board.add_child(label)

	return board


## Create sign backing mesh (green rectangle)
static func _create_sign_backing() -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var hw = SIGN_WIDTH / 2.0
	var hh = SIGN_HEIGHT / 2.0
	var hd = SIGN_DEPTH / 2.0

	# Front face
	st.set_normal(Vector3(0, 0, 1))
	st.add_vertex(Vector3(-hw, -hh, hd))
	st.add_vertex(Vector3(hw, -hh, hd))
	st.add_vertex(Vector3(hw, hh, hd))

	st.set_normal(Vector3(0, 0, 1))
	st.add_vertex(Vector3(-hw, -hh, hd))
	st.add_vertex(Vector3(hw, hh, hd))
	st.add_vertex(Vector3(-hw, hh, hd))

	# Back face
	st.set_normal(Vector3(0, 0, -1))
	st.add_vertex(Vector3(hw, -hh, -hd))
	st.add_vertex(Vector3(-hw, -hh, -hd))
	st.add_vertex(Vector3(-hw, hh, -hd))

	st.set_normal(Vector3(0, 0, -1))
	st.add_vertex(Vector3(hw, -hh, -hd))
	st.add_vertex(Vector3(-hw, hh, -hd))
	st.add_vertex(Vector3(hw, hh, -hd))

	var mesh = st.commit()

	# Green sign material (standard US street sign)
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.0, 0.4, 0.2)  # Green
	material.roughness = 0.6
	mesh.surface_set_material(0, material)

	return mesh
