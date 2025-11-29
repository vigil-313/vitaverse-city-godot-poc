extends RefCounted
class_name UtilityPoleGenerator

## Utility Pole Generator
## Creates wooden utility poles with crossarms along residential streets.
## Uses FurnitureBase for common utilities.

const FurnitureBase = preload("res://scripts/generators/street_furniture/furniture_base.gd")
const StreetFurniturePlacer = FurnitureBase.StreetFurniturePlacer

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


## Create tapered wooden pole using FurnitureBase
static func _create_pole_mesh() -> MeshInstance3D:
	return FurnitureBase.create_tapered_pole_instance(
		POLE_BASE_RADIUS, POLE_TOP_RADIUS, POLE_HEIGHT, "wood"
	)


## Create horizontal crossarm using FurnitureBase
static func _create_crossarm_mesh() -> MeshInstance3D:
	var mesh = FurnitureBase.create_box_mesh(
		CROSSARM_WIDTH, CROSSARM_HEIGHT, CROSSARM_DEPTH,
		FurnitureBase.create_wood_material()
	)
	return FurnitureBase.mesh_to_instance(mesh)


## Create white ceramic insulator using FurnitureBase
static func _create_insulator_mesh() -> MeshInstance3D:
	var mesh = FurnitureBase.create_cylinder_mesh(
		INSULATOR_RADIUS, INSULATOR_HEIGHT, 6,
		FurnitureBase.create_ceramic_material()
	)
	return FurnitureBase.mesh_to_instance(mesh)
