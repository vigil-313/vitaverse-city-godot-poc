extends Node

## Complete OSM Data Parser
## Extracts ALL available tags from OpenStreetMap data
## Preserves full building detail: colors, materials, roofs, architecture, etc.
##
## This parser captures EVERYTHING from OSM:
## - Building: type, levels, height, color, material, architecture
## - Roof: shape, color, material, height, angle
## - Address: full address information
## - Metadata: name, dates, heritage info
## - Geometry: exact footprints, node coordinates

class_name OSMDataComplete

## Parsed OSM data storage
var buildings: Array = []
var roads: Array = []
var parks: Array = []
var water: Array = []
var amenities: Array = []

## Coordinate transformation data
var center_lat: float = 47.6062  # Seattle city center
var center_lon: float = -122.3321
var meters_per_degree_lat: float = 111320.0
var meters_per_degree_lon: float = 0.0

## Load and parse complete OSM JSON file
func load_osm_data(file_path: String) -> bool:
	print("📂 Loading complete OSM data from: ", file_path)

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to open OSM file: " + file_path)
		return false

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		push_error("Failed to parse OSM JSON")
		return false

	var data = json.data
	if not data.has("elements"):
		push_error("OSM data missing 'elements'")
		return false

	# Calculate meters per degree longitude at this latitude
	meters_per_degree_lon = 111320.0 * cos(deg_to_rad(center_lat))

	_parse_osm_elements(data.elements)

	print("✅ OSM data loaded successfully")
	print("   🏢 Buildings: ", buildings.size())
	print("   🛣️  Roads: ", roads.size())
	print("   🌳 Parks: ", parks.size())
	print("   💧 Water: ", water.size())

	return true

## Parse all OSM elements
func _parse_osm_elements(elements: Array):
	# First pass: collect all nodes for coordinate lookup
	var nodes_dict = {}
	for element in elements:
		if element.get("type") == "node":
			nodes_dict[element.get("id")] = element

	# Second pass: parse ways and relations
	for element in elements:
		var type = element.get("type", "")
		var tags = element.get("tags", {})

		if type == "way":
			# Buildings
			if tags.has("building") and tags.get("building:part", "") != "yes":
				var building_data = _parse_complete_building(element, nodes_dict)
				if building_data:
					buildings.append(building_data)

			# Roads
			elif tags.has("highway"):
				var road_data = _parse_complete_road(element, nodes_dict)
				if road_data:
					roads.append(road_data)

			# Parks
			elif tags.has("leisure") or (tags.has("landuse") and tags.get("landuse") in ["park", "grass", "recreation_ground"]):
				var park_data = _parse_park(element, nodes_dict)
				if park_data:
					parks.append(park_data)

			# Water
			elif tags.get("natural") == "water" or tags.has("waterway"):
				var water_data = _parse_water(element, nodes_dict)
				if water_data:
					water.append(water_data)

		elif type == "relation":
			# Water relations (like Lake Union)
			if tags.get("natural") == "water" or tags.has("waterway"):
				var water_data = _parse_water_relation(element, elements)
				if water_data:
					water.append(water_data)

## Parse complete building with ALL available tags
func _parse_complete_building(element: Dictionary, nodes: Dictionary) -> Dictionary:
	var tags = element.get("tags", {})
	var node_refs = element.get("nodes", [])

	# Get footprint coordinates
	var footprint = []
	for node_id in node_refs:
		if nodes.has(node_id):
			var node = nodes[node_id]
			var pos = _latlon_to_meters(node.get("lat"), node.get("lon"))
			footprint.append(pos)

	if footprint.size() < 3:
		return {}  # Invalid footprint

	# Calculate center
	var center = _calculate_centroid(footprint)

	# Extract ALL building attributes
	var building_data = {
		"id": element.get("id"),
		"footprint": footprint,
		"center": center,

		# === BASIC INFO ===
		"name": tags.get("name", ""),
		"building_type": tags.get("building", "yes"),

		# === DIMENSIONS ===
		"height": _parse_height(tags),
		"levels": int(tags.get("building:levels", 2)),
		"min_level": int(tags.get("building:min_level", 0)),
		"layer": int(tags.get("layer", 0)),

		# === BUILDING APPEARANCE ===
		"building:colour": tags.get("building:colour", tags.get("building:color", "")),
		"building:material": tags.get("building:material", ""),
		"building:cladding": tags.get("building:cladding", ""),
		"building:architecture": tags.get("building:architecture", ""),

		# === ROOF DATA ===
		"roof:shape": tags.get("roof:shape", ""),  # Empty string = infer from building type
		"roof:colour": tags.get("roof:colour", tags.get("roof:color", "")),
		"roof:material": tags.get("roof:material", ""),
		"roof:height": float(tags.get("roof:height", 0)),
		"roof:angle": float(tags.get("roof:angle", 0)),
		"roof:orientation": tags.get("roof:orientation", ""),
		"roof:direction": tags.get("roof:direction", ""),
		"roof:levels": int(tags.get("roof:levels", 0)),

		# === ADDRESS ===
		"addr:housenumber": tags.get("addr:housenumber", ""),
		"addr:street": tags.get("addr:street", ""),
		"addr:city": tags.get("addr:city", ""),
		"addr:postcode": tags.get("addr:postcode", ""),

		# === METADATA ===
		"start_date": tags.get("start_date", ""),
		"construction_date": tags.get("construction_date", ""),
		"heritage": tags.get("heritage", ""),
		"historic": tags.get("historic", ""),
		"wikidata": tags.get("wikidata", ""),

		# === USAGE ===
		"amenity": tags.get("amenity", ""),
		"shop": tags.get("shop", ""),
		"office": tags.get("office", ""),

		# === ALL TAGS (for future use) ===
		"all_tags": tags
	}

	return building_data

## Parse complete road with ALL available tags
func _parse_complete_road(element: Dictionary, nodes: Dictionary) -> Dictionary:
	var tags = element.get("tags", {})
	var node_refs = element.get("nodes", [])

	# Get path coordinates
	var path = []
	for node_id in node_refs:
		if nodes.has(node_id):
			var node = nodes[node_id]
			var pos = _latlon_to_meters(node.get("lat"), node.get("lon"))
			path.append(pos)

	if path.size() < 2:
		return {}  # Invalid path

	var road_data = {
		"id": element.get("id"),
		"path": path,
		"name": tags.get("name", ""),
		"highway_type": tags.get("highway", ""),
		"lanes": int(tags.get("lanes", 0)),
		"width": float(tags.get("width", 0)),
		"surface": tags.get("surface", ""),
		"layer": int(tags.get("layer", 0)),
		"bridge": tags.get("bridge", "") == "yes",
		"tunnel": tags.get("tunnel", "") == "yes",
		"oneway": tags.get("oneway", "") == "yes",
		"all_tags": tags
	}

	return road_data

## Parse park/leisure area
func _parse_park(element: Dictionary, nodes: Dictionary) -> Dictionary:
	var tags = element.get("tags", {})
	var node_refs = element.get("nodes", [])

	var footprint = []
	for node_id in node_refs:
		if nodes.has(node_id):
			var node = nodes[node_id]
			var pos = _latlon_to_meters(node.get("lat"), node.get("lon"))
			footprint.append(pos)

	if footprint.size() < 3:
		return {}

	return {
		"id": element.get("id"),
		"footprint": footprint,
		"center": _calculate_centroid(footprint),
		"name": tags.get("name", ""),
		"leisure_type": tags.get("leisure", tags.get("landuse", "")),
		"all_tags": tags
	}

## Parse water feature
func _parse_water(element: Dictionary, nodes: Dictionary) -> Dictionary:
	var tags = element.get("tags", {})
	var node_refs = element.get("nodes", [])

	var footprint = []
	for node_id in node_refs:
		if nodes.has(node_id):
			var node = nodes[node_id]
			var pos = _latlon_to_meters(node.get("lat"), node.get("lon"))
			footprint.append(pos)

	if footprint.size() < 3:
		return {}

	return {
		"id": element.get("id"),
		"footprint": footprint,
		"center": _calculate_centroid(footprint),
		"name": tags.get("name", ""),
		"water_type": tags.get("natural", tags.get("waterway", "")),
		"all_tags": tags
	}

## Parse height from OSM tags (priority: height > levels)
func _parse_height(tags: Dictionary) -> float:
	# Priority 1: Explicit height
	if tags.has("height"):
		var height_str = str(tags.get("height")).replace(" m", "").replace("m", "")
		var height = float(height_str)
		if height > 0:
			return height

	# Priority 2: building:levels × 3m per floor
	if tags.has("building:levels"):
		return int(tags.get("building:levels")) * 3.0

	# Default: 2 floors
	return 6.0

## Convert lat/lon to game coordinates (meters from center)
func _latlon_to_meters(lat: float, lon: float) -> Vector2:
	var x = (lon - center_lon) * meters_per_degree_lon
	var y = (lat - center_lat) * meters_per_degree_lat
	return Vector2(x, y)

## Parse water relation (like Lake Union - multipolygon)
func _parse_water_relation(element: Dictionary, all_elements: Array) -> Dictionary:
	var tags = element.get("tags", {})
	var members = element.get("members", [])

	# Create a lookup dictionary for ways
	var ways_dict = {}
	for elem in all_elements:
		if elem.get("type") == "way":
			ways_dict[elem.get("id")] = elem

	# Collect outer ways first
	var outer_ways = []
	for member in members:
		if member.get("role") == "outer" and member.get("type") == "way":
			var way_id = member.get("ref")
			if ways_dict.has(way_id):
				var way = ways_dict[way_id]
				var node_refs = way.get("nodes", [])
				if node_refs.size() >= 2:
					outer_ways.append(node_refs)

	if outer_ways.is_empty():
		return {}

	# Assemble ways into a single closed polygon by connecting them end-to-end
	var all_way_nodes = []
	all_way_nodes.append_array(outer_ways[0])  # Start with first way
	outer_ways.remove_at(0)

	# Keep joining ways until all are connected
	while not outer_ways.is_empty():
		var current_end = all_way_nodes[all_way_nodes.size() - 1]
		var found_connection = false

		for i in range(outer_ways.size()):
			var way = outer_ways[i]
			var way_start = way[0]
			var way_end = way[way.size() - 1]

			# Check if this way connects to our current end
			if way_start == current_end:
				# Connects forward - append (skip first node to avoid duplicate)
				for j in range(1, way.size()):
					all_way_nodes.append(way[j])
				outer_ways.remove_at(i)
				found_connection = true
				break
			elif way_end == current_end:
				# Connects backward - append reversed (skip last node)
				for j in range(way.size() - 2, -1, -1):
					all_way_nodes.append(way[j])
				outer_ways.remove_at(i)
				found_connection = true
				break

		# If no connection found, we have a broken polygon - just append remaining ways
		if not found_connection:
			print("   ⚠️  Warning: Broken polygon - ways don't connect properly")
			for way in outer_ways:
				for node in way:
					if node != all_way_nodes[all_way_nodes.size() - 1]:
						all_way_nodes.append(node)
			break

	if all_way_nodes.size() < 3:
		return {}  # Not enough nodes for a valid polygon

	# Convert node IDs to coordinates
	var footprint = []
	var nodes_dict = {}
	for elem in all_elements:
		if elem.get("type") == "node":
			nodes_dict[elem.get("id")] = elem

	for node_id in all_way_nodes:
		if nodes_dict.has(node_id):
			var node = nodes_dict[node_id]
			var pos = _latlon_to_meters(node.get("lat"), node.get("lon"))
			footprint.append(pos)

	if footprint.size() < 3:
		return {}

	return {
		"id": element.get("id"),
		"footprint": footprint,
		"center": _calculate_centroid(footprint),
		"name": tags.get("name", ""),
		"water_type": tags.get("natural", tags.get("waterway", "")),
		"all_tags": tags
	}

## Calculate centroid of a polygon
func _calculate_centroid(points: Array) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO

	var sum_x = 0.0
	var sum_y = 0.0
	for point in points:
		sum_x += point.x
		sum_y += point.y

	return Vector2(sum_x / points.size(), sum_y / points.size())
