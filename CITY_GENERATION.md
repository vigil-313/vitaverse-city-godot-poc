# Seattle City Generation System

A procedural building system that generates accurate 3D pixel art cities from OpenStreetMap data.

## 🏗️ Architecture

```
OSM Data → Template Selector → Building Generator → 3D Scene
   ↓              ↓                    ↓              ↓
footprints   building type         CSG geometry   pixel art
heights      Seattle style         windows/doors  textures
tags         era matching          props/details  cozy aesthetic
```

## 📦 Components

### 1. **BuildingTemplate** (`building_template.gd`)
Defines building appearance and characteristics:
- Dimensions, materials, colors
- Window/door styles
- Decorative elements (chimney, balcony, awning)
- Seattle-specific eras (Pioneer Square, Modern, Contemporary)

### 2. **Seattle Templates** (`seattle_templates.gd`)
Pre-made templates for Seattle buildings:
- **Landmarks**: Space Needle, Pike Place Market
- **Residential**: Craftsman houses, modern apartments
- **Commercial**: Office buildings, retail stores
- **Cafes**: Cozy Seattle coffee shops with outdoor seating

### 3. **BuildingGenerator** (`building_generator.gd`)
Generates 3D buildings from templates + OSM data:
- Creates walls, windows, doors, roofs
- Applies pixel art textures
- Adds decorative elements

### 4. **OSMParser** (`osm_parser.gd`)
Parses OpenStreetMap data:
- Converts lat/lon to game coordinates
- Extracts building footprints, heights, types
- Handles OSM tags (building type, amenity, shop)

### 5. **CityManager** (`city_manager.gd`)
Manages city generation:
- Loads OSM data
- Generates buildings
- Chunk-based streaming for large cities

## 🚀 Quick Start

### Step 1: Add CityManager to Your Scene

1. Open `scenes/main.tscn`
2. Add a new `Node3D` node
3. Attach `city_manager.gd` script
4. Set `Auto Generate On Ready` to true

### Step 2: Get OSM Data for Seattle

#### Option A: Download Pre-Made Area

1. Go to https://overpass-turbo.eu/
2. Paste this query for South Lake Union:

```
[bbox:47.620,-122.345,47.635,-122.330];
(
  way["building"];
  relation["building"];
);
out geom;
```

3. Click **Run**
4. Click **Export** → **Data** → **GeoJSON**
5. Save as `seattle_slu.json` in `res://data/`

#### Option B: Custom Area

1. Go to https://www.openstreetmap.org/
2. Navigate to your desired area in Seattle
3. Click **Export**
4. Select area (keep it small for testing!)
5. Download as `.osm` file
6. Convert to GeoJSON using https://tyrasd.github.io/osmtogeojson/

### Step 3: Generate City

```gdscript
# In your main scene or game manager
var city = CityManager.new()
city.osm_data_file = "res://data/seattle_slu.json"
add_child(city)
city.generate_city_from_osm()
```

## 🎨 Customization

### Create Custom Templates

```gdscript
# In seattle_templates.gd
static func create_my_building_template() -> BuildingTemplate:
    var template = BuildingTemplate.new()
    template.template_name = "My Building"
    template.default_width = 15.0
    template.default_depth = 12.0
    template.wall_material_type = "brick"
    template.wall_color = Color(0.7, 0.3, 0.2)
    template.has_awning = true
    # ... more customization
    return template
```

### Match Buildings by Name

```gdscript
# In seattle_templates.gd -> get_template_for_building()
if "starbucks" in name:
    return create_starbucks_template()
elif "amazon" in name:
    return create_amazon_building_template()
```

## 🗺️ Scaling to Full Seattle

### Phase 1: Downtown Core (Current)
- South Lake Union
- Pike Place Market
- Downtown shopping district
- ~500 buildings

### Phase 2: Neighborhoods
- Capitol Hill
- Fremont
- Ballard
- University District
- ~5,000 buildings

### Phase 3: Full City
- All Seattle neighborhoods
- ~100,000 buildings
- Requires chunk streaming

### Phase 4: Metro Area
- Bellevue, Redmond, Tacoma
- Puget Sound (water)
- ~500,000 buildings
- Requires LOD system

### Phase 5: State/Country
- Washington State
- Pacific Northwest
- Eventually: entire USA
- Millions of buildings
- Requires procedural generation + OSM data

## 🔧 Performance Optimization

### Chunk Streaming
```gdscript
# CityManager automatically loads/unloads chunks
city.chunk_size = 500.0  # 500m chunks
city.load_distance = 1000.0  # Load within 1km
```

### Level of Detail (LOD)
```gdscript
# TODO: Implement LOD system
# - Far buildings: simple boxes
# - Medium: basic geometry
# - Near: full detail
```

### Occlusion Culling
- Buildings behind other buildings aren't rendered
- Godot handles this automatically with proper collision

## 📊 OSM Data Structure

### Building Tags Used
- `building=*` - Building type (house, commercial, retail, etc.)
- `building:levels=*` - Number of floors
- `height=*` - Building height in meters
- `name=*` - Building name
- `amenity=*` - Purpose (cafe, restaurant, etc.)
- `shop=*` - Shop type (coffee, convenience, etc.)
- `addr:street=*` - Street address

### Seattle-Specific Landmarks
- Space Needle: `name="Space Needle"`
- Pike Place Market: `name="Pike Place Market"`
- Amazon Spheres: `name="Amazon Spheres"`
- More can be added to `seattle_templates.gd`

## 🎯 Accuracy Tips

### 1. Reference Photos
- Take photos of real Seattle buildings
- Match colors, styles, details
- Add to templates

### 2. Street View
- Use Google Street View for reference
- Note: window patterns, door styles, colors

### 3. Architectural Eras
Match Seattle's building history:
- **Pioneer Square** (1890s): Brick, ornate details
- **Early 1900s**: Craftsman houses, brick commercial
- **Mid-Century** (1950s-70s): Concrete, modernist
- **Contemporary** (2000s+): Glass, steel, mixed-use

### 4. Neighborhoods Have Styles
- Capitol Hill: Victorian, Craftsman
- South Lake Union: Modern glass towers
- Fremont: Eclectic, colorful
- Ballard: Scandinavian influence

## 🚦 Next Steps

1. ✅ **Building Template System** (Done!)
2. ✅ **OSM Parser** (Done!)
3. ⬜ **Test with real SLU data**
4. ⬜ **Add more Seattle templates**
5. ⬜ **Implement chunk streaming**
6. ⬜ **Add LOD system**
7. ⬜ **Generate streets/roads**
8. ⬜ **Add Lake Union (water)**
9. ⬜ **Add terrain (hills)**
10. ⬜ **Scale to full Seattle**

## 💡 Tips for Expansion

- Start small: 1 city block → 1 neighborhood → 1 city
- Test performance frequently
- Use chunking and LOD for large areas
- Keep pixel art style consistent
- Add variation to avoid repetition
- Reference real Seattle for authenticity

## 🆘 Troubleshooting

**No buildings generated?**
- Check OSM file exists at `res://data/seattle_slu.json`
- Verify JSON is valid
- Check console for errors

**Buildings look weird?**
- Adjust templates in `seattle_templates.gd`
- Check OSM data has height/levels tags
- Verify footprints are valid

**Performance issues?**
- Reduce load_distance
- Implement LOD system
- Use smaller OSM area

**Coordinates wrong?**
- Verify Seattle center in `osm_parser.gd` (47.6062° N, 122.3321° W)
- Check coordinate conversion math
