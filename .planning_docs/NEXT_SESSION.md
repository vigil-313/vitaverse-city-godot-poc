# Next Session Quick Start

**Date Created:** 2025-01-23
**For:** Phase 2 - Hybrid Retro Aesthetic

---

## 🎯 Where We Left Off

### ✅ Completed
- **Phase 0:** Foundation & Documentation
- **Phase 1:** Performance Fix (LoadingQueue)
  - Stuttering completely eliminated
  - Smooth chunk loading at 5ms/frame
  - Performance mode added

### ⏭️ Next Up
**Phase 2:** Hybrid Retro Aesthetic
- Native low-res rendering (SubViewport 480×360)
- Palette quantization (64 colors)
- Bayer matrix dithering
- Runtime-configurable settings

---

## 📚 Required Reading

Before starting Phase 2, read these in order:

1. **`.planning_docs/README.md`** - Bootstrap procedure
2. **`.planning_docs/PROGRESS.md`** - Current status
3. **`.planning_docs/plan/phase-2-visuals.md`** - Detailed Phase 2 plan
4. **`.planning_docs/visuals/native-lowres-architecture.md`** - SubViewport design
5. **`.planning_docs/visuals/shader-design.md`** - Shader implementation
6. **`.planning_docs/DECISIONS.md`** - Why we made these choices

**Quick version (5 min):** Just read items 1, 2, and 3

---

## 🚀 Phase 2 Overview

### What We're Building

Transform the rendering pipeline from:
```
3D Scene → Render at 1920×1080 → Display
```

To:
```
3D Scene → SubViewport (480×360) → Palette Shader → Dithering → Upscale → Display
```

### Key Files to Modify

**Major refactor:**
- `scripts/city_renderer.gd` - Create SubViewport, move all 3D content inside

**Minor changes:**
- `scripts/city/camera_controller.gd` - Update camera parent reference
- `scripts/city/chunk_manager.gd` - Update scene_root reference
- `scripts/city/debug_ui.gd` - Ensure native res rendering

**New files:**
- `shaders/retro_3d.gdshader` - Palette + dithering shader
- `visuals/palettes/psx_64.gd` - PSX 64-color palette
- `visuals/palettes/saturn_64.gd` - Saturn palette
- `scripts/retro_presets.gd` - Resolution/palette constants

---

## 📋 Phase 2 Task Checklist

### Part 1: SubViewport Architecture (2-3 hours)
- [ ] Read architecture documentation
- [ ] Refactor city_renderer.gd _ready()
- [ ] Create SubViewport (480×360)
- [ ] Move Camera3D into SubViewport
- [ ] Move DirectionalLight3D into SubViewport
- [ ] Move WorldEnvironment into SubViewport
- [ ] Update chunk_manager scene_root reference
- [ ] Create upscaling display (CanvasLayer + TextureRect)
- [ ] Test basic rendering works

### Part 2: Shaders (1-2 hours)
- [ ] Research/create color palettes
- [ ] Implement retro_3d.gdshader
- [ ] Add Bayer 8×8 dithering matrix
- [ ] Implement palette quantization
- [ ] Test shader with different palettes

### Part 3: Integration (1 hour)
- [ ] Fix camera_controller.gd references
- [ ] Fix debug_ui.gd rendering
- [ ] Add resolution presets
- [ ] Add palette presets
- [ ] Test resolution switching
- [ ] Test palette switching

### Part 4: Polish (1 hour)
- [ ] Add debug UI controls
- [ ] Tune dithering strength
- [ ] Test performance (should be 60fps!)
- [ ] Visual comparison screenshots
- [ ] Document results

---

## 🎨 Visual Settings We're Implementing

### Resolution Presets
- 240p (320×240) - Extreme retro
- 360p (480×360) - **Default** - Sweet spot
- 480p (640×480) - Softer retro
- 540p (960×540) - Subtle effect

### Palette Presets
- PSX (64 colors) - **Default** - Muted, warm tones
- Saturn (64 colors) - Brighter, more saturated
- Limited (32 colors) - Strong constraint
- Extended (256 colors) - More flexibility

### Configurable Parameters
- Dithering strength (0.0 - 2.0)
- Dithering enable/disable
- Bayer matrix size (4×4 or 8×8)
- Debug palette view

---

## ⚠️ Potential Issues to Watch For

### 1. Reference Errors
**Problem:** Components expecting CityRenderer as parent
**Solution:** Update all references to use SubViewport

### 2. Mouse Coordinates
**Problem:** Mouse picking may need coordinate conversion
**Solution:** Scale mouse coords from window to SubViewport

### 3. UI Rendering
**Problem:** Debug UI might render at low-res
**Solution:** Keep DebugUI outside SubViewport

### 4. Performance
**Problem:** Shader might be slower than expected
**Solution:** Profile, optimize palette lookup if needed

---

## 🧪 Testing Strategy

### Basic Tests
1. Launch game - verify rendering works
2. Move camera - verify no crashes
3. Load chunks - verify loading still works
4. Check debug UI - verify readable

### Visual Tests
1. Gradients - verify dithering smooth
2. Different palettes - verify all work
3. Different resolutions - verify all work
4. Color variety - verify palette coverage

### Performance Tests
1. Measure FPS - should be 60+ now
2. Dense areas - verify maintains 60fps
3. Rapid movement - verify smooth

---

## 💡 Quick Tips

### If Stuck on SubViewport
- Start small: Get basic SubViewport rendering first
- Then add shaders
- Keep original pixelate.gdshader as reference

### If Shader Not Working
- Test with simple shader first (just pass through color)
- Add palette quantization
- Then add dithering
- Debug one feature at a time

### If Performance Still Low
- Check SubViewport size is actually 480×360
- Verify texture_filter = NEAREST
- Profile to find bottleneck
- May need to reduce chunk load radius further

---

## 📊 Success Criteria

At the end of Phase 2, you should have:
- ✅ Game renders at 480×360 internally
- ✅ Upscales to window with nearest-neighbor
- ✅ Palette quantization visible
- ✅ Dithering smooth and configurable
- ✅ 60fps or better performance
- ✅ Runtime switchable settings
- ✅ Authentic retro aesthetic

---

## 🚨 Emergency Rollback

If Phase 2 breaks things badly:

```bash
# Revert city_renderer.gd
git checkout HEAD -- scripts/city_renderer.gd

# Revert other changes
git checkout HEAD -- scripts/city/camera_controller.gd
git checkout HEAD -- scripts/city/chunk_manager.gd
```

Or create a git branch before starting:
```bash
git checkout -b phase-2-visuals
# Work happens here
# If good: git merge
# If bad: git checkout main
```

---

## 📞 Need Help?

Reference these docs:
- Architecture questions → `visuals/native-lowres-architecture.md`
- Shader questions → `visuals/shader-design.md`
- What to modify → `code/files-to-modify.md`
- Overall plan → `plan/phase-2-visuals.md`

---

## 🎯 First Steps When You Start

1. **Read** this file
2. **Read** `.planning_docs/plan/phase-2-visuals.md`
3. **Create** a new session log: `sessions/2025-XX-XX-session-002.md`
4. **Update** PROGRESS.md (mark Phase 2 as "in progress")
5. **Begin** with Task 2.1 (SubViewport architecture design review)

---

**Ready to make it look retro! 🎮✨**

Last Updated: 2025-01-23
Estimated Time: 5-7 hours total
Expected Outcome: Smooth 60fps retro aesthetic
