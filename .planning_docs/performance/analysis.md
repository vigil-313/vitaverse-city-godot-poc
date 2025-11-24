# Performance Analysis - Stuttering Issue

## 🎯 Objective
Identify and document the root causes of periodic stuttering in Vitaverse City.

---

## 📊 Problem Description

**Symptoms:**
- Periodic frame time spikes every ~1 second
- Stuttering occurs even with low chunk load radius
- Most noticeable during camera movement
- Consistent pattern, not random

**User Report:**
> "Even when I drop the config to load chunks at low radius, every few seconds there's a stutter laggy moment, not sure what's causing that"

---

## 🔍 Code Analysis

### Root Cause #1: Unbounded Distant Water Loading
**File:** `scripts/city/chunk_manager.gd:369-396`
**Function:** `_load_distant_water()`

**Problem:**
```gdscript
func _load_distant_water(camera_pos: Vector2, extended_radius: float):
    var distant_chunks = get_chunks_in_radius(camera_pos, extended_radius)

    for chunk_key in distant_chunks:
        if active_chunks.has(chunk_key):
            continue

        # PROBLEM: No limit on how many water bodies are created!
        var water_in_chunk = water_data_by_chunk.get(chunk_key, [])
        for water_data in water_in_chunk:
            # ... checks ...
            if area > 50000.0:  # Large water body
                var water_node = WaterGenerator.create_water(footprint, water_data, scene_root)
                # ↑ Synchronous mesh generation!
```

**Issues:**
1. No frame budget limit
2. Called every `chunk_update_interval` (1 second)
3. Lake Union (50,000+ m²) = thousands of vertices
4. All mesh generation happens synchronously
5. Can generate multiple large water bodies in one frame

**Impact:** 100-200ms frame spike when Lake Union loads

---

### Root Cause #2: Synchronous Chunk Loading
**File:** `scripts/city/chunk_manager.gd:110-151`
**Function:** `load_chunk()`

**Problem:**
```gdscript
func load_chunk(chunk_key: Vector2i):
    # Create chunk container
    var chunk_node = Node3D.new()
    scene_root.add_child(chunk_node)

    # Get features
    var buildings_in_chunk = building_data_by_chunk.get(chunk_key, [])
    var roads_in_chunk = road_data_by_chunk.get(chunk_key, [])
    # ...

    # PROBLEM: All created immediately, no frame budget
    feature_factory.create_buildings_for_chunk(buildings_in_chunk, chunk_node, buildings)
    feature_factory.create_roads_for_chunk(roads_in_chunk, chunk_node, roads)
    feature_factory.create_parks_for_chunk(parks_in_chunk, chunk_node)
    feature_factory.create_water_for_chunk(water_in_chunk, chunk_node)
    # ↑ All synchronous!
```

**Issues:**
1. Loads up to `max_chunks_per_frame` (2) chunks per update
2. Each chunk can have 10-50+ buildings
3. Each building creates multiple meshes (walls, windows, roof)
4. All mesh generation is synchronous
5. No consideration for total frame time

**Estimated costs per chunk:**
- Simple chunk (10 buildings): ~50-100ms
- Dense chunk (50 buildings): ~200-500ms
- 2 chunks simultaneously: potential 1000ms spike!

---

### Root Cause #3: Mesh Generation Complexity
**File:** `scripts/generators/building_generator_mesh.gd`
**Function:** `generate_building()`

**Analysis:**
Each building generates:
1. **Wall meshes** with embedded window geometry
2. **Roof mesh** (flat, gabled, hipped, or pyramidal)
3. **Material setup** for each mesh
4. **Node creation** and scene tree addition

**Vertex counts (estimated):**
- Simple building (10×10m, 2 floors): ~200-400 vertices
- Medium building (20×20m, 5 floors): ~800-1200 vertices
- Complex building (30×30m, 10 floors): ~1500-3000 vertices

**Per-building cost:**
- Simple: ~5-10ms
- Medium: ~15-25ms
- Complex: ~30-50ms

---

## 📈 Frame Time Analysis

### Current Behavior Timeline

```
Frame 0-59:   [Normal rendering] ~16ms per frame
Frame 60:     [Chunk update triggers]
              - Load 2 chunks (40 buildings total) = 500ms
              - Load distant water (Lake Union) = 150ms
              Total spike: 650ms!
Frame 61-119: [Normal rendering] ~16ms per frame
Frame 120:    [Chunk update triggers again]
              ...
```

**Result:** Every 60 frames (1 second), massive spike.

---

## 🎯 Baseline Metrics (To Be Measured)

Need to add profiling to measure:

### Overall Metrics
- [ ] Average frame time (normal)
- [ ] Frame time during chunk load
- [ ] Frequency of spikes
- [ ] Spike duration

### Chunk Loading Metrics
- [ ] Time to load 1 chunk (average)
- [ ] Time to load 2 chunks
- [ ] Building generation time per building
- [ ] Road generation time per road
- [ ] Park generation time per park
- [ ] Water generation time per water body

### Distant Water Metrics
- [ ] Time to generate Lake Union mesh
- [ ] Time to generate smaller water bodies
- [ ] Number of water bodies loaded per update

---

## 🔬 Profiling Plan

### Instrumentation Points

**1. ChunkManager.load_chunk()**
```gdscript
func load_chunk(chunk_key: Vector2i):
    var start_time = Time.get_ticks_usec()

    # ... existing code ...

    var elapsed = (Time.get_ticks_usec() - start_time) / 1000.0  # ms
    print("Chunk load took: ", elapsed, "ms for chunk ", chunk_key)
```

**2. ChunkManager._load_distant_water()**
```gdscript
func _load_distant_water(camera_pos: Vector2, extended_radius: float):
    var start_time = Time.get_ticks_usec()

    # ... existing code ...

    var elapsed = (Time.get_ticks_usec() - start_time) / 1000.0
    print("Distant water loading took: ", elapsed, "ms")
```

**3. Per-building timing** (in FeatureFactory or BuildingGenerator)
```gdscript
var building_times = []
for building_data in buildings_in_chunk:
    var start = Time.get_ticks_usec()
    # generate building
    var elapsed = (Time.get_ticks_usec() - start) / 1000.0
    building_times.append(elapsed)

print("Building generation: avg=", building_times.reduce(func(a, b): return a + b) / building_times.size(), "ms")
```

---

## 📊 Expected Results

Based on code analysis, we expect to find:

1. **Frame time spikes of 100-500ms** every ~1 second
2. **Distant water loading** accounts for 30-50% of spike
3. **Chunk loading** accounts for 50-70% of spike
4. **Complex buildings** take 3-5x longer than simple ones
5. **Lake Union** takes 100+ ms to generate

---

## ✅ Solution Validation

After implementing frame-budget queue:

**Expected improvements:**
- Frame time spikes reduced to <10ms
- Chunk loading spread over 5-10 frames
- No perceptible stuttering
- Smooth 60fps maintained

**Metrics to track:**
- Max frame time during loading
- Average frame time during loading
- Time to fully load a chunk (spread across frames)
- Loading queue depth

---

## 🔮 Future Performance Optimization Ideas

If frame-budget queue is insufficient:

1. **Threading**
   - Use WorkerThreadPool for mesh generation
   - Generate mesh data in thread
   - Add to scene on main thread

2. **LOD System**
   - Simple meshes for distant buildings
   - Detailed meshes only when close
   - Smooth transitions

3. **Mesh Instancing**
   - Identify repeated building shapes
   - Use MultiMeshInstance3D
   - Significant performance gain for similar buildings

4. **Async Resource Loading**
   - Load OSM data asynchronously
   - Stream chunks from disk
   - Reduce initial load time

5. **Simplified Geometry**
   - Reduce vertex count for windows
   - Simpler roof geometry
   - Balance visual quality vs performance

---

## 📝 Profiling Results

### Baseline (Before Optimization)
*To be filled in after profiling instrumentation*

- Average frame time: _____ ms
- Frame time during chunk load: _____ ms
- Chunk load frequency: _____ times per second
- Buildings per chunk: _____ (avg)
- Time per building: _____ ms (avg)
- Distant water load time: _____ ms
- Lake Union generation: _____ ms

### After Frame-Budget Queue
*To be filled in after implementation*

- Average frame time: _____ ms
- Max frame time during loading: _____ ms
- Chunk load spread: _____ frames
- Loading queue depth: _____ items (avg)
- Improvement: _____ % reduction in spikes

---

Last Updated: 2025-01-23
Status: Analysis complete, profiling pending
