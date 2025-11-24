# Files to Modify - Complete List

This document tracks all files that will be modified or created during the project.

---

## 📋 Phase 1: Performance Fix

### New Files Created

| File | Purpose | Status |
|------|---------|--------|
| `scripts/city/loading_queue.gd` | Frame-budget work queue class | ⏸️ Not started |

### Files to Modify

| File | Lines | Changes | Impact | Status |
|------|-------|---------|--------|--------|
| `scripts/city/chunk_manager.gd` | ~405 | Add LoadingQueue, refactor loading | Major | ⏸️ Not started |
| `scripts/generators/feature_factory.gd` | TBD | Return work items instead of immediate creation | Medium | ⏸️ Not started |
| `scripts/city_renderer.gd` | ~330 | Integration, profiling | Minor | ⏸️ Not started |
| `scripts/city/debug_ui.gd` | TBD | Add loading queue stats display | Minor | ⏸️ Not started |

### Temporary Profiling Code

| File | Purpose | Status |
|------|---------|--------|
| `scripts/city/chunk_manager.gd` | Add timing instrumentation | ✅ Next task |

---

## 📋 Phase 2: Visual Aesthetic

### New Files Created

| File | Purpose | Status |
|------|---------|--------|
| `shaders/retro_3d.gdshader` | Main retro shader (palette + dithering) | ⏸️ Not started |
| `visuals/palettes/psx_64.gd` | PSX 64-color palette | ⏸️ Not started |
| `visuals/palettes/saturn_64.gd` | Saturn 64-color palette | ⏸️ Not started |
| `visuals/palettes/limited_32.gd` | Limited 32-color palette | ⏸️ Not started |
| `visuals/palettes/extended_256.gd` | Extended 256-color palette | ⏸️ Not started |
| `scripts/retro_presets.gd` | Resolution and palette preset constants | ⏸️ Not started |

### Files to Modify

| File | Lines | Changes | Impact | Status |
|------|-------|---------|--------|--------|
| `scripts/city_renderer.gd` | ~330 | Complete refactor - SubViewport architecture | **Major** | ⏸️ Not started |
| `scripts/city/camera_controller.gd` | TBD | Update camera parent reference | Minor | ⏸️ Not started |
| `scripts/city/chunk_manager.gd` | ~405 | Update scene_root reference | Minor | ⏸️ Not started |
| `scripts/city/debug_ui.gd` | TBD | Add retro settings panel | Medium | ⏸️ Not started |

### Files to Deprecate/Remove

| File | Reason | Action | Status |
|------|--------|--------|--------|
| `shaders/pixelate.gdshader` | Replaced by retro_3d.gdshader | Keep for reference, don't delete | ⏸️ Not started |
| `scenes/pixelate_layer.tscn` | No longer used | Keep for reference, don't delete | ⏸️ Not started |

---

## 📊 Detailed Change Breakdown

### scripts/city/chunk_manager.gd

**Current:** 405 lines
**Expected after Phase 1:** ~500 lines
**Expected after Phase 2:** ~505 lines

**Phase 1 Changes:**
- Add LoadingQueue instance
- Add chunk_states Dictionary (unloaded/loading/loaded)
- Modify `load_chunk()` to queue work items
- Modify `unload_chunk()` to handle loading state
- Modify `_update_streaming()` to respect states
- Change `_load_distant_water()` to `_queue_distant_water()`
- Add `update()` call to `loading_queue.process()`
- Add signal handlers for work completion
- Add helper methods for work item creation

**Phase 2 Changes:**
- Update `scene_root` reference (CityRenderer → SubViewport)
- No logic changes, just reference update

**Risk Level:** High (Phase 1), Low (Phase 2)

---

### scripts/generators/feature_factory.gd

**Current:** TBD (need to read file)
**Expected after Phase 1:** +50-100 lines

**Phase 1 Changes:**
- Add `create_building_work_items()` method
- Add `create_road_work_items()` method
- Add `create_park_work_items()` method
- Add `create_water_work_items()` method
- Keep existing immediate creation methods (for backward compat)

**Phase 2 Changes:**
- None

**Risk Level:** Medium

---

### scripts/city_renderer.gd

**Current:** 330 lines
**Expected after Phase 1:** ~340 lines (profiling)
**Expected after Phase 2:** ~450 lines (SubViewport)

**Phase 1 Changes:**
- Add profiling instrumentation (temporary)
- Update `_process()` to show loading stats
- Minor debug output

**Phase 2 Changes (MAJOR REFACTOR):**
- Add `@export` for viewport size, palette
- Add SubViewport, CanvasLayer, TextureRect creation
- Move `_setup_environment()` to create inside SubViewport
- Refactor `_initialize_components()` to use SubViewport
- Add `_setup_retro_viewport()` method
- Add `_setup_retro_shader()` method
- Update all child creation to use SubViewport

**Risk Level:** Low (Phase 1), **Very High (Phase 2)**

---

### scripts/city/camera_controller.gd

**Current:** TBD
**Expected after Phase 2:** +0 lines (reference change only)

**Phase 1 Changes:**
- None

**Phase 2 Changes:**
- Update `setup_camera()` parent parameter
- Parent changes from CityRenderer to SubViewport
- No logic changes

**Risk Level:** Low

---

### scripts/city/debug_ui.gd

**Current:** TBD
**Expected after Phase 1:** +50 lines
**Expected after Phase 2:** +200 lines

**Phase 1 Changes:**
- Add loading queue stats display
- Show work items remaining
- Show loading progress bar

**Phase 2 Changes:**
- Add retro settings panel
- Resolution preset controls
- Palette preset dropdown
- Dithering controls
- Apply/Reset buttons
- Signal connections to city_renderer

**Risk Level:** Medium

---

### scripts/city/loading_queue.gd (NEW)

**Lines:** ~300 lines
**Purpose:** Frame-budget work queue

**Contents:**
- LoadingQueue class definition
- Signal definitions
- Work item queue management
- Frame budget processing
- Priority sorting
- Chunk progress tracking
- Statistics

**Risk Level:** Medium (new code, needs testing)

---

### shaders/retro_3d.gdshader (NEW)

**Lines:** ~200 lines
**Purpose:** Palette quantization + dithering shader

**Contents:**
- Uniforms (palette, settings)
- Bayer matrices (4×4, 8×8)
- Helper functions
- Fragment shader

**Risk Level:** Medium (shader debugging can be tricky)

---

### visuals/palettes/*.gd (NEW)

**Files:** 4 palette files
**Lines:** ~70 lines each
**Purpose:** Color palette data

**Contents:**
- Resource class
- Const array of Vector3 colors

**Risk Level:** Low (just data)

---

### scripts/retro_presets.gd (NEW)

**Lines:** ~30 lines
**Purpose:** Preset constants

**Contents:**
- Resolution presets dictionary
- Palette presets dictionary
- Helper methods

**Risk Level:** Low (just constants)

---

## 📂 Folder Structure Changes

### New Folders Created

```
visuals/
└── palettes/
    ├── psx_64.gd
    ├── saturn_64.gd
    ├── limited_32.gd
    └── extended_256.gd
```

---

## 🧪 Testing Impact

### Phase 1: Files Requiring Testing

1. **scripts/city/loading_queue.gd**
   - Unit test work queue
   - Test frame budget
   - Test priority sorting

2. **scripts/city/chunk_manager.gd**
   - Integration test with LoadingQueue
   - Test chunk loading/unloading
   - Test distant water queueing

3. **scripts/generators/feature_factory.gd**
   - Test work item creation
   - Verify backward compatibility

4. **Integration**
   - Full game test
   - Performance profiling
   - Stress test (rapid movement)

### Phase 2: Files Requiring Testing

1. **scripts/city_renderer.gd**
   - SubViewport creation
   - Component migration
   - Rendering pipeline

2. **shaders/retro_3d.gdshader**
   - Visual quality
   - Performance
   - Parameter tuning

3. **scripts/city/debug_ui.gd**
   - UI controls
   - Signal connections
   - Runtime changes

4. **Integration**
   - Full visual pipeline
   - Resolution switching
   - Palette switching

---

## 📝 Code Review Checklist

### Before Committing

- [ ] All modified files documented here
- [ ] All new files added to version control
- [ ] No debug print statements left in
- [ ] No commented-out code blocks
- [ ] All functions documented
- [ ] No magic numbers (use constants)
- [ ] Error handling added
- [ ] Null safety checks added

### After Each Phase

- [ ] All tests passing
- [ ] Performance metrics documented
- [ ] Visual comparison screenshots taken
- [ ] User-facing changes documented
- [ ] PROGRESS.md updated
- [ ] Session log updated

---

## 🔮 Rollback Plan

### Phase 1 Rollback

If frame-budget queue causes issues:

1. Keep LoadingQueue class (may be useful later)
2. Revert chunk_manager.gd changes
3. Revert feature_factory.gd changes
4. Remove loading queue integration

**Estimated rollback time:** 30 minutes

### Phase 2 Rollback

If SubViewport architecture causes issues:

1. Revert city_renderer.gd to backup
2. Revert camera_controller.gd changes
3. Revert chunk_manager.gd scene_root changes
4. Restore pixelate_layer.tscn usage

**Estimated rollback time:** 1 hour

**Mitigation:** Create git branch before Phase 2, test thoroughly before merging.

---

Last Updated: 2025-01-23
Status: Documented, ready for implementation
