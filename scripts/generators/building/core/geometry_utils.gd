extends Node
class_name GeometryUtils

## Math and geometry utilities for building generation

## Calculate wall normal from two 2D points
static func calculate_wall_normal(p1: Vector2, p2: Vector2) -> Vector3:
	var wall_dir = (p2 - p1).normalized()
	return Vector3(-wall_dir.y, 0, wall_dir.x)  # Perpendicular, pointing outward

## Calculate tangent along wall
static func calculate_wall_tangent(p1: Vector2, p2: Vector2) -> Vector3:
	var wall_dir = (p2 - p1).normalized()
	return Vector3(wall_dir.x, 0, -wall_dir.y)

## Calculate bounding box of 2D polygon
static func calculate_bounding_box(polygon: Array) -> Rect2:
	if polygon.is_empty():
		return Rect2()

	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF

	for point in polygon:
		min_x = min(min_x, point.x)
		max_x = max(max_x, point.x)
		min_y = min(min_y, point.y)
		max_y = max(max_y, point.y)

	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)

## Convert 2D point to 3D (Y-up, Z-forward Godot convention)
static func to_3d(point: Vector2, y: float = 0.0) -> Vector3:
	return Vector3(point.x, y, -point.y)

## Calculate center of 2D polygon
static func calculate_center(polygon: Array) -> Vector2:
	if polygon.is_empty():
		return Vector2.ZERO

	var sum = Vector2.ZERO
	for point in polygon:
		sum += point
	return sum / float(polygon.size())
