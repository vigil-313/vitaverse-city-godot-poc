extends RefCounted
class_name FeatureFactory

## Feature Factory
##
## Factory pattern for creating city features (buildings, roads, parks, water).
## Coordinates between ChunkManager and individual generators.
##
## Responsibilities:
##   - Create features for chunks using specialized generators
##   - Manage feature positioning and parenting
##   - Track created features for cleanup

# ========================================================================
# INITIALIZATION
# ========================================================================

func _init():
	pass  # No dependencies needed - all generators are static

# ========================================================================
# CHUNK FEATURE CREATION
# ========================================================================

## Create all buildings for a chunk
func create_buildings_for_chunk(buildings_data: Array, parent: Node3D, tracking_array: Array):
	for building_data in buildings_data:
		var center = building_data.get("center", Vector2.ZERO)
		var building = BuildingGeneratorMesh.create_building(building_data, parent, true)

		if building:
			building.position = Vector3(center.x, 0, -center.y)

			# Track for cleanup during chunk unload
			tracking_array.append({
				"node": building,
				"position": building.position
			})

## Create all roads for a chunk
func create_roads_for_chunk(roads_data: Array, parent: Node3D, tracking_array: Array):
	for road_data in roads_data:
		var path = road_data.get("path", [])
		if path.size() < 2:
			continue

		RoadGenerator.create_road(path, road_data, parent, tracking_array)

## Create all parks for a chunk
func create_parks_for_chunk(parks_data: Array, parent: Node3D):
	for park_data in parks_data:
		var footprint = park_data.get("footprint", [])
		if footprint.size() >= 3:
			ParkGenerator.create_park(footprint, park_data, parent)

## Create all water features for a chunk
func create_water_for_chunk(water_data_array: Array, parent: Node3D):
	for water_data in water_data_array:
		var footprint = water_data.get("footprint", [])
		if footprint.size() >= 3:
			WaterGenerator.create_water(footprint, water_data, parent)
