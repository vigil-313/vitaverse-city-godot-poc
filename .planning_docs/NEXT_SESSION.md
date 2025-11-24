# Next Session Quick Start

**Last Updated:** 2025-11-23 (Session #002)
**Current Phase:** Phase 3 - Realistic Geometry for First-Person

---

## 🚨 IMPORTANT: Major Direction Change!

**We pivoted!** Phase 2 (retro flat/low-poly) was ABANDONED.

**Why?** Game is a **first-person world simulator** where players walk around.
- Current graphics look like "origami" - paper-thin with no volume
- Flat/unshaded materials remove all depth
- Simple box geometry has no wall thickness
- Everything optimized for viewing from 200m away, NOT 2m away

**New Goal:** Realistic geometry with actual 3D volume and detail.

---

## 📋 Session #003 Priorities

### Immediate Task: Phase 3A (1 hour)
**Restore Proper Lighting & Shading**

Current problem: All materials are UNSHADED (flat colors, no lighting)
- Buildings, roads, parks, water all use `SHADING_MODE_UNSHADED`
- This makes everything look paper-flat
- No depth perception from shadows/lighting

**What to do:**
1. Remove `SHADING_MODE_UNSHADED` from all material creation
2. Restore PBR shading (StandardMaterial3D default)
3. Keep vibrant colors but with proper lighting
4. Re-enable reflections on water/windows
5. Test in first-person view

**Files to modify:**
- `scripts/generators/building_generator_mesh.gd` - 4 functions
- `scripts/generators/road_generator.gd` - 1 function
- `scripts/generators/park_generator.gd` - 1 inline material
- `scripts/generators/water_generator.gd` - 2 locations

**Expected result:** Objects have depth from lighting, not flat anymore

---

## 🎯 Next Priority: Phase 3B (8-12 hours, multiple sessions)
**Implement Building Wall Thickness**

This is THE most important change for first-person feel.

**Current state:**
```
Building = hollow box with 6 thin faces
  If you look at wall edge: paper-thin (no thickness)
```

**Target state:**
```
Building = solid walls with actual volume
  Walls have thickness (15-30cm)
  Windows recessed into walls
  Visible wall edges/corners
```

**Approach (Hybrid):**
- Main walls: Double-sided with thickness
- Window areas: Volumetric frames with depth
- Architectural details: Separate geometry

**Implementation steps (spread over multiple sessions):**
1. Create wall volume generation system
2. Implement window recess/depth
3. Add window frames as 3D geometry
4. Add ledges/cornices
5. Test and optimize

---

## 📚 Key Documents

**Read these before starting:**
1. `.planning_docs/plan/NEW_DIRECTION_realistic_geometry.md` - Full plan
2. `.planning_docs/PROGRESS.md` - What happened in Phase 2
3. This file - Quick start guide

**Current generators (what you'll modify):**
- `scripts/generators/building_generator_mesh.gd` - Buildings
- `scripts/generators/road_generator.gd` - Roads
- `scripts/generators/park_generator.gd` - Parks
- `scripts/generators/water_generator.gd` - Water

---

## 🔧 Current State of Code

### What's Working (Keep!)
- ✅ Phase 1 LoadingQueue (performance system) - **Don't touch this!**
- ✅ Chunk streaming (smooth, no stuttering)
- ✅ MSAA 4x anti-aliasing enabled
- ✅ Native resolution rendering (SubViewport removed)

### What's Broken (Needs fixing)
- ❌ All materials are UNSHADED (looks flat/paper-like)
- ❌ Buildings are thin boxes (no wall thickness)
- ❌ Windows are painted rectangles (no depth)
- ❌ No architectural detail for close viewing
- ❌ Roads are flat planes (no curbs)

### Recent Changes (Session #002)
- Tried flat/low-poly aesthetic (wrong direction)
- All materials changed to UNSHADED
- Colors changed to vibrant pastels
- SubViewport architecture added then removed
- Result: "Origami city" - not suitable for first-person

---

## 🎮 Testing Checklist

After Phase 3A (shading fix):
- [ ] Load game and walk around in first-person
- [ ] Do objects have depth from lighting?
- [ ] Are shadows helping show 3D volume?
- [ ] Is it better than flat/unshaded look?

After Phase 3B (wall thickness):
- [ ] Walk up close to buildings
- [ ] Can you see wall thickness at edges?
- [ ] Do windows look recessed?
- [ ] Does it feel like real 3D architecture?

---

## 💡 Remember

**Goal:** First-person world simulator
- Players walk around at 2m viewing distance
- Need real 3D volume (wall thickness visible)
- Need architectural detail (not distant-view optimization)
- Performance still important (keep LoadingQueue!)

**Not the goal:** Distant city view, artistic minimalism, retro aesthetic

---

## ⚡ Quick Commands

Start development server:
```bash
godot --path . scenes/city_renderer.tscn
```

Run tests:
```bash
# No automated tests yet - manual testing in-game
```

---

**Let's build a real first-person world!** 🏗️
