# OSM Data Analysis - Seattle South Lake Union

## Data Overview
- **Total Elements**: 2,742 (all "way" type)
- **Buildings**: ~400
- **Roads/Paths**: ~2,340

## Critical Issues Identified

### Issue 1: Rendering ALL paths as roads
**Current Problem**: We render 1,619 footways (sidewalks) as full roads
- Footways: 1,619 (59% of all paths!)
- Service roads: 271
- Actual driveable roads: ~450

**Solution**: Only render driveable roads (primary, secondary, tertiary, residential, motorway)
- Don't render footways, steps, pedestrian paths as roads
- These are sidewalks and should be part of building setbacks

### Issue 2: Not using lane data
**Current Problem**: Using fixed widths per road type
**Available Data**: OSM has `lanes` tag
- Primary roads: 3-4 lanes
- Secondary: 3-4 lanes
- Residential: 2 lanes

**Solution**: Calculate width = (lanes × 3.5m) + sidewalk_buffer
- Standard lane: 3.5m wide
- Add 1-2m per side for sidewalks

### Issue 3: Building collision blocking movement
**Current Problem**: Buildings have collision enabled
**Solution**: Disable collision on buildings entirely

### Issue 4: Too many buildings rendering
**Current Problem**: Rendering all 400 buildings at once
**Solution**: Implement proper LOD with distance culling

## OSM Data Structure

### Buildings (400 total)
Types:
- yes: 193 (generic)
- apartments: 66
- office: 36
- house: 27
- commercial: 16

**Available Tags**:
- `building:levels` - number of floors
- `height` - height in meters (rare)
- `building:part` - building part vs whole building
- `building:min_level` - elevated sections
- `layer` - vertical stacking
- `name` - building name

**Height Calculation**:
- If `height` tag exists: use it
- Else: `building:levels` × 3m per floor
- Default: 2 floors = 6m

### Roads (2,340 total)
Types (driveable only):
- primary: 29 (like Mercer)
- secondary: 121
- tertiary: 14
- residential: 61
- motorway: 16
- motorway_link: 29

Non-driveable (don't render as roads):
- footway: 1,619 (sidewalks!)
- service: 271 (parking lots, alleys - render smaller)
- steps: 65
- cycleway: 62

**Available Tags**:
- `lanes` - number of lanes (use this!)
- `highway` - road type
- `name` - street name
- `layer` - elevation (bridges)
- `bridge` - is it a bridge?

## Proposed Rendering Strategy

### 1. Scale (1 game unit = 1 meter)
- ✅ Player: 1.7m tall
- ✅ Building heights: From OSM data (levels × 3m)
- ✅ Road widths: From lanes data (lanes × 3.5m + 2m sidewalks)

### 2. What to Render
**RENDER**:
- Primary/secondary/tertiary/residential roads
- Motorways and links
- All buildings (with LOD)
- Parks and water

**DON'T RENDER** (or render differently):
- Footways (these are sidewalks, part of road buffer)
- Steps
- Pedestrian-only paths

### 3. Collision Strategy
**WITH COLLISION**:
- Ground plane
- Roads (so player stays on surface)
- Water (as static decorative)

**NO COLLISION**:
- Buildings (player should walk through if needed)
- Parks
- Labels

### 4. Building Generation
**Simple Buildings** (>100m from player):
- Use actual OSM footprint polygon
- Scale: 95% of footprint (5% setback)
- Height: From OSM levels/height
- No windows, flat color

**Detailed Buildings** (<100m from player):
- Same footprint as simple
- Add windows based on levels
- Add door at ground level
- Textured walls

## Next Steps

1. **Fix road rendering** - Use lanes data, only render driveable roads
2. **Remove all collision from buildings**
3. **Use footprint polygons correctly** - No bounding box fallback
4. **Test with one intersection** - Get Mercer & Westlake perfect first
5. **Scale validation** - Measure against real-world reference
