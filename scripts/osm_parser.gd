extends Node
class_name OSMParser

# Parse OpenStreetMap data and convert to game format
# You can get OSM data from https://overpass-api.de/ or export from openstreetmap.org

# Example OSM query for Seattle downtown:
# [bbox:47.6,-122.35,47.65,-122.3];
# (way["building"];);
# out geom;

static func parse_osm_json(json_data: Dictionary) -> Dictionary:
	"""Parse OSM JSON and return dictionary with all features"""
	var features = {
		"buildings": [],
		"roads": [],
		"water": [],
		"parks": []
	}

	var elements = json_data.get("elements", [])
	for element in elements:
		if element.get("type") == "way" and element.has("tags"):
			var tags = element.get("tags", {})

			# Parse buildings (skip building:part entries - those are parts, not whole buildings)
			if tags.has("building") and tags.get("building:part", "") != "yes":
				var building_data = _parse_building(element)
				if building_data:
					features.buildings.append(building_data)

			# Parse roads (only driveable roads, skip footways/pedestrian paths)
			elif tags.has("highway"):
				var highway_type = tags.get("highway", "")
				# Only render actual driveable roads
				var driveable = ["motorway", "motorway_link", "trunk", "trunk_link",
								 "primary", "primary_link", "secondary", "secondary_link",
								 "tertiary", "tertiary_link", "residential", "unclassified"]
				if highway_type in driveable:
					var road_data = _parse_road(element)
					if road_data:
						features.roads.append(road_data)

			# Parse water bodies
			elif tags.has("natural") and tags["natural"] == "water":
				var water_data = _parse_water(element)
				if water_data:
					features.water.append(water_data)

			# Parse waterways
			elif tags.has("waterway"):
				var water_data = _parse_water(element)
				if water_data:
					features.water.append(water_data)

			# Parse parks
			elif tags.has("leisure") and tags["leisure"] == "park":
				var park_data = _parse_park(element)
				if park_data:
					features.parks.append(park_data)

	return features

static func _parse_building(element: Dictionary) -> Dictionary:
	"""Extract building data from OSM element"""
	var tags = element.get("tags", {})
	var geometry = element.get("geometry", [])

	if geometry.is_empty():
		return {}

	# Convert lat/lon to game coordinates
	var footprint = []
	var center = Vector2.ZERO

	for node in geometry:
		var lat = node.get("lat", 0.0)
		var lon = node.get("lon", 0.0)
		var point = _latlon_to_game_coords(lat, lon)
		footprint.append(point)
		center += point

	if footprint.size() > 0:
		center /= footprint.size()

	# Extract building attributes
	var building_data = {
		"id": element.get("id", 0),
		"name": tags.get("name", ""),
		"type": tags.get("building", "yes"),
		"footprint": footprint,
		"center": center,
		"height": _parse_height(tags),
		"levels": int(tags.get("building:levels", 2)),
		"min_level": int(tags.get("building:min_level", 0)),
		"layer": int(tags.get("layer", 0)),
		"amenity": tags.get("amenity", ""),
		"shop": tags.get("shop", ""),
		"addr_street": tags.get("addr:street", ""),
		"addr_housenumber": tags.get("addr:housenumber", ""),
	}

	return building_data

static func _latlon_to_game_coords(lat: float, lon: float) -> Vector2:
	"""Convert latitude/longitude to game X,Z coordinates"""
	# South Lake Union center (actual center of our OSM data)
	var seattle_center_lat = 47.626382
	var seattle_center_lon = -122.338937

	# Approximate conversion (1 degree ≈ 111km)
	# Scale to make 1 game unit = 1 meter
	var meters_per_degree_lat = 111000.0
	var meters_per_degree_lon = 111000.0 * cos(deg_to_rad(seattle_center_lat))

	var x = (lon - seattle_center_lon) * meters_per_degree_lon
	var z = -(lat - seattle_center_lat) * meters_per_degree_lat  # Negative because north is negative Z

	return Vector2(x, z)

static func _parse_height(tags: Dictionary) -> float:
	"""Parse building height from OSM tags"""
	# Try height tag first
	if tags.has("height"):
		var height_str = tags.get("height", "")
		# Handle "5 m", "15.5", etc.
		var height = float(height_str.replace(" m", "").replace("m", ""))
		if height > 0:
			return height

	# Estimate from levels
	if tags.has("building:levels"):
		var levels = int(tags.get("building:levels", 2))
		return levels * 3.0  # Assume 3m per floor

	# Default height
	return 6.0

static func _parse_road(element: Dictionary) -> Dictionary:
	"""Extract road data from OSM element"""
	var tags = element.get("tags", {})
	var geometry = element.get("geometry", [])

	if geometry.is_empty():
		return {}

	# Convert geometry to game coordinates
	var path = []
	for node in geometry:
		var lat = node.get("lat", 0.0)
		var lon = node.get("lon", 0.0)
		var point = _latlon_to_game_coords(lat, lon)
		path.append(point)

	# Determine road width from lanes data (preferred) or type
	var highway_type = tags.get("highway", "unclassified")
	var lanes = int(tags.get("lanes", 0))
	var width = 0.0

	if lanes > 0:
		# Use actual lane count: 3.5m per lane + 3m total for sidewalks
		width = (lanes * 3.5) + 3.0
	else:
		# Fallback to type-based width
		width = _get_road_width(highway_type)

	var road_data = {
		"id": element.get("id", 0),
		"name": tags.get("name", ""),
		"type": highway_type,
		"path": path,
		"width": width,
		"lanes": lanes,
		"layer": int(tags.get("layer", 0)),
		"bridge": tags.get("bridge", ""),
	}

	return road_data

static func _parse_water(element: Dictionary) -> Dictionary:
	"""Extract water body data from OSM element"""
	var tags = element.get("tags", {})
	var geometry = element.get("geometry", [])

	if geometry.is_empty():
		return {}

	var polygon = []
	for node in geometry:
		var lat = node.get("lat", 0.0)
		var lon = node.get("lon", 0.0)
		var point = _latlon_to_game_coords(lat, lon)
		polygon.append(point)

	var water_data = {
		"id": element.get("id", 0),
		"name": tags.get("name", "Water"),
		"type": tags.get("natural", tags.get("waterway", "water")),
		"polygon": polygon,
	}

	return water_data

static func _parse_park(element: Dictionary) -> Dictionary:
	"""Extract park data from OSM element"""
	var tags = element.get("tags", {})
	var geometry = element.get("geometry", [])

	if geometry.is_empty():
		return {}

	var polygon = []
	for node in geometry:
		var lat = node.get("lat", 0.0)
		var lon = node.get("lon", 0.0)
		var point = _latlon_to_game_coords(lat, lon)
		polygon.append(point)

	var park_data = {
		"id": element.get("id", 0),
		"name": tags.get("name", "Park"),
		"polygon": polygon,
	}

	return park_data

static func _get_road_width(highway_type: String) -> float:
	"""Get road width based on highway type (includes lanes + sidewalks)"""
	match highway_type:
		"motorway": return 25.0  # Highway with shoulders
		"trunk": return 20.0  # Major arterial
		"primary": return 18.0  # Primary arterial like Mercer (4-6 lanes + sidewalks)
		"secondary": return 14.0  # Secondary arterial (2-4 lanes + sidewalks)
		"tertiary": return 12.0  # Collector street
		"residential": return 10.0  # Residential street with parking
		"service": return 6.0  # Alley/parking lot
		"footway", "path", "pedestrian": return 3.0  # Sidewalk/path
		"cycleway": return 2.5  # Bike lane
		"steps": return 2.0  # Stairs
		_: return 8.0  # Default

static func load_osm_file(file_path: String) -> Dictionary:
	"""Load OSM data from a JSON file"""
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Could not open OSM file: " + file_path)
		return {"buildings": [], "roads": [], "water": [], "parks": []}

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("JSON Parse Error: " + json.get_error_message())
		return {"buildings": [], "roads": [], "water": [], "parks": []}

	return parse_osm_json(json.data)

# Example function to fetch OSM data (would need HTTP request in actual implementation)
static func fetch_osm_area(_min_lat: float, _min_lon: float, _max_lat: float, _max_lon: float) -> Array:
	"""Fetch OSM data for a bounding box (placeholder for actual HTTP request)"""
	# In a real implementation, this would use HTTPRequest to query Overpass API
	# For now, return empty array - use load_osm_file() with pre-downloaded data
	push_warning("fetch_osm_area not implemented - use load_osm_file() instead")
	return []
