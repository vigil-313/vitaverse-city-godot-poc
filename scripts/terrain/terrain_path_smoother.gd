extends RefCounted
class_name TerrainPathSmoother

## Terrain Path Smoother
## Creates smooth 3D paths that follow terrain without clipping through or hovering.
## Used for roads, sidewalks, and other ground-following features.

## Configuration
const RESAMPLE_INTERVAL: float = 5.0  # Meters between path samples
const CROSS_SAMPLES: int = 5  # Number of samples across road width
const SMOOTHING_KERNEL_SIZE: int = 3  # Gaussian smoothing kernel size
const MIN_CLEARANCE: float = 0.15  # Minimum meters above terrain
const MAX_SLOPE: float = 0.15  # Maximum slope (rise/run) before flattening


## Smooth a 2D path to follow terrain, returning 3D positions
## path: Array of Vector2 positions (game coordinates)
## heightmap: HeightmapLoader instance
## road_width: Width of the road (for cross-sampling)
## Returns: Array of Vector3 with smoothed elevation
static func smooth_path(path: Array, heightmap, road_width: float) -> Array:
	if path.size() < 2 or heightmap == null:
		return _convert_to_3d_flat(path)

	# Step 1: Resample path to uniform spacing
	var resampled = _resample_path(path, RESAMPLE_INTERVAL)
	if resampled.size() < 2:
		return _convert_to_3d_flat(path)

	# Step 2: Sample terrain elevations with cross-road averaging
	var elevations = _sample_cross_section_elevations(resampled, heightmap, road_width)

	# Step 3: Apply Gaussian smoothing
	var smoothed = _gaussian_smooth(elevations, SMOOTHING_KERNEL_SIZE)

	# Step 4: Enforce minimum clearance above terrain
	smoothed = _enforce_minimum_clearance(resampled, smoothed, heightmap, road_width)

	# Step 5: Limit slope transitions
	smoothed = _limit_slopes(resampled, smoothed)

	# Step 6: Combine positions with elevations
	return _combine_with_positions(resampled, smoothed)


## Resample path to uniform spacing
static func _resample_path(path: Array, interval: float) -> Array:
	if path.size() < 2:
		return path.duplicate()

	var result: Array = []
	result.append(path[0])

	var accumulated_distance = 0.0
	var current_point = path[0]

	for i in range(1, path.size()):
		var next_point = path[i]
		var segment_dir = (next_point - current_point).normalized()
		var segment_length = current_point.distance_to(next_point)

		var remaining = segment_length
		while remaining > 0:
			var distance_to_next_sample = interval - accumulated_distance

			if distance_to_next_sample <= remaining:
				# Add a sample point
				var t = (segment_length - remaining + distance_to_next_sample) / segment_length
				var sample_point = current_point.lerp(next_point, t)
				result.append(sample_point)
				accumulated_distance = 0.0
				remaining -= distance_to_next_sample
			else:
				# Move to next segment
				accumulated_distance += remaining
				remaining = 0

		current_point = next_point

	# Always include the last point
	if result[result.size() - 1].distance_to(path[path.size() - 1]) > 0.1:
		result.append(path[path.size() - 1])

	return result


## Sample terrain elevation across road width at each point
static func _sample_cross_section_elevations(path: Array, heightmap, road_width: float) -> Array:
	var elevations: Array = []

	for i in range(path.size()):
		var point = path[i]

		# Get direction for perpendicular sampling
		var direction: Vector2
		if i == 0:
			direction = (path[1] - path[0]).normalized()
		elif i == path.size() - 1:
			direction = (path[i] - path[i - 1]).normalized()
		else:
			var dir_prev = (path[i] - path[i - 1]).normalized()
			var dir_next = (path[i + 1] - path[i]).normalized()
			direction = (dir_prev + dir_next).normalized()

		var perpendicular = Vector2(-direction.y, direction.x)

		# Sample across the width
		var samples: Array = []
		var half_width = road_width / 2.0

		for j in range(CROSS_SAMPLES):
			var t = float(j) / float(CROSS_SAMPLES - 1) - 0.5  # -0.5 to 0.5
			var sample_pos = point + perpendicular * (t * road_width)
			var elevation = heightmap.get_elevation(sample_pos.x, -sample_pos.y)
			samples.append(elevation)

		# Weighted average (center-heavy)
		# Weights: [0.1, 0.2, 0.4, 0.2, 0.1] for 5 samples
		var weights = _get_center_weights(CROSS_SAMPLES)
		var weighted_sum = 0.0
		var weight_total = 0.0

		for j in range(samples.size()):
			weighted_sum += samples[j] * weights[j]
			weight_total += weights[j]

		elevations.append(weighted_sum / weight_total)

	return elevations


## Generate center-weighted distribution
static func _get_center_weights(count: int) -> Array:
	var weights: Array = []
	var center = float(count - 1) / 2.0

	for i in range(count):
		var distance_from_center = abs(float(i) - center)
		var weight = 1.0 - (distance_from_center / center) * 0.75  # 0.25 at edges, 1.0 at center
		weights.append(weight)

	return weights


## Apply Gaussian smoothing to elevation array
static func _gaussian_smooth(values: Array, kernel_size: int) -> Array:
	if values.size() < kernel_size:
		return values.duplicate()

	var result: Array = []
	var half_kernel = kernel_size / 2

	# Generate Gaussian kernel
	var kernel: Array = []
	var sigma = float(kernel_size) / 3.0
	var kernel_sum = 0.0

	for i in range(kernel_size):
		var x = float(i - half_kernel)
		var weight = exp(-(x * x) / (2.0 * sigma * sigma))
		kernel.append(weight)
		kernel_sum += weight

	# Normalize kernel
	for i in range(kernel.size()):
		kernel[i] /= kernel_sum

	# Apply convolution
	for i in range(values.size()):
		var smoothed_value = 0.0

		for j in range(kernel_size):
			var sample_idx = i + j - half_kernel
			# Clamp to array bounds
			sample_idx = clampi(sample_idx, 0, values.size() - 1)
			smoothed_value += values[sample_idx] * kernel[j]

		result.append(smoothed_value)

	return result


## Ensure road stays above terrain with minimum clearance
static func _enforce_minimum_clearance(path: Array, elevations: Array, heightmap, road_width: float) -> Array:
	var result: Array = []
	var half_width = road_width / 2.0

	for i in range(path.size()):
		var point = path[i]

		# Find maximum terrain height in a radius around the point
		var max_terrain = elevations[i]  # Start with smoothed elevation

		# Sample a small area to find local maximum
		var sample_radius = half_width + 1.0  # Road width plus buffer
		var sample_points = [
			Vector2(point.x, point.y),
			Vector2(point.x + sample_radius, point.y),
			Vector2(point.x - sample_radius, point.y),
			Vector2(point.x, point.y + sample_radius),
			Vector2(point.x, point.y - sample_radius),
		]

		for sample in sample_points:
			var sample_elev = heightmap.get_elevation(sample.x, -sample.y)
			max_terrain = max(max_terrain, sample_elev)

		# Ensure minimum clearance
		var final_elevation = max(elevations[i], max_terrain + MIN_CLEARANCE)
		result.append(final_elevation)

	return result


## Limit slope transitions to prevent unrealistic road angles
static func _limit_slopes(path: Array, elevations: Array) -> Array:
	if elevations.size() < 2:
		return elevations.duplicate()

	var result = elevations.duplicate()

	# Forward pass - limit upward slopes
	for i in range(1, result.size()):
		var distance = path[i].distance_to(path[i - 1])
		if distance < 0.1:
			continue

		var max_rise = distance * MAX_SLOPE
		var prev_elev = result[i - 1]

		if result[i] > prev_elev + max_rise:
			result[i] = prev_elev + max_rise

	# Backward pass - limit downward slopes
	for i in range(result.size() - 2, -1, -1):
		var distance = path[i].distance_to(path[i + 1])
		if distance < 0.1:
			continue

		var max_rise = distance * MAX_SLOPE
		var next_elev = result[i + 1]

		if result[i] > next_elev + max_rise:
			result[i] = next_elev + max_rise

	return result


## Combine 2D positions with elevations to create 3D path
static func _combine_with_positions(path: Array, elevations: Array) -> Array:
	var result: Array = []

	for i in range(min(path.size(), elevations.size())):
		var pos_2d = path[i]
		var elevation = elevations[i]
		result.append(Vector3(pos_2d.x, elevation, -pos_2d.y))

	return result


## Fallback: convert 2D path to 3D with zero elevation
static func _convert_to_3d_flat(path: Array) -> Array:
	var result: Array = []
	for point in path:
		result.append(Vector3(point.x, 0.0, -point.y))
	return result


## Get elevation at a single point with smoothing (for standalone queries)
static func get_smoothed_elevation(position: Vector2, heightmap, radius: float = 5.0) -> float:
	if heightmap == null:
		return 0.0

	# Sample in a small area and average
	var samples = [
		heightmap.get_elevation(position.x, -position.y),
		heightmap.get_elevation(position.x + radius, -position.y),
		heightmap.get_elevation(position.x - radius, -position.y),
		heightmap.get_elevation(position.x, -position.y + radius),
		heightmap.get_elevation(position.x, -position.y - radius),
	]

	# Weighted average (center heavy)
	return samples[0] * 0.4 + (samples[1] + samples[2] + samples[3] + samples[4]) * 0.15
