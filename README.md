# Vitaverse City - 3D Pixel Art City Renderer

A procedural 3D city renderer built with Godot 4.5.1, featuring dynamic chunk-based streaming of OpenStreetMap data for South Lake Union, Seattle.

![City Renderer](https://img.shields.io/badge/Godot-4.5.1-blue) ![OSM Data](https://img.shields.io/badge/OSM-South%20Lake%20Union-green)

## Features

- **Dynamic Chunk Streaming**: Load/unload city chunks based on camera position for smooth performance
- **OpenStreetMap Integration**: Real-world building, road, park, and water data
- **Procedural Building Generation**: Detailed buildings with windows, roofs, and realistic materials
- **Performance Optimized**:
  - Gradual chunk loading (2 chunks/sec)
  - Configurable load/unload radius (default: 1000m/1500m)
  - Large water bodies render at 2x distance
- **Runtime Configuration**:
  - F3 debug panel for chunk settings & movement speed
  - F4 chunk boundary visualization
  - FPS counter and performance HUD

## Quick Start

### Prerequisites
- Godot 4.5.1+
- Bash shell (for OSM data fetch)

### Setup

1. **Clone the repository**
   ```bash
   git clone git@github.com:vigil-313/vitaverse-city-godot-poc.git
   cd vitaverse-city-godot-poc
   ```

2. **Fetch OSM data** (required on first setup)
   ```bash
   cd scripts
   ./fetch_complete_osm.sh
   cd ..
   ```
   This downloads and processes OpenStreetMap data for South Lake Union (~431 MB).

3. **Open in Godot**
   - Launch Godot 4.5.1
   - Import the project
   - Open `scenes/city_renderer.tscn`
   - Press F5 to run

## Controls

| Key | Action |
|-----|--------|
| **Right-Click + Drag** | Look around |
| **WASD** | Move camera |
| **Q/E** | Move up/down |
| **Shift** | Fast movement |
| **Scroll Wheel** | Adjust speed |
| **F3** | Toggle debug panel (chunk settings & speed control) |
| **F4** | Toggle chunk visualization |
| **ESC** | Release mouse |

## Debug Panel (F3)

Adjust settings in real-time:
- **Speed Multiplier**: 0.1x - 10.0x (default: 1.0x)
- **Load Radius**: 100m - 5000m (default: 1000m)
- **Unload Radius**: 200m - 6000m (default: 1500m)

Click **Apply Changes** to update all settings.

## Project Structure

```
├── data/
│   └── osm_complete.json       # OSM data (generated, not in git)
├── scenes/
│   └── city_renderer.tscn      # Main city scene
├── scripts/
│   ├── city_renderer.gd        # Main renderer with chunk system
│   ├── building_generator_mesh.gd  # Procedural building generator
│   ├── osm_data_complete.gd    # OSM data parser
│   ├── polygon_triangulator.gd # Geometry utilities
│   └── fetch_complete_osm.sh   # OSM data fetch script
└── docs/
    ├── CHANGES_SUMMARY.md
    ├── OSM_DATA_ANALYSIS.md
    └── SCALE_TEST_INSTRUCTIONS.md
```

## Technical Details

### Chunk System
- **Chunk Size**: 500m × 500m
- **Load Radius**: 1000m (configurable)
- **Unload Radius**: 1500m (configurable)
- **Update Interval**: 1.0 second
- **Gradual Loading**: 2 chunks per update cycle

### OSM Dataset
- **Area**: South Lake Union, Seattle
- **Features**: ~2,700+ buildings, roads, parks, water bodies
- **Data Size**: 431 MB (generated locally, not in repository)
- **Scale**: 1 game unit = 1 meter

### Performance
- **Target FPS**: 60
- **Active Chunks**: ~12-16 (at default settings)
- **Loaded Buildings**: ~600-800
- **Memory**: Efficient chunk unloading prevents leaks

## Architecture

### Key Classes
- **CityRenderer**: Main orchestrator, chunk streaming logic
- **BuildingGeneratorMesh**: Procedural building mesh generation with windows, roofs
- **OSMDataComplete**: OpenStreetMap data parser and coordinate conversion
- **PolygonTriangulator**: Geometry triangulation for parks/water

### Rendering Flow
1. Load OSM data at startup
2. Organize all features into 500m chunks
3. Load initial chunks around camera spawn
4. Continuously stream chunks based on camera position
5. Unload distant chunks to free memory

## Known Limitations

- Chunk size changes require scene restart
- No LOD system yet (all buildings full detail)
- No async loading (may stutter on rapid movement)
- Water doesn't have reflections/waves

## Future Enhancements

- LOD system for distant buildings
- Use OSM building colors/materials (already parsed!)
- Enhanced water rendering with reflections
- Minimap with chunk grid
- Time of day system
- Pedestrians and vehicles

## License

MIT

## Credits

- OpenStreetMap contributors for real-world city data
- Built with Godot Engine 4.5.1
