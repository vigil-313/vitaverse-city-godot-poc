extends RefCounted
class_name FurnitureBase

## Street Furniture Base Class
##
## Provides common utilities for all street furniture generators:
## - Material creation (metal, wood, ceramic)
## - Mesh generation helpers (cylinders, quads, boxes)
## - Placement validation
## - Container node creation
##
## Usage: Subclasses should use static methods for shared functionality.

const TerrainPathSmoother = preload("res://scripts/terrain/terrain_path_smoother.gd")
const StreetFurniturePlacer = preload("res://scripts/generators/street_furniture/street_furniture_placer.gd")

# ========================================================================
# CONTAINER CREATION
# ========================================================================

## Create the standard chunk container node
static func create_chunk_container(prefix: String, chunk_key: Vector2i) -> Node3D:
	var node = Node3D.new()
	node.name = "%s_%d_%d" % [prefix, chunk_key.x, chunk_key.y]
	return node

## Add container to parent if provided and return it
static func finalize_container(container: Node3D, parent: Node) -> Node3D:
	if parent:
		parent.add_child(container)
	return container

# ========================================================================
# PLACEMENT VALIDATION
# ========================================================================

## Check if a position is valid (far enough from existing positions)
static func is_valid_position(position: Vector3, placed: Array, min_distance: float) -> bool:
	for existing in placed:
		if position.distance_to(existing) < min_distance:
			return false
	return true

## Get terrain elevation at a 2D position
static func get_elevation(pos_2d: Vector2, heightmap) -> float:
	if heightmap:
		return heightmap.get_elevation(pos_2d.x, -pos_2d.y)
	return 0.0

## Get smoothed terrain elevation (better for signs near roads)
static func get_smoothed_elevation(pos_2d: Vector2, heightmap, radius: float = 5.0) -> float:
	if heightmap:
		return TerrainPathSmoother.get_smoothed_elevation(pos_2d, heightmap, radius)
	return 0.0

## Convert 2D position to 3D with elevation
static func pos_2d_to_3d(pos_2d: Vector2, heightmap, smoothed: bool = false) -> Vector3:
	var elevation: float
	if smoothed:
		elevation = get_smoothed_elevation(pos_2d, heightmap)
	else:
		elevation = get_elevation(pos_2d, heightmap)
	return Vector3(pos_2d.x, elevation, -pos_2d.y)

# ========================================================================
# MATERIAL BUILDERS
# ========================================================================

## Create dark metal material (for poles, traffic signals)
static func create_metal_material(color: Color = Color(0.2, 0.2, 0.2)) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.5
	material.roughness = 0.6
	return material

## Create gray galvanized steel material
static func create_galvanized_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.4, 0.4, 0.4)
	material.metallic = 0.3
	material.roughness = 0.7
	return material

## Create dark powder-coated metal (for traffic signals)
static func create_powder_coat_material(color: Color = Color(0.15, 0.15, 0.15)) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.6
	material.roughness = 0.4
	return material

## Create wood material (for utility poles)
static func create_wood_material(color: Color = Color(0.35, 0.22, 0.12)) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.0
	material.roughness = 0.9
	return material

## Create ceramic/porcelain material (for insulators)
static func create_ceramic_material(color: Color = Color(0.9, 0.9, 0.85)) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.0
	material.roughness = 0.4
	return material

## Create sign backing material
static func create_sign_material(color: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.0
	material.roughness = 0.5
	return material

# ========================================================================
# MESH BUILDERS - CYLINDERS
# ========================================================================

## Create a simple cylinder mesh (uniform radius)
static func create_cylinder_mesh(
	radius: float,
	height: float,
	segments: int = 8,
	material: StandardMaterial3D = null
) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(segments):
		var angle1 = TAU * i / segments
		var angle2 = TAU * (i + 1) / segments

		var x1 = cos(angle1) * radius
		var z1 = sin(angle1) * radius
		var x2 = cos(angle2) * radius
		var z2 = sin(angle2) * radius

		# Side quad
		st.add_vertex(Vector3(x1, 0, z1))
		st.add_vertex(Vector3(x2, 0, z2))
		st.add_vertex(Vector3(x2, height, z2))

		st.add_vertex(Vector3(x1, 0, z1))
		st.add_vertex(Vector3(x2, height, z2))
		st.add_vertex(Vector3(x1, height, z1))

	st.generate_normals()
	var mesh = st.commit()

	if material:
		mesh.surface_set_material(0, material)

	return mesh

## Create a tapered cylinder (pole that narrows toward top)
static func create_tapered_cylinder_mesh(
	base_radius: float,
	top_radius: float,
	height: float,
	segments: int = 8,
	height_steps: int = 4,
	material: StandardMaterial3D = null
) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for h in range(height_steps):
		var y0 = height * h / height_steps
		var y1 = height * (h + 1) / height_steps

		var t0 = float(h) / height_steps
		var t1 = float(h + 1) / height_steps

		var r0 = lerpf(base_radius, top_radius, t0)
		var r1 = lerpf(base_radius, top_radius, t1)

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

	if material:
		mesh.surface_set_material(0, material)

	return mesh

# ========================================================================
# MESH BUILDERS - BOXES/QUADS
# ========================================================================

## Add a quad to a SurfaceTool (counter-clockwise winding)
static func add_quad(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3) -> void:
	st.add_vertex(v0)
	st.add_vertex(v1)
	st.add_vertex(v2)

	st.add_vertex(v0)
	st.add_vertex(v2)
	st.add_vertex(v3)

## Create a simple box mesh
static func create_box_mesh(
	width: float,
	height: float,
	depth: float,
	material: StandardMaterial3D = null
) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var hw = width / 2.0
	var hh = height / 2.0
	var hd = depth / 2.0

	var verts = [
		Vector3(-hw, -hh, -hd), Vector3(hw, -hh, -hd),
		Vector3(hw, hh, -hd), Vector3(-hw, hh, -hd),
		Vector3(-hw, -hh, hd), Vector3(hw, -hh, hd),
		Vector3(hw, hh, hd), Vector3(-hw, hh, hd)
	]

	# All 6 faces
	add_quad(st, verts[4], verts[5], verts[6], verts[7])  # Front (+Z)
	add_quad(st, verts[1], verts[0], verts[3], verts[2])  # Back (-Z)
	add_quad(st, verts[3], verts[7], verts[6], verts[2])  # Top (+Y)
	add_quad(st, verts[0], verts[1], verts[5], verts[4])  # Bottom (-Y)
	add_quad(st, verts[0], verts[4], verts[7], verts[3])  # Left (-X)
	add_quad(st, verts[5], verts[1], verts[2], verts[6])  # Right (+X)

	st.generate_normals()
	var mesh = st.commit()

	if material:
		mesh.surface_set_material(0, material)

	return mesh

## Create a flat sign panel (front and back faces only)
static func create_sign_panel_mesh(
	width: float,
	height: float,
	material: StandardMaterial3D = null
) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var hw = width / 2.0
	var hh = height / 2.0
	var depth = 0.02  # Thin panel

	# Front face (+Z)
	st.set_normal(Vector3(0, 0, 1))
	st.add_vertex(Vector3(-hw, -hh, depth))
	st.add_vertex(Vector3(hw, -hh, depth))
	st.add_vertex(Vector3(hw, hh, depth))

	st.add_vertex(Vector3(-hw, -hh, depth))
	st.add_vertex(Vector3(hw, hh, depth))
	st.add_vertex(Vector3(-hw, hh, depth))

	# Back face (-Z)
	st.set_normal(Vector3(0, 0, -1))
	st.add_vertex(Vector3(hw, -hh, -depth))
	st.add_vertex(Vector3(-hw, -hh, -depth))
	st.add_vertex(Vector3(-hw, hh, -depth))

	st.add_vertex(Vector3(hw, -hh, -depth))
	st.add_vertex(Vector3(-hw, hh, -depth))
	st.add_vertex(Vector3(hw, hh, -depth))

	var mesh = st.commit()

	if material:
		mesh.surface_set_material(0, material)

	return mesh

# ========================================================================
# MESH INSTANCE HELPERS
# ========================================================================

## Create a MeshInstance3D with the given mesh
static func mesh_to_instance(mesh: ArrayMesh) -> MeshInstance3D:
	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	return instance

## Create a pole MeshInstance3D (common operation)
static func create_pole_instance(
	radius: float,
	height: float,
	material_type: String = "metal"
) -> MeshInstance3D:
	var material: StandardMaterial3D
	match material_type:
		"wood":
			material = create_wood_material()
		"galvanized":
			material = create_galvanized_material()
		"powder_coat":
			material = create_powder_coat_material()
		_:
			material = create_metal_material()

	var mesh = create_cylinder_mesh(radius, height, 6, material)
	return mesh_to_instance(mesh)

## Create a tapered pole MeshInstance3D
static func create_tapered_pole_instance(
	base_radius: float,
	top_radius: float,
	height: float,
	material_type: String = "wood"
) -> MeshInstance3D:
	var material: StandardMaterial3D
	match material_type:
		"wood":
			material = create_wood_material()
		"metal":
			material = create_metal_material()
		"powder_coat":
			material = create_powder_coat_material()
		_:
			material = create_metal_material()

	var mesh = create_tapered_cylinder_mesh(base_radius, top_radius, height, 8, 4, material)
	return mesh_to_instance(mesh)

# ========================================================================
# LABEL HELPERS
# ========================================================================

## Create a 3D text label for signs
static func create_sign_label(
	text: String,
	font_size: int = 48,
	color: Color = Color.WHITE,
	pixel_size: float = 0.002
) -> Label3D:
	var label = Label3D.new()
	label.text = text.to_upper()
	label.font_size = font_size
	label.modulate = color
	label.pixel_size = pixel_size
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.no_depth_test = false
	return label

# ========================================================================
# SIGN COLOR CONSTANTS
# ========================================================================

## Standard US sign colors
const COLOR_STOP_RED = Color(0.8, 0.0, 0.0)
const COLOR_HIGHWAY_GREEN = Color(0.0, 0.35, 0.15)
const COLOR_STREET_GREEN = Color(0.0, 0.4, 0.2)
const COLOR_SPEED_WHITE = Color(1.0, 1.0, 1.0)
const COLOR_WARNING_YELLOW = Color(1.0, 0.85, 0.0)
const COLOR_SAFETY_YELLOW = Color(0.85, 0.65, 0.0)
