## TerrainMesh - Generates terrain mesh chunks
##
## Creates subdivided plane meshes that follow heightmap elevation.
## Each chunk is 500m x 500m matching the city chunk system.
##
## Usage:
##   var terrain = TerrainMesh.create_terrain_chunk(chunk_key, 500.0, heightmap)
##   parent.add_child(terrain)

class_name TerrainMesh
extends RefCounted

## Terrain configuration
const DEFAULT_SUBDIVISION = 32  # 32x32 grid = ~15.6m between vertices for 500m chunk
const TERRAIN_MATERIAL_COLOR = Color(0.42, 0.36, 0.27)  # Earth brown (#6B5C45)
const GRASS_COLOR = Color(0.30, 0.45, 0.22)  # Grass green for parks
const ROCK_COLOR = Color(0.45, 0.42, 0.38)  # Rocky gray for steep slopes

## Create a terrain mesh for a specific chunk
## chunk_key: Vector2i identifying the chunk (e.g., Vector2i(-1, 2))
## chunk_size: Size of chunk in meters (default 500m)
## heightmap: HeightmapLoader instance for elevation queries
## subdivision: Number of grid divisions (higher = more detail)
##
## NOTE: Chunk keys use OSM coordinates where Y is north (positive up on map).
## Godot uses Z for depth where -Z is north. So we negate the Y component
## when converting to Godot world position.
static func create_terrain_chunk(
	chunk_key: Vector2i,
	chunk_size: float,
	heightmap,  # HeightmapLoader
	subdivision: int = DEFAULT_SUBDIVISION
) -> MeshInstance3D:

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Terrain_" + str(chunk_key.x) + "_" + str(chunk_key.y)

	# Calculate chunk world position in OSM coordinates
	# OSM: X is east, Y is north
	var osm_origin_x = float(chunk_key.x) * chunk_size
	var osm_origin_y = float(chunk_key.y) * chunk_size

	# Convert to Godot coordinates for heightmap queries
	# Godot: X is east (same), Z is south (so -Y from OSM)
	var godot_origin_x = osm_origin_x
	var godot_origin_z = -osm_origin_y - chunk_size  # Negate Y and offset by chunk size

	# Create the mesh with OSM coordinates for heightmap queries
	var array_mesh = _create_terrain_mesh(
		osm_origin_x, osm_origin_y,
		chunk_size, subdivision, heightmap
	)

	mesh_instance.mesh = array_mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Position at Godot world coordinates
	mesh_instance.position = Vector3(godot_origin_x, 0, godot_origin_z)

	return mesh_instance

## Create the actual mesh geometry
## osm_origin_x, osm_origin_y: Origin in OSM coordinates (Y is north)
static func _create_terrain_mesh(
	osm_origin_x: float, osm_origin_y: float,
	size: float, subdivision: int,
	heightmap
) -> ArrayMesh:

	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Create material
	var material = _create_terrain_material()
	surface_tool.set_material(material)

	var step = size / float(subdivision)
	var vertex_count_per_side = subdivision + 1

	# Pre-sample all heights and calculate normals
	var heights = []
	heights.resize(vertex_count_per_side * vertex_count_per_side)

	# The mesh will be positioned at (osm_origin_x, 0, -osm_origin_y - size)
	# Vertices go from local (0,0) to (size, size)
	# So world position of vertex (x*step, h, z*step) will be:
	#   (osm_origin_x + x*step, h, -osm_origin_y - size + z*step)

	for z in range(vertex_count_per_side):
		for x in range(vertex_count_per_side):
			# Calculate where this vertex will be in Godot world coordinates
			var world_x = osm_origin_x + float(x) * step
			var world_z = -osm_origin_y - size + float(z) * step

			# Query heightmap at world position
			var height = 0.0
			if heightmap:
				height = heightmap.get_elevation(world_x, world_z)
			heights[z * vertex_count_per_side + x] = height

	# Generate triangles with proper normals
	for z in range(subdivision):
		for x in range(subdivision):
			# Get indices for this quad's corners
			var i00 = z * vertex_count_per_side + x
			var i10 = z * vertex_count_per_side + (x + 1)
			var i01 = (z + 1) * vertex_count_per_side + x
			var i11 = (z + 1) * vertex_count_per_side + (x + 1)

			# Get positions (relative to chunk origin)
			var p00 = Vector3(float(x) * step, heights[i00], float(z) * step)
			var p10 = Vector3(float(x + 1) * step, heights[i10], float(z) * step)
			var p01 = Vector3(float(x) * step, heights[i01], float(z + 1) * step)
			var p11 = Vector3(float(x + 1) * step, heights[i11], float(z + 1) * step)

			# Calculate normals for each vertex (average of adjacent faces)
			var n00 = _calculate_vertex_normal(heights, x, z, vertex_count_per_side, step)
			var n10 = _calculate_vertex_normal(heights, x + 1, z, vertex_count_per_side, step)
			var n01 = _calculate_vertex_normal(heights, x, z + 1, vertex_count_per_side, step)
			var n11 = _calculate_vertex_normal(heights, x + 1, z + 1, vertex_count_per_side, step)

			# Calculate UVs
			var uv00 = Vector2(float(x) / float(subdivision), float(z) / float(subdivision))
			var uv10 = Vector2(float(x + 1) / float(subdivision), float(z) / float(subdivision))
			var uv01 = Vector2(float(x) / float(subdivision), float(z + 1) / float(subdivision))
			var uv11 = Vector2(float(x + 1) / float(subdivision), float(z + 1) / float(subdivision))

			# Calculate vertex colors based on slope and height
			var c00 = _get_terrain_color(heights[i00], n00)
			var c10 = _get_terrain_color(heights[i10], n10)
			var c01 = _get_terrain_color(heights[i01], n01)
			var c11 = _get_terrain_color(heights[i11], n11)

			# Triangle 1: 00, 10, 01
			surface_tool.set_normal(n00)
			surface_tool.set_uv(uv00)
			surface_tool.set_color(c00)
			surface_tool.add_vertex(p00)

			surface_tool.set_normal(n10)
			surface_tool.set_uv(uv10)
			surface_tool.set_color(c10)
			surface_tool.add_vertex(p10)

			surface_tool.set_normal(n01)
			surface_tool.set_uv(uv01)
			surface_tool.set_color(c01)
			surface_tool.add_vertex(p01)

			# Triangle 2: 10, 11, 01
			surface_tool.set_normal(n10)
			surface_tool.set_uv(uv10)
			surface_tool.set_color(c10)
			surface_tool.add_vertex(p10)

			surface_tool.set_normal(n11)
			surface_tool.set_uv(uv11)
			surface_tool.set_color(c11)
			surface_tool.add_vertex(p11)

			surface_tool.set_normal(n01)
			surface_tool.set_uv(uv01)
			surface_tool.set_color(c01)
			surface_tool.add_vertex(p01)

	return surface_tool.commit()

## Calculate vertex normal from surrounding heights
static func _calculate_vertex_normal(
	heights: Array, x: int, z: int,
	size: int, step: float
) -> Vector3:

	# Get heights of neighbors (clamped to bounds)
	var h_left = heights[z * size + maxi(x - 1, 0)]
	var h_right = heights[z * size + mini(x + 1, size - 1)]
	var h_up = heights[maxi(z - 1, 0) * size + x]
	var h_down = heights[mini(z + 1, size - 1) * size + x]

	# Calculate gradient
	var dx = (h_right - h_left) / (2.0 * step)
	var dz = (h_down - h_up) / (2.0 * step)

	# Normal is perpendicular to the gradient
	var normal = Vector3(-dx, 1.0, -dz).normalized()
	return normal

## Get terrain color based on elevation and slope
static func _get_terrain_color(height: float, normal: Vector3) -> Color:
	# Calculate slope (how much normal deviates from straight up)
	var slope = 1.0 - normal.y  # 0 = flat, 1 = vertical

	# Base color is earth brown
	var color = TERRAIN_MATERIAL_COLOR

	# Low elevations near water level get more grass
	if height < 20.0 and slope < 0.3:
		var grass_factor = (1.0 - height / 20.0) * 0.5
		color = color.lerp(GRASS_COLOR, grass_factor)

	# Steep slopes get more rocky
	if slope > 0.4:
		var rock_factor = (slope - 0.4) / 0.6
		color = color.lerp(ROCK_COLOR, rock_factor)

	# Higher elevations slightly lighter
	if height > 80.0:
		var light_factor = minf((height - 80.0) / 100.0, 0.2)
		color = color.lightened(light_factor)

	return color

## Create the terrain material
static func _create_terrain_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()

	# Use vertex colors for terrain variation
	material.vertex_color_use_as_albedo = true
	material.albedo_color = TERRAIN_MATERIAL_COLOR

	# Rough, earthy surface
	material.roughness = 0.9
	material.metallic = 0.0
	material.metallic_specular = 0.1

	# No culling for terrain (visible from below if needed)
	material.cull_mode = BaseMaterial3D.CULL_BACK

	return material

## Create a simple flat terrain chunk (for areas without heightmap)
static func create_flat_terrain_chunk(
	chunk_key: Vector2i,
	chunk_size: float,
	elevation: float = 0.0
) -> MeshInstance3D:

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "FlatTerrain_" + str(chunk_key.x) + "_" + str(chunk_key.y)

	var plane = PlaneMesh.new()
	plane.size = Vector2(chunk_size, chunk_size)
	plane.subdivide_width = 4
	plane.subdivide_depth = 4

	var material = _create_terrain_material()
	plane.material = material

	mesh_instance.mesh = plane
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Convert OSM coordinates to Godot world position
	# OSM chunk_key.y is north, Godot Z is south
	var osm_origin_x = float(chunk_key.x) * chunk_size
	var osm_origin_y = float(chunk_key.y) * chunk_size

	# PlaneMesh is centered, so position at center of chunk
	mesh_instance.position = Vector3(
		osm_origin_x + chunk_size / 2.0,
		elevation,
		-osm_origin_y - chunk_size / 2.0  # Negate Y for Godot Z
	)

	return mesh_instance
