extends Node

## Polygon triangulation using Godot's built-in Geometry2D
## Much more robust than custom implementation

class_name PolygonTriangulator

## Triangulate a polygon into triangle indices using Godot's built-in function
## Input: Array of Vector2 points (polygon vertices)
## Output: PackedInt32Array of triangle indices (3 indices per triangle)
static func triangulate(polygon: Array) -> PackedInt32Array:
	if polygon.size() < 3:
		return PackedInt32Array()

	# Convert Array to PackedVector2Array for Godot's built-in function
	var packed_polygon = PackedVector2Array()
	for point in polygon:
		packed_polygon.append(point)

	# Clean up polygon: remove duplicate consecutive points
	# Godot's triangulate_polygon() expects NO duplicate closing point - it auto-closes
	var cleaned = PackedVector2Array()
	cleaned.append(packed_polygon[0])

	for i in range(1, packed_polygon.size()):
		if packed_polygon[i].distance_to(cleaned[cleaned.size() - 1]) > 0.01:  # 1cm threshold
			cleaned.append(packed_polygon[i])

	# Remove last point if it's a duplicate of first (Godot auto-closes internally)
	if cleaned.size() > 2 and cleaned[cleaned.size() - 1].distance_to(cleaned[0]) < 0.01:
		cleaned.resize(cleaned.size() - 1)

	if cleaned.size() < 3:
		return PackedInt32Array()

	# Use Godot's built-in triangulation directly - no fixes, no fallbacks
	var triangle_indices = Geometry2D.triangulate_polygon(cleaned)

	# Debug output
	if triangle_indices.is_empty() and cleaned.size() > 0:
		print("   ❌ TRIANGULATION FAILED for ", cleaned.size(), " point polygon")
		print("   First 5 vertices: ")
		for i in range(min(5, cleaned.size())):
			print("      [", i, "] = ", cleaned[i])
		print("   Last vertex: ", cleaned[cleaned.size() - 1])
	elif cleaned.size() > 100:
		print("   ✅ Successfully triangulated: ", cleaned.size(), " points -> ", int(triangle_indices.size() / 3.0), " triangles")

	return triangle_indices

## Check if polygon has self-intersections
## Returns the number of intersections found
static func _check_self_intersections(polygon: PackedVector2Array) -> int:
	var count = 0
	var n = polygon.size()

	# Check each edge against all other non-adjacent edges
	for i in range(n):
		var a1 = polygon[i]
		var a2 = polygon[(i + 1) % n]

		# Start checking from i+2 to avoid adjacent edges
		for j in range(i + 2, n):
			# Skip if this is the closing edge and we're checking the first edge
			if i == 0 and j == n - 1:
				continue

			var b1 = polygon[j]
			var b2 = polygon[(j + 1) % n]

			if _segments_intersect(a1, a2, b1, b2):
				count += 1

	return count

## Check if two line segments intersect
static func _segments_intersect(a1: Vector2, a2: Vector2, b1: Vector2, b2: Vector2) -> bool:
	var d1 = _cross_product_2d(b2 - b1, a1 - b1)
	var d2 = _cross_product_2d(b2 - b1, a2 - b1)
	var d3 = _cross_product_2d(a2 - a1, b1 - a1)
	var d4 = _cross_product_2d(a2 - a1, b2 - a1)

	# Segments intersect if signs are different (proper intersection)
	if ((d1 > 0 and d2 < 0) or (d1 < 0 and d2 > 0)) and \
	   ((d3 > 0 and d4 < 0) or (d3 < 0 and d4 > 0)):
		return true

	return false

## 2D cross product (returns scalar)
static func _cross_product_2d(a: Vector2, b: Vector2) -> float:
	return a.x * b.y - a.y * b.x

## Calculate polygon area using shoelace formula
static func _calculate_area(polygon: PackedVector2Array) -> float:
	if polygon.size() < 3:
		return 0.0

	var area = 0.0
	var n = polygon.size()

	for i in range(n):
		var j = (i + 1) % n
		area += polygon[i].x * polygon[j].y
		area -= polygon[j].x * polygon[i].y

	return abs(area) / 2.0
