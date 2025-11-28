## HeightmapLoader - Loads and queries terrain elevation data
##
## Loads 16-bit grayscale PNG heightmaps (e.g., from USGS 3DEP DEM data).
## Must call load_heightmap() before querying elevation.
##
## Usage:
##   var heightmap = HeightmapLoader.new()
##   if heightmap.load_heightmap("res://data/heightmap/heightmap_config.json"):
##       var elevation = heightmap.get_elevation(world_x, world_z)

class_name HeightmapLoader
extends RefCounted

## Configuration
var world_origin_x: float = -5000.0
var world_origin_z: float = -5000.0
var world_size_x: float = 10000.0
var world_size_z: float = 10000.0
var elevation_scale: float = 1.0
var elevation_offset: float = 0.0
var water_level: float = 0.5  # Sea level / lake surface (config overrides this)

## Heightmap image data
var heightmap_image: Image = null
var heightmap_width: int = 0
var heightmap_height: int = 0

## Precomputed conversion factors
var _pixels_per_meter_x: float = 0.0
var _pixels_per_meter_z: float = 0.0

## Water body polygons from OSM (for terrain depression)
var _water_polygons: Array = []  # Array of {footprint: Array[Vector2], bounds: Rect2}


## Load heightmap from config file
func load_heightmap(config_path: String) -> bool:
	if config_path == "" or not FileAccess.file_exists(config_path):
		push_error("HeightmapLoader: Config file not found: " + config_path)
		return false
	return _load_from_config(config_path)

## Load from JSON config and PNG heightmap
func _load_from_config(config_path: String) -> bool:
	var file = FileAccess.open(config_path, FileAccess.READ)
	if not file:
		push_error("HeightmapLoader: Failed to open config: " + config_path)
		return false

	var json = JSON.new()
	var parse_result = json.parse(file.get_as_text())
	file.close()

	if parse_result != OK:
		push_error("HeightmapLoader: Failed to parse config JSON")
		return false

	var config = json.data

	# Load configuration
	world_origin_x = config.get("world_origin_x", world_origin_x)
	world_origin_z = config.get("world_origin_z", world_origin_z)
	world_size_x = config.get("world_size_x", world_size_x)
	world_size_z = config.get("world_size_z", world_size_z)
	elevation_scale = config.get("elevation_scale", elevation_scale)
	elevation_offset = config.get("elevation_offset", elevation_offset)
	water_level = config.get("water_level", water_level)

	# Load heightmap image
	var heightmap_file = config.get("heightmap_file", "")
	if heightmap_file == "":
		push_error("HeightmapLoader: No heightmap_file in config")
		return false

	var heightmap_path = config_path.get_base_dir() + "/" + heightmap_file
	heightmap_image = Image.load_from_file(heightmap_path)

	if heightmap_image == null:
		push_error("HeightmapLoader: Failed to load heightmap: " + heightmap_path)
		return false

	heightmap_width = heightmap_image.get_width()
	heightmap_height = heightmap_image.get_height()

	# Precompute conversion factors
	_pixels_per_meter_x = float(heightmap_width) / world_size_x
	_pixels_per_meter_z = float(heightmap_height) / world_size_z

	print("HeightmapLoader: Loaded ", heightmap_width, "x", heightmap_height, " heightmap")

	return true

## Get elevation at world coordinates
## world_x: X position in game world (East is positive)
## world_z: Z position in game world (South is positive in Godot, but OSM Y becomes -Z)
func get_elevation(world_x: float, world_z: float) -> float:
	if heightmap_image == null:
		push_error("HeightmapLoader: get_elevation called but no heightmap loaded")
		return 0.0
	return _sample_heightmap(world_x, world_z)

## Get water level (for lakes, rivers)
func get_water_level() -> float:
	return water_level

## Sample elevation from loaded heightmap with bilinear interpolation
func _sample_heightmap(world_x: float, world_z: float) -> float:
	# Convert world coordinates to pixel coordinates
	var pixel_x = (world_x - world_origin_x) * _pixels_per_meter_x
	var pixel_z = (world_z - world_origin_z) * _pixels_per_meter_z

	# Clamp to image bounds
	pixel_x = clampf(pixel_x, 0.0, float(heightmap_width - 1))
	pixel_z = clampf(pixel_z, 0.0, float(heightmap_height - 1))

	# Get integer and fractional parts for bilinear interpolation
	var x0 = int(pixel_x)
	var z0 = int(pixel_z)
	var x1 = mini(x0 + 1, heightmap_width - 1)
	var z1 = mini(z0 + 1, heightmap_height - 1)
	var fx = pixel_x - float(x0)
	var fz = pixel_z - float(z0)

	# Sample 4 corners
	var h00 = _get_pixel_height(x0, z0)
	var h10 = _get_pixel_height(x1, z0)
	var h01 = _get_pixel_height(x0, z1)
	var h11 = _get_pixel_height(x1, z1)

	# Bilinear interpolation
	var h0 = lerpf(h00, h10, fx)
	var h1 = lerpf(h01, h11, fx)
	var height = lerpf(h0, h1, fz)

	return height * elevation_scale + elevation_offset

## Get height value from a pixel (0-1 normalized range)
## For 16-bit grayscale PNG, Godot's get_pixel() returns normalized values
## The elevation_scale and elevation_offset in config convert this to meters
func _get_pixel_height(x: int, z: int) -> float:
	var color = heightmap_image.get_pixel(x, z)
	# Use red channel (for grayscale images, R=G=B)
	# Returns 0.0-1.0 normalized value for both 8-bit and 16-bit images
	return color.r

## Register water bodies from OSM data for terrain depression
## water_data_array: Array of dictionaries with "footprint" (Array[Vector2]) keys
## Footprints should be in OSM coordinates (x, y where y is north)
func register_water_bodies(water_data_array: Array) -> void:
	_water_polygons.clear()

	for water_data in water_data_array:
		var footprint = water_data.get("footprint", [])
		if footprint.size() < 3:
			continue

		# Calculate bounding box for quick rejection
		var min_x = INF
		var max_x = -INF
		var min_y = INF
		var max_y = -INF

		for point in footprint:
			min_x = minf(min_x, point.x)
			max_x = maxf(max_x, point.x)
			min_y = minf(min_y, point.y)
			max_y = maxf(max_y, point.y)

		_water_polygons.append({
			"footprint": footprint,
			"bounds": Rect2(min_x, min_y, max_x - min_x, max_y - min_y)
		})

	print("HeightmapLoader: Registered ", _water_polygons.size(), " water bodies for terrain depression")

## Check if a position is over water (OSM water polygons)
## world_x, world_z: Godot world coordinates (Z is south-positive)
func is_water(world_x: float, world_z: float) -> bool:
	# Convert Godot coords back to OSM coords for polygon check
	var osm_x = world_x
	var osm_y = -world_z  # Godot -Z = OSM Y (north)
	return _is_point_in_water_polygon(osm_x, osm_y)

## Check if OSM point is inside any registered water polygon
func _is_point_in_water_polygon(osm_x: float, osm_y: float) -> bool:
	for water in _water_polygons:
		var bounds: Rect2 = water.bounds

		# Quick bounding box rejection
		if osm_x < bounds.position.x or osm_x > bounds.position.x + bounds.size.x:
			continue
		if osm_y < bounds.position.y or osm_y > bounds.position.y + bounds.size.y:
			continue

		# Full point-in-polygon test
		if _point_in_polygon(Vector2(osm_x, osm_y), water.footprint):
			return true

	return false

## Point-in-polygon test using ray casting algorithm
func _point_in_polygon(point: Vector2, polygon: Array) -> bool:
	var n = polygon.size()
	if n < 3:
		return false

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

## Get terrain bounds
func get_bounds() -> Rect2:
	return Rect2(world_origin_x, world_origin_z, world_size_x, world_size_z)

## Debug: Get elevation at a grid of points (for visualization)
func get_elevation_grid(center: Vector2, size: float, resolution: int) -> Array:
	var grid = []
	var step = size / float(resolution - 1)
	var half_size = size / 2.0

	for z in range(resolution):
		var row = []
		for x in range(resolution):
			var world_x = center.x - half_size + x * step
			var world_z = center.y - half_size + z * step
			row.append(get_elevation(world_x, world_z))
		grid.append(row)

	return grid
