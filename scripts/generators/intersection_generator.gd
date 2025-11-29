extends RefCounted
class_name IntersectionGenerator

## Intersection Geometry Generator
## Creates mesh geometry for road intersections and segments using the road network graph.
## Replaces the old per-road mesh generation with unified intersection-aware geometry.

const TerrainPathSmoother = preload("res://scripts/terrain/terrain_path_smoother.gd")

## Road surface properties
const ROAD_BASE_OFFSET: float = 0.05  # Slight elevation above terrain
const CURB_HEIGHT: float = 0.15  # 15cm curb
const CURB_WIDTH: float = 0.25  # 25cm curb width


## Generate mesh for a single intersection
## Returns a MeshInstance3D with the intersection polygon
static func create_intersection_mesh(intersection, heightmap, material: Material = null) -> MeshInstance3D:
	if intersection.polygon.size() < 3:
		return null

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Intersection_%d" % intersection.node_id

	# Get elevation at intersection center
	var elevation = 0.0
	if heightmap:
		elevation = TerrainPathSmoother.get_smoothed_elevation(
			intersection.position, heightmap, intersection.get_max_road_width() / 2.0
		)

	# Position mesh at intersection center
	mesh_instance.position = Vector3(
		intersection.position.x,
		elevation + ROAD_BASE_OFFSET,
		-intersection.position.y
	)

	# Build mesh from polygon
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Convert polygon to local coordinates (relative to mesh position)
	var local_polygon: Array = []
	for point in intersection.polygon:
		var local = point - intersection.position
		local_polygon.append(Vector3(local.x, 0, -local.y))

	# Triangulate the polygon using fan triangulation from center
	var center = Vector3.ZERO
	for point in local_polygon:
		center += point
	center /= local_polygon.size()

	for i in range(local_polygon.size()):
		var p1 = local_polygon[i]
		var p2 = local_polygon[(i + 1) % local_polygon.size()]

		# Triangle: center, p1, p2
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.5, 0.5))
		st.add_vertex(center)

		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.5 + p1.x * 0.1, 0.5 + p1.z * 0.1))
		st.add_vertex(p1)

		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.5 + p2.x * 0.1, 0.5 + p2.z * 0.1))
		st.add_vertex(p2)

	st.generate_tangents()
	mesh_instance.mesh = st.commit()

	# Apply material
	if material:
		mesh_instance.material_override = material
	else:
		mesh_instance.material_override = _create_default_road_material()

	return mesh_instance


## Generate mesh for a road segment between intersections
## Returns a MeshInstance3D with the road ribbon
static func create_segment_mesh(segment, heightmap, material: Material = null) -> MeshInstance3D:
	if segment.path.size() < 2:
		return null

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Segment_%s" % segment.segment_id

	# Get smoothed 3D path
	var path_3d = TerrainPathSmoother.smooth_path(segment.path, heightmap, segment.calculated_width)
	if path_3d.size() < 2:
		return null

	# Calculate center for local coordinates
	var center_2d = Vector2.ZERO
	for point in segment.path:
		center_2d += point
	center_2d /= segment.path.size()

	var center_elevation = 0.0
	if heightmap:
		center_elevation = TerrainPathSmoother.get_smoothed_elevation(center_2d, heightmap, segment.calculated_width / 2.0)

	mesh_instance.position = Vector3(center_2d.x, center_elevation, -center_2d.y)

	# Build road mesh
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_width = segment.calculated_width / 2.0
	var accumulated_length = 0.0

	# Build ribbon mesh along path
	for i in range(path_3d.size()):
		var pos = path_3d[i]

		# Convert to local coordinates
		var local_pos = pos - Vector3(center_2d.x, center_elevation, -center_2d.y)

		# Calculate direction and perpendicular
		var direction: Vector3
		if i == 0:
			direction = (path_3d[1] - path_3d[0]).normalized()
		elif i == path_3d.size() - 1:
			direction = (path_3d[i] - path_3d[i - 1]).normalized()
		else:
			var dir_prev = (path_3d[i] - path_3d[i - 1]).normalized()
			var dir_next = (path_3d[i + 1] - path_3d[i]).normalized()
			direction = (dir_prev + dir_next).normalized()

		# Perpendicular in XZ plane
		var perpendicular = Vector3(-direction.z, 0, direction.x).normalized()

		# Left and right edge vertices
		var left = local_pos + perpendicular * half_width
		var right = local_pos - perpendicular * half_width

		# Keep Y at 0 relative to mesh position (terrain following handled by smoothing)
		left.y = local_pos.y
		right.y = local_pos.y

		# UV coordinates
		var u = accumulated_length / segment.calculated_width  # Repeat every road-width
		var v_left = 0.0
		var v_right = 1.0

		# Add vertices (will connect with previous pair to form quads)
		if i > 0:
			# Get previous vertices (stored as indices would be complex, recalculate)
			var prev_pos = path_3d[i - 1]
			var prev_local = prev_pos - Vector3(center_2d.x, center_elevation, -center_2d.y)

			var prev_direction: Vector3
			if i == 1:
				prev_direction = (path_3d[1] - path_3d[0]).normalized()
			else:
				var pd_prev = (path_3d[i - 1] - path_3d[i - 2]).normalized()
				var pd_next = (path_3d[i] - path_3d[i - 1]).normalized()
				prev_direction = (pd_prev + pd_next).normalized()

			var prev_perp = Vector3(-prev_direction.z, 0, prev_direction.x).normalized()
			var prev_left = prev_local + prev_perp * half_width
			var prev_right = prev_local - prev_perp * half_width
			prev_left.y = prev_local.y
			prev_right.y = prev_local.y

			var prev_u = (accumulated_length - prev_pos.distance_to(pos)) / segment.calculated_width

			# Triangle 1: prev_left, prev_right, right
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(prev_u, v_left))
			st.add_vertex(prev_left)

			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(prev_u, v_right))
			st.add_vertex(prev_right)

			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(u, v_right))
			st.add_vertex(right)

			# Triangle 2: prev_left, right, left
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(prev_u, v_left))
			st.add_vertex(prev_left)

			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(u, v_right))
			st.add_vertex(right)

			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(u, v_left))
			st.add_vertex(left)

		# Update accumulated length
		if i < path_3d.size() - 1:
			accumulated_length += path_3d[i].distance_to(path_3d[i + 1])

	st.generate_tangents()
	mesh_instance.mesh = st.commit()

	# Apply material
	if material:
		mesh_instance.material_override = material
	else:
		mesh_instance.material_override = _create_default_road_material()

	return mesh_instance


## Generate curb geometry for a segment
static func create_segment_curbs(segment, heightmap, material: Material = null) -> MeshInstance3D:
	if segment.path.size() < 2:
		return null

	# Skip curbs for pedestrian paths
	if segment.is_pedestrian():
		return null

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Curbs_%s" % segment.segment_id

	var path_3d = TerrainPathSmoother.smooth_path(segment.path, heightmap, segment.calculated_width)
	if path_3d.size() < 2:
		return null

	# Calculate center
	var center_2d = Vector2.ZERO
	for point in segment.path:
		center_2d += point
	center_2d /= segment.path.size()

	var center_elevation = 0.0
	if heightmap:
		center_elevation = TerrainPathSmoother.get_smoothed_elevation(center_2d, heightmap, segment.calculated_width / 2.0)

	mesh_instance.position = Vector3(center_2d.x, center_elevation, -center_2d.y)

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_width = segment.calculated_width / 2.0

	# Build curbs on both sides
	for i in range(path_3d.size() - 1):
		var pos = path_3d[i]
		var next_pos = path_3d[i + 1]

		var local_pos = pos - Vector3(center_2d.x, center_elevation, -center_2d.y)
		var local_next = next_pos - Vector3(center_2d.x, center_elevation, -center_2d.y)

		var direction = (next_pos - pos).normalized()
		var perpendicular = Vector3(-direction.z, 0, direction.x).normalized()

		# Left curb (outer edge of road)
		var left_inner = local_pos + perpendicular * half_width
		var left_outer = local_pos + perpendicular * (half_width + CURB_WIDTH)
		var left_inner_next = local_next + perpendicular * half_width
		var left_outer_next = local_next + perpendicular * (half_width + CURB_WIDTH)

		# Adjust Y for curb height
		left_inner.y = local_pos.y
		left_outer.y = local_pos.y + CURB_HEIGHT
		left_inner_next.y = local_next.y
		left_outer_next.y = local_next.y + CURB_HEIGHT

		# Left curb top face
		_add_quad(st, left_inner, left_outer, left_outer_next, left_inner_next, Vector3.UP)

		# Left curb inner face (facing road)
		var inner_top = left_inner + Vector3(0, CURB_HEIGHT, 0)
		var inner_top_next = left_inner_next + Vector3(0, CURB_HEIGHT, 0)
		_add_quad(st, left_inner, inner_top, inner_top_next, left_inner_next, -perpendicular)

		# Right curb (mirror)
		var right_inner = local_pos - perpendicular * half_width
		var right_outer = local_pos - perpendicular * (half_width + CURB_WIDTH)
		var right_inner_next = local_next - perpendicular * half_width
		var right_outer_next = local_next - perpendicular * (half_width + CURB_WIDTH)

		right_inner.y = local_pos.y
		right_outer.y = local_pos.y + CURB_HEIGHT
		right_inner_next.y = local_next.y
		right_outer_next.y = local_next.y + CURB_HEIGHT

		# Right curb top face
		_add_quad(st, right_outer, right_inner, right_inner_next, right_outer_next, Vector3.UP)

		# Right curb inner face
		var right_inner_top = right_inner + Vector3(0, CURB_HEIGHT, 0)
		var right_inner_top_next = right_inner_next + Vector3(0, CURB_HEIGHT, 0)
		_add_quad(st, right_inner_top, right_inner, right_inner_next, right_inner_top_next, perpendicular)

	st.generate_tangents()
	mesh_instance.mesh = st.commit()

	if material:
		mesh_instance.material_override = material
	else:
		mesh_instance.material_override = _create_curb_material()

	return mesh_instance


## Helper to add a quad (two triangles)
static func _add_quad(st: SurfaceTool, p1: Vector3, p2: Vector3, p3: Vector3, p4: Vector3, normal: Vector3) -> void:
	# Triangle 1
	st.set_normal(normal)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(p1)

	st.set_normal(normal)
	st.set_uv(Vector2(1, 0))
	st.add_vertex(p2)

	st.set_normal(normal)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(p3)

	# Triangle 2
	st.set_normal(normal)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(p1)

	st.set_normal(normal)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(p3)

	st.set_normal(normal)
	st.set_uv(Vector2(0, 1))
	st.add_vertex(p4)


## Create default road material
static func _create_default_road_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.25, 0.27)  # Dark asphalt gray
	material.roughness = 0.9
	material.metallic = 0.0
	return material


## Create curb material
static func _create_curb_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.6, 0.6, 0.58)  # Concrete gray
	material.roughness = 0.85
	material.metallic = 0.0
	return material


## Create sidewalk material
static func _create_sidewalk_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.68, 0.65)  # Light concrete
	material.roughness = 0.8
	material.metallic = 0.0
	return material
