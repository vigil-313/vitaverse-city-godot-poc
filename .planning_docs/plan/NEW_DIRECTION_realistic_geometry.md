# NEW DIRECTION: First-Person World Simulator with Realistic Geometry

**Date Created:** 2025-11-23
**Status:** Active - Major Pivot
**Priority:** Critical

---

## What Happened (The Pivot)

### Original Plan (Phases 1-2)
- Phase 0: Documentation ✅
- Phase 1: Performance optimization (LoadingQueue) ✅
- Phase 2: Retro PSX/Saturn aesthetic ❌ **WRONG DIRECTION**

### What We Learned
After implementing Phase 2 (flat/low-poly aesthetic):
- ❌ Flat unshaded materials made everything look like "origami"
- ❌ Paper-thin geometry has no volume
- ❌ Current approach optimized for distant viewing, NOT first-person
- ❌ Players will walk around in first-person - need REAL 3D detail

### Core Problem Identified
**Fundamental geometry is wrong for first-person gameplay:**
- Buildings: Hollow boxes (6 thin faces) - no wall thickness
- Windows: Painted rectangles - not recessed, no depth
- Walls: Single planes - paper-thin when viewed from edge
- Everything: Designed for viewing from 200m away, not 2m away

---

## New Vision: First-Person World Simulator

### Requirements
Players need to:
- ✅ Walk around in first-person
- ✅ See wall thickness and object volume
- ✅ Experience realistic 3D depth everywhere
- ✅ Interact with a believable world
- ✅ Do everyday things (requires realistic detail)

### What "Realistic Geometry" Means
1. **Walls with thickness** - solid volumes, not thin planes
2. **Recessed windows** - inset into walls with visible frames
3. **Architectural depth** - ledges, cornices that protrude
4. **Road curbs** - raised edges with geometry
5. **Close-up detail** - designed to be viewed from 2m away
6. **Proper interiors** - buildings aren't hollow shells

---

## The Plan: Geometry Rebuild (Multi-Phase)

### Phase 3A: Material Foundation (Quick - 1 hour)
**Goal:** Remove flat/unshaded look, restore proper lighting for depth

**Tasks:**
1. Revert UNSHADED materials to normal PBR shading
2. Keep vibrant colors but with proper lighting
3. Restore reflections/shadows for volume perception
4. Test first-person view with proper lighting

**Files to modify:**
- `scripts/generators/building_generator_mesh.gd` - restore shading
- `scripts/generators/road_generator.gd` - add subtle roughness
- `scripts/generators/park_generator.gd` - grass-like material
- `scripts/generators/water_generator.gd` - restore reflections

**Outcome:** Objects look 3D from lighting (not paper-flat)

---

### Phase 3B: Building Wall Thickness (Major - 8-12 hours)

**Current Problem:**
```
Building = 6 faces (hollow box)
  Top face
  Bottom face
  4 wall faces (each is a thin plane)
```

**New Approach:**
```
Building = Solid walls with thickness
  Each wall = 3D volume (not thin plane)
  Windows recessed into walls
  Visible wall edges/corners
```

**Implementation Options:**

#### Option 1: Double-Sided Walls (Medium complexity)
- Create inner and outer wall faces
- Connect them at edges
- Windows cut through both faces
- **Pros:** Relatively simple, good performance
- **Cons:** Still somewhat "shell-like"

#### Option 2: True Volumetric Walls (High complexity)
- Walls are actual 3D volumes (boxes)
- Windows are holes cut into volumes
- Frames are separate geometry
- **Pros:** Fully realistic, perfect for first-person
- **Cons:** More complex, more polygons

#### Option 3: Hybrid Approach (Recommended)
- Main walls: Double-sided with thickness
- Window areas: Volumetric frames
- Architectural details: Separate geometry
- **Pros:** Balanced realism/performance
- **Cons:** Medium complexity

**Files to modify:**
- `scripts/generators/building_generator_mesh.gd` - rebuild wall generation
- New helper functions for wall volumes
- Window generation with depth

**Sub-tasks:**
1. Create wall volume generation (2-3 hours)
2. Implement window recess system (2-3 hours)
3. Add window frames as geometry (1-2 hours)
4. Add architectural details (ledges, cornices) (2-3 hours)
5. Test and optimize (1-2 hours)

---

### Phase 3C: Window Detail (Major - 4-6 hours)

**Current:** Windows are painted blue rectangles

**New:** Windows with actual depth

**Implementation:**
1. **Window recess:**
   - Cut window opening into wall
   - Inset window glass 10-20cm into wall
   - Create reveal (wall edge around window)

2. **Window frames:**
   - Separate geometry for frames
   - Frame protrudes slightly from wall
   - Frame has thickness

3. **Window sills:**
   - Horizontal ledge below window
   - Protrudes from wall surface
   - Casts shadows

**Visual Impact:** HUGE - windows will look real from first-person

---

### Phase 3D: Architectural Detail (Medium - 3-4 hours)

**Add depth to buildings:**

1. **Cornices** (top of building)
   - Horizontal band that protrudes
   - Casts shadow on wall below
   - Adds visual interest

2. **Ledges between floors**
   - Horizontal bands at floor divisions
   - Slight protrusion
   - Creates visual rhythm

3. **Entrance canopies**
   - For some building types
   - Protrudes from facade
   - Casts shadow on ground

4. **Balconies** (optional)
   - For residential buildings
   - Simple box geometry
   - Adds realism

**Files to modify:**
- `scripts/generators/building_generator_mesh.gd` - add detail generation

---

### Phase 3E: Road Improvements (Medium - 2-3 hours)

**Current:** Roads are flat gray planes

**New:** Roads with curbs and detail

**Implementation:**
1. **Curbs:**
   - Raised edge along road sides
   - 10-15cm height
   - Creates visual boundary

2. **Sidewalks** (if needed):
   - Raised platform next to road
   - Different color/material
   - Creates pedestrian space

3. **Lane markings:**
   - Painted or slightly raised
   - White/yellow colors
   - Adds realism

4. **Slight elevation:**
   - Roads not perfectly flat
   - Subtle crown (higher in middle)
   - More realistic

**Files to modify:**
- `scripts/generators/road_generator.gd` - add curb generation

---

### Phase 3F: Performance Optimization (Important - 2-3 hours)

**Problem:** More geometry = worse performance

**Solutions:**

1. **Level of Detail (LOD):**
   - High detail geometry for nearby buildings
   - Simplified geometry for distant buildings
   - Switch based on distance from camera

2. **Occlusion Culling:**
   - Don't render buildings player can't see
   - Use Godot's built-in occlusion system

3. **Instancing:**
   - Reuse common elements (windows, frames)
   - Reduce memory usage

4. **Smart Loading:**
   - Keep Phase 1 LoadingQueue system
   - Load high-detail geometry gradually

---

## Success Criteria

### Immediate (Phase 3A - Materials):
- [ ] Objects have depth from lighting (not flat)
- [ ] Shadows show 3D volume
- [ ] First-person view looks better

### Short-term (Phase 3B-C - Walls & Windows):
- [ ] Walls have visible thickness
- [ ] Windows recessed into walls
- [ ] Window frames have geometry
- [ ] Buildings look solid, not hollow

### Medium-term (Phase 3D-E - Details):
- [ ] Architectural details add visual interest
- [ ] Roads have curbs and detail
- [ ] Everything designed for 2m viewing distance

### Long-term (Phase 3F - Performance):
- [ ] Maintain 60fps with detailed geometry
- [ ] LOD system working
- [ ] Chunk streaming still smooth

---

## Estimated Timeline

**Phase 3A (Materials):** 1 hour - **Start immediately**
**Phase 3B (Wall thickness):** 8-12 hours - Spread over 2-3 sessions
**Phase 3C (Window detail):** 4-6 hours - 1-2 sessions
**Phase 3D (Arch details):** 3-4 hours - 1 session
**Phase 3E (Roads):** 2-3 hours - 1 session
**Phase 3F (Performance):** 2-3 hours - 1 session

**Total:** ~25-35 hours across multiple sessions

---

## Priority Order

1. **Phase 3A first** - Quick win, immediate visual improvement
2. **Phase 3B next** - Most impactful (wall thickness)
3. **Phase 3C after** - Windows are very visible in first-person
4. **Phase 3D, 3E, 3F** - As time permits

---

## Notes

- This is a **fundamental rebuild**, not a surface fix
- Current flat/low-poly materials will be replaced
- Performance optimization critical (more geometry)
- Build incrementally - test after each phase
- Focus on buildings first (most visible)
- Roads/parks can wait until later phases

---

## References

- Previous phase 2 attempt: `.planning_docs/plan/phase-2-visuals.md` (abandoned)
- Current generators: `scripts/generators/*.gd`
- Performance system: Phase 1 LoadingQueue (keep this!)

---

**This is the path to a real first-person world simulator!** 🏗️
