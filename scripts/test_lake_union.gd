extends SceneTree

func _init():
	# Load OSM data
	var osm_data = OSMDataComplete.new()
	var success = osm_data.load_osm_data("res://data/osm_complete.json")
	
	if not success:
		print("Failed to load OSM data")
		quit()
		return
	
	# Find Lake Union
	for water in osm_data.water:
		var name = water.get("name", "")
		if "Lake Union" in name:
			print("=== LAKE UNION ===")
			print("Name: ", name)
			print("Footprint points: ", water.get("footprint", []).size())
			
			var footprint = water.get("footprint", [])
			if footprint.size() > 0:
				print("First 5 points:")
				for i in range(min(5, footprint.size())):
					print("  Point ", i, ": ", footprint[i])
				
				# Check for duplicate consecutive points
				var duplicates = 0
				for i in range(footprint.size() - 1):
					if footprint[i].distance_to(footprint[i + 1]) < 0.001:
						duplicates += 1
				print("Duplicate consecutive points: ", duplicates)
				
				# Test triangulation
				print("\nTesting triangulation...")
				var indices = PolygonTriangulator.triangulate(footprint)
				print("Triangle indices returned: ", indices.size())
				if indices.is_empty():
					print("❌ TRIANGULATION FAILED!")
				else:
					print("✅ Triangulation succeeded with ", indices.size() / 3, " triangles")
			
			break
	
	quit()
