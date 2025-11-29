extends RefCounted
class_name UtilityPoleGenerator

## Utility Pole Generator
## Creates wooden utility poles with crossarms along residential streets.
## Uses StreetFurniturePlacer for proper road edge positioning.

const StreetFurniturePlacer = preload("res://scripts/generators/street_furniture/street_furniture_placer.gd")

## Pole dimensions
const POLE_HEIGHT: float = 8.0
const POLE_BASE_RADIUS: float = 0.15
const POLE_TOP_RADIUS: float = 0.08

## Crossarm dimensions
const CROSSARM_WIDTH: float = 2.0
const CROSSARM_HEIGHT: float = 0.1
const CROSSARM_DEPTH: float = 0.1
const CROSSARM_Y_OFFSET: float = 0.5  # Below top of pole

## Insulator dimensions
const INSULATOR_RADIUS: float = 0.04
const INSULATOR_HEIGHT: float = 0.12

## Placement
const POLE_SPACING: float = 70.0  # Meters between poles
const ROAD_OFFSET: float = 3.5    # Distance from road edge
const MAX_POLES_PER_CHUNK: int = 30

## Road types that get utility poles
const POLE_ROAD_TYPES = ["residential", "tertiary", "unclassified", "secondary"]


## Generate utility poles for a chunk
static func create_chunk_poles(
	road_network,
	chunk_key: Vector2i,
	chunk_size: float,
	heightmap,
	parent: Node = null
) -> Node3D:
	var poles_node = Node3D.new()
	poles_node.name = "UtilityPoles_%d_%d" % [chunk_key.x, chunk_key.y]

	var pole_count = 0
	var placed_positions: Array = []

	var segments = road_network.get_segments_in_chunk(chunk_key, chunk_size)

	for segment in segments:
		if pole_count >= MAX_POLES_PER_CHUNK:
			break

		# Only place on appropriate road types
		if segment.highway_type not in POLE_ROAD_TYPES:
			continue

		# Skip short segments
		if segment.length < POLE_SPACING * 0.5:
			continue

		# Use segment hash to determine which side and if this segment gets poles
		var seg_hash = hash(segment.segment_id)
		if seg_hash % 3 != 0:  # ~33% of eligible segments
			continue

		var side = "right" if (seg_hash % 2 == 0) else "left"

		# Place poles along segment
		var num_poles = int(segment.length / POLE_SPACING)
		for i in range(num_poles):
			if pole_count >= MAX_POLES_PER_CHUNK:
				break

			var t = (i + 0.5) / float(num_poles)  # Distribute evenly

			var placement = StreetFurniturePlacer.get_road_edge_position(
				segment, t, side, heightmap, ROAD_OFFSET
			)

			if placement.is_empty():
				continue

			# Check spacing from existing poles
			if not StreetFurniturePlacer.is_position_valid(placement.position, placed_positions, POLE_SPACING * 0.5):
				continue

			placed_positions.append(placement.position)

			var pole_node = _create_utility_pole(placement.position, placement.direction)
			poles_node.add_child(pole_node)
			pole_count += 1

	if parent:
		parent.add_child(poles_node)

	return poles_node


## Create a single utility pole with crossarm
static func _create_utility_pole(position: Vector3, road_dir: Vector2) -> Node3D:
	var pole_assembly = Node3D.new()
	pole_assembly.name = "UtilityPole"
	pole_assembly.position = position

	# Rotate crossarm perpendicular to road
	pole_assembly.rotation.y = atan2(road_dir.x, -road_dir.y)

	# Create tapered pole
	var pole = _create_pole_mesh()
	pole_assembly.add_child(pole)

	# Create crossarm
	var crossarm = _create_crossarm_mesh()
	crossarm.position.y = POLE_HEIGHT - CROSSARM_Y_OFFSET
	pole_assembly.add_child(crossarm)

	# Create insulators on crossarm
	var insulator_positions = [-0.8, -0.4, 0.0, 0.4, 0.8]
	for x_pos in insulator_positions:
		var insulator = _create_insulator_mesh()
		insulator.position = Vector3(x_pos, POLE_HEIGHT - CROSSARM_Y_OFFSET + CROSSARM_HEIGHT / 2.0, 0)
		pole_assembly.add_child(insulator)

	return pole_assembly


## Create tapered wooden pole
static func _create_pole_mesh() -> MeshInstance3D:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var segments = 8
	var height_steps = 4

	for h in range(height_steps):
		var y0 = POLE_HEIGHT * h / height_steps
		var y1 = POLE_HEIGHT * (h + 1) / height_steps

		var t0 = float(h) / height_steps
		var t1 = float(h + 1) / height_steps

		var r0 = lerp(POLE_BASE_RADIUS, POLE_TOP_RADIUS, t0)
		var r1 = lerp(POLE_BASE_RADIUS, POLE_TOP_RADIUS, t1)

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

			# Quad for this section
			st.add_vertex(Vector3(x1_0, y0, z1_0))
			st.add_vertex(Vector3(x2_0, y0, z2_0))
			st.add_vertex(Vector3(x2_1, y1, z2_1))

			st.add_vertex(Vector3(x1_0, y0, z1_0))
			st.add_vertex(Vector3(x2_1, y1, z2_1))
			st.add_vertex(Vector3(x1_1, y1, z1_1))

	st.generate_normals()
	var mesh = st.commit()

	# Brown wood color
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.22, 0.12)  # Dark brown
	material.roughness = 0.9
	mesh.surface_set_material(0, material)

	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	return instance


## Create horizontal crossarm
static func _create_crossarm_mesh() -> MeshInstance3D:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var hw = CROSSARM_WIDTH / 2.0
	var hh = CROSSARM_HEIGHT / 2.0
	var hd = CROSSARM_DEPTH / 2.0

	var verts = [
		Vector3(-hw, -hh, -hd), Vector3(hw, -hh, -hd),
		Vector3(hw, hh, -hd), Vector3(-hw, hh, -hd),
		Vector3(-hw, -hh, hd), Vector3(hw, -hh, hd),
		Vector3(hw, hh, hd), Vector3(-hw, hh, hd)
	]

	# All faces
	_add_quad(st, verts[4], verts[5], verts[6], verts[7])  # Front
	_add_quad(st, verts[1], verts[0], verts[3], verts[2])  # Back
	_add_quad(st, verts[3], verts[7], verts[6], verts[2])  # Top
	_add_quad(st, verts[0], verts[1], verts[5], verts[4])  # Bottom
	_add_quad(st, verts[0], verts[4], verts[7], verts[3])  # Left
	_add_quad(st, verts[5], verts[1], verts[2], verts[6])  # Right

	st.generate_normals()
	var mesh = st.commit()

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.22, 0.12)  # Same brown
	material.roughness = 0.9
	mesh.surface_set_material(0, material)

	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	return instance


## Create white ceramic insulator
static func _create_insulator_mesh() -> MeshInstance3D:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var segments = 6

	# Simple cylinder for insulator
	for i in range(segments):
		var angle1 = TAU * i / segments
		var angle2 = TAU * (i + 1) / segments

		var x1 = cos(angle1) * INSULATOR_RADIUS
		var z1 = sin(angle1) * INSULATOR_RADIUS
		var x2 = cos(angle2) * INSULATOR_RADIUS
		var z2 = sin(angle2) * INSULATOR_RADIUS

		# Side
		st.add_vertex(Vector3(x1, 0, z1))
		st.add_vertex(Vector3(x2, 0, z2))
		st.add_vertex(Vector3(x2, INSULATOR_HEIGHT, z2))

		st.add_vertex(Vector3(x1, 0, z1))
		st.add_vertex(Vector3(x2, INSULATOR_HEIGHT, z2))
		st.add_vertex(Vector3(x1, INSULATOR_HEIGHT, z1))

		# Top cap
		st.add_vertex(Vector3(0, INSULATOR_HEIGHT, 0))
		st.add_vertex(Vector3(x1, INSULATOR_HEIGHT, z1))
		st.add_vertex(Vector3(x2, INSULATOR_HEIGHT, z2))

	st.generate_normals()
	var mesh = st.commit()

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.9, 0.85)  # Off-white ceramic
	material.roughness = 0.4
	mesh.surface_set_material(0, material)

	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	return instance


## Helper to add a quad
static func _add_quad(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3) -> void:
	st.add_vertex(v0)
	st.add_vertex(v1)
	st.add_vertex(v2)

	st.add_vertex(v0)
	st.add_vertex(v2)
	st.add_vertex(v3)
