extends RefCounted
class_name TreeGenerator

## Tree Generator
## Creates simple geometric trees (cone + cylinder)
## Supports multiple tree types with varying shapes and colors

# ========================================================================
# TREE TYPE DEFINITIONS
# ========================================================================

## Tree type configurations
const TREE_TYPES = {
	"deciduous": {
		"trunk_height": 3.0,
		"trunk_radius": 0.3,
		"canopy_height": 5.0,
		"canopy_radius": 2.5,
		"trunk_color": Color(0.4, 0.3, 0.2),
		"canopy_colors": [
			Color(0.2, 0.5, 0.15),   # Dark green
			Color(0.3, 0.55, 0.2),   # Medium green
			Color(0.25, 0.6, 0.18),  # Light green
		],
	},
	"conifer": {
		"trunk_height": 2.0,
		"trunk_radius": 0.25,
		"canopy_height": 8.0,
		"canopy_radius": 2.0,
		"trunk_color": Color(0.35, 0.25, 0.15),
		"canopy_colors": [
			Color(0.1, 0.35, 0.15),  # Dark pine
			Color(0.15, 0.4, 0.18),  # Medium pine
			Color(0.12, 0.38, 0.12), # Blue-green pine
		],
	},
	"small_bush": {
		"trunk_height": 0.3,
		"trunk_radius": 0.1,
		"canopy_height": 1.5,
		"canopy_radius": 1.0,
		"trunk_color": Color(0.35, 0.25, 0.15),
		"canopy_colors": [
			Color(0.25, 0.5, 0.2),
			Color(0.3, 0.45, 0.15),
		],
	},
}

# ========================================================================
# TREE GENERATION
# ========================================================================

## Create a single tree at the given position
static func generate(
	position: Vector3,
	tree_type: String = "deciduous",
	seed_value: int = 0,
	parent: Node = null
) -> Node3D:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value

	# Get tree configuration
	var config = TREE_TYPES.get(tree_type, TREE_TYPES["deciduous"])

	# Apply some randomness to size
	var scale_factor = rng.randf_range(0.7, 1.3)
	var trunk_height = config["trunk_height"] * scale_factor
	var trunk_radius = config["trunk_radius"] * scale_factor
	var canopy_height = config["canopy_height"] * scale_factor
	var canopy_radius = config["canopy_radius"] * scale_factor

	# Pick random canopy color from options
	var canopy_colors = config["canopy_colors"]
	var canopy_color = canopy_colors[rng.randi() % canopy_colors.size()]

	# Create tree node
	var tree_node = Node3D.new()
	tree_node.name = "Tree_" + tree_type
	tree_node.position = position

	# Random rotation for variety
	tree_node.rotation.y = rng.randf() * TAU

	# Create trunk (cylinder)
	var trunk = _create_trunk(trunk_height, trunk_radius, config["trunk_color"])
	tree_node.add_child(trunk)

	# Create canopy (cone for conifers, sphere/cone for deciduous)
	var canopy = _create_canopy(trunk_height, canopy_height, canopy_radius, canopy_color, tree_type)
	tree_node.add_child(canopy)

	if parent:
		parent.add_child(tree_node)

	return tree_node

## Create tree trunk mesh
static func _create_trunk(height: float, radius: float, color: Color) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Trunk"

	var cylinder = CylinderMesh.new()
	cylinder.height = height
	cylinder.top_radius = radius * 0.7  # Taper toward top
	cylinder.bottom_radius = radius
	cylinder.radial_segments = 8  # Low poly
	mesh_instance.mesh = cylinder

	# Position trunk so bottom is at origin
	mesh_instance.position.y = height / 2.0

	# Trunk material
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh_instance.material_override = material

	return mesh_instance

## Create tree canopy mesh
static func _create_canopy(
	trunk_height: float,
	canopy_height: float,
	canopy_radius: float,
	color: Color,
	tree_type: String
) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Canopy"

	var mesh: Mesh

	if tree_type == "conifer":
		# Conifers get a tall narrow cone
		var cone = CylinderMesh.new()
		cone.height = canopy_height
		cone.top_radius = 0.0
		cone.bottom_radius = canopy_radius
		cone.radial_segments = 8
		mesh = cone
	elif tree_type == "small_bush":
		# Bushes get a sphere
		var sphere = SphereMesh.new()
		sphere.radius = canopy_radius
		sphere.height = canopy_height
		sphere.radial_segments = 8
		sphere.rings = 4
		mesh = sphere
	else:
		# Deciduous trees get a rounded cone (egg shape approximation)
		var cone = CylinderMesh.new()
		cone.height = canopy_height
		cone.top_radius = canopy_radius * 0.3
		cone.bottom_radius = canopy_radius
		cone.radial_segments = 8
		mesh = cone

	mesh_instance.mesh = mesh

	# Position canopy on top of trunk
	if tree_type == "conifer":
		mesh_instance.position.y = trunk_height + canopy_height / 2.0 - 0.5  # Overlap slightly
	elif tree_type == "small_bush":
		mesh_instance.position.y = trunk_height + canopy_height / 2.0
	else:
		mesh_instance.position.y = trunk_height + canopy_height / 2.0 - 0.3

	# Canopy material
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	mesh_instance.material_override = material

	return mesh_instance

# ========================================================================
# BATCH GENERATION
# ========================================================================

## Generate multiple trees in a region (for parks/forests)
static func generate_trees_in_region(
	polygon: Array,
	density: float,
	tree_type: String,
	parent: Node,
	heightmap = null,
	seed_value: int = 0
) -> Array[Node3D]:
	var trees: Array[Node3D] = []
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value

	# Calculate bounding box
	var min_point = Vector2(INF, INF)
	var max_point = Vector2(-INF, -INF)

	for point in polygon:
		min_point.x = min(min_point.x, point.x)
		min_point.y = min(min_point.y, point.y)
		max_point.x = max(max_point.x, point.x)
		max_point.y = max(max_point.y, point.y)

	# Calculate area and number of trees
	var width = max_point.x - min_point.x
	var height = max_point.y - min_point.y
	var area = width * height
	var num_trees = int(area * density / 100.0)  # density per 100 sqm

	# Cap tree count for performance
	num_trees = min(num_trees, 50)

	# Generate trees at random positions within polygon
	var attempts = 0
	var max_attempts = num_trees * 3

	while trees.size() < num_trees and attempts < max_attempts:
		attempts += 1

		# Random point in bounding box
		var x = rng.randf_range(min_point.x, max_point.x)
		var y = rng.randf_range(min_point.y, max_point.y)
		var point_2d = Vector2(x, y)

		# Check if point is inside polygon
		if not _point_in_polygon(point_2d, polygon):
			continue

		# Check minimum spacing (trees shouldn't be too close)
		var too_close = false
		for existing_tree in trees:
			var existing_pos_2d = Vector2(existing_tree.position.x, -existing_tree.position.z)
			if point_2d.distance_to(existing_pos_2d) < 3.0:  # 3m minimum spacing
				too_close = true
				break

		if too_close:
			continue

		# Get terrain elevation
		var elevation = 0.0
		if heightmap:
			elevation = heightmap.get_elevation(x, -y)

		var position = Vector3(x, elevation, -y)
		var tree_seed = rng.randi()

		var tree = generate(position, tree_type, tree_seed, parent)
		trees.append(tree)

	return trees

## Check if point is inside polygon (ray casting algorithm)
static func _point_in_polygon(point: Vector2, polygon: Array) -> bool:
	var n = polygon.size()
	var inside = false

	var j = n - 1
	for i in range(n):
		var pi = polygon[i]
		var pj = polygon[j]

		if ((pi.y > point.y) != (pj.y > point.y)) and \
		   (point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x):
			inside = not inside
		j = i

	return inside

# ========================================================================
# STREET TREES
# ========================================================================

## Generate trees along a road/street
static func generate_street_trees(
	road_path: Array,
	spacing: float,
	offset: float,
	parent: Node,
	heightmap = null,
	seed_value: int = 0
) -> Array[Node3D]:
	var trees: Array[Node3D] = []
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value

	if road_path.size() < 2:
		return trees

	# Calculate total road length
	var total_length = 0.0
	for i in range(road_path.size() - 1):
		total_length += road_path[i].distance_to(road_path[i + 1])

	# Place trees at regular intervals
	var num_trees = int(total_length / spacing)
	var accumulated_length = 0.0
	var segment_idx = 0
	var tree_count = 0

	for tree_idx in range(num_trees):
		var target_dist = (tree_idx + 0.5) * spacing

		# Find the segment containing this distance
		while segment_idx < road_path.size() - 1:
			var seg_length = road_path[segment_idx].distance_to(road_path[segment_idx + 1])
			if accumulated_length + seg_length >= target_dist:
				break
			accumulated_length += seg_length
			segment_idx += 1

		if segment_idx >= road_path.size() - 1:
			break

		# Interpolate position along segment
		var seg_start = road_path[segment_idx]
		var seg_end = road_path[segment_idx + 1]
		var seg_length = seg_start.distance_to(seg_end)
		var t = (target_dist - accumulated_length) / seg_length if seg_length > 0 else 0
		t = clamp(t, 0.0, 1.0)

		var tree_pos_2d = seg_start.lerp(seg_end, t)

		# Offset to side of road
		var road_dir = (seg_end - seg_start).normalized()
		var road_normal = Vector2(-road_dir.y, road_dir.x)

		# Alternate sides
		var side = 1.0 if tree_idx % 2 == 0 else -1.0
		tree_pos_2d += road_normal * (offset * side)

		# Get terrain elevation
		var elevation = 0.0
		if heightmap:
			elevation = heightmap.get_elevation(tree_pos_2d.x, -tree_pos_2d.y)

		var tree_pos = Vector3(tree_pos_2d.x, elevation, -tree_pos_2d.y)
		var tree_seed = seed_value + tree_count

		# Street trees are typically deciduous
		var tree = generate(tree_pos, "deciduous", tree_seed, parent)
		trees.append(tree)
		tree_count += 1

	return trees
