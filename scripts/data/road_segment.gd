extends RefCounted
class_name RoadSegment

## Road Segment - represents a road section between two intersections
## Part of the road network graph structure

## Unique identifier (from OSM way ID + segment index)
var segment_id: String = ""

## OSM way ID this segment came from
var way_id: int = 0

## Path points between intersections (Vector2 in game coordinates)
var path: Array[Vector2] = []

## Connections to intersections (null for dead ends/road terminations)
var start_intersection: RoadIntersection = null
var end_intersection: RoadIntersection = null

## Road properties from OSM
var highway_type: String = ""
var name: String = ""
var lanes: int = 0
var width: float = 0.0  # Explicit width from OSM, 0 = use default
var surface: String = ""
var layer: int = 0
var is_bridge: bool = false
var is_tunnel: bool = false
var is_oneway: bool = false

## Calculated properties
var calculated_width: float = 0.0  # Actual width to use for rendering
var length: float = 0.0

## All OSM tags for future reference
var all_tags: Dictionary = {}


## Initialize segment from road data dictionary
func init_from_road_data(road_data: Dictionary, start_idx: int, end_idx: int) -> void:
	way_id = road_data.get("id", 0)
	segment_id = "%d_%d_%d" % [way_id, start_idx, end_idx]

	# Extract path slice
	var full_path = road_data.get("path", [])
	path.clear()
	for i in range(start_idx, end_idx + 1):
		if i < full_path.size():
			path.append(full_path[i])

	# Copy road properties
	highway_type = road_data.get("highway_type", "")
	name = road_data.get("name", "")
	lanes = road_data.get("lanes", 0)
	width = road_data.get("width", 0.0)
	surface = road_data.get("surface", "")
	layer = road_data.get("layer", 0)
	is_bridge = road_data.get("bridge", false)
	is_tunnel = road_data.get("tunnel", false)
	is_oneway = road_data.get("oneway", false)
	all_tags = road_data.get("all_tags", {})

	# Calculate width from lane data or defaults
	calculated_width = _calculate_width()

	# Calculate length
	length = _calculate_length()


## Calculate road width from available data
func _calculate_width() -> float:
	# Priority 1: Explicit OSM width tag
	if width > 0:
		return width

	# Priority 2: Calculate from lanes (3.5m per lane standard US)
	if lanes > 0:
		var base_width = lanes * 3.5
		# Add parking lane width if present
		if all_tags.has("parking:lane:both") or all_tags.has("parking:lane:left") or all_tags.has("parking:lane:right"):
			var parking_lanes = 0
			if all_tags.has("parking:lane:both"):
				parking_lanes = 2
			else:
				if all_tags.has("parking:lane:left"):
					parking_lanes += 1
				if all_tags.has("parking:lane:right"):
					parking_lanes += 1
			base_width += parking_lanes * 2.4  # 2.4m parking lanes
		return base_width

	# Priority 3: Default by highway type
	return _get_default_width()


## Get default width for highway type
func _get_default_width() -> float:
	match highway_type:
		"motorway", "trunk":
			return 14.0  # 4 lanes
		"motorway_link", "trunk_link":
			return 7.0   # 2 lanes
		"primary":
			return 14.0  # 4 lanes
		"primary_link":
			return 7.0
		"secondary":
			return 10.5  # 3 lanes
		"secondary_link":
			return 7.0
		"tertiary":
			return 7.0   # 2 lanes
		"tertiary_link":
			return 5.0
		"residential", "unclassified":
			return 7.0   # 2 lanes
		"service":
			return 4.0   # 1 lane
		"living_street":
			return 5.0
		"pedestrian":
			return 4.0
		"footway", "path":
			return 2.0   # Pedestrian path
		"cycleway":
			return 2.0   # Bike path
		"steps":
			return 2.0
		_:
			return 7.0   # Default residential


## Calculate total path length
func _calculate_length() -> float:
	var total = 0.0
	for i in range(path.size() - 1):
		total += path[i].distance_to(path[i + 1])
	return total


## Get start position
func get_start_position() -> Vector2:
	if path.is_empty():
		return Vector2.ZERO
	return path[0]


## Get end position
func get_end_position() -> Vector2:
	if path.is_empty():
		return Vector2.ZERO
	return path[path.size() - 1]


## Get direction at start (outgoing from start intersection)
func get_start_direction() -> Vector2:
	if path.size() < 2:
		return Vector2.RIGHT
	return (path[1] - path[0]).normalized()


## Get direction at end (incoming to end intersection)
func get_end_direction() -> Vector2:
	if path.size() < 2:
		return Vector2.RIGHT
	return (path[path.size() - 1] - path[path.size() - 2]).normalized()


## Check if this is a driveable road (vs footway/cycleway)
func is_driveable() -> bool:
	return highway_type in ["motorway", "motorway_link", "trunk", "trunk_link",
							"primary", "primary_link", "secondary", "secondary_link",
							"tertiary", "tertiary_link", "residential", "unclassified",
							"service", "living_street"]


## Check if this is a pedestrian path
func is_pedestrian() -> bool:
	return highway_type in ["footway", "path", "pedestrian", "steps"]


## Check if this is a cycleway
func is_cycleway() -> bool:
	return highway_type == "cycleway"
