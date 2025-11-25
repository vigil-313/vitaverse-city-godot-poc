extends Node
class_name FlatRoof

## Generates flat roof geometry (triangulated polygon)

## Generate flat roof
static func generate(
	footprint: Array,
	center: Vector2,
	building_height: float,
	roof_surface
) -> void:
	if footprint.size() < 3:
		return

	# Place roof slightly above cornice to avoid z-fighting
	var roof_y = building_height + 0.05  # 5cm above building top/cornice
	var base_index = roof_surface.vertices.size()

	# Convert footprint to local coordinates
	var local_polygon = []
	for point in footprint:
		local_polygon.append(point - center)

	# Use Godot's built-in triangulation (handles concave footprints correctly)
	var roof_indices_raw = PolygonTriangulator.triangulate(local_polygon)

	# REVERSE indices for correct winding order (normals facing UP)
	var roof_indices_reversed = PackedInt32Array()
	for i in range(0, roof_indices_raw.size(), 3):
		roof_indices_reversed.append(roof_indices_raw[i + 2])
		roof_indices_reversed.append(roof_indices_raw[i + 1])
		roof_indices_reversed.append(roof_indices_raw[i])

	# Add roof vertices
	for point in local_polygon:
		roof_surface.vertices.append(Vector3(point.x, roof_y, -point.y))
		roof_surface.normals.append(Vector3.UP)
		roof_surface.uvs.append(Vector2(point.x, point.y))

	# Add triangulated indices (offset by base_index)
	for idx in roof_indices_reversed:
		roof_surface.indices.append(base_index + idx)
