# Technical Decisions & Rationale

This document records all major technical decisions made during the project, with rationale and alternatives considered.

---

## 🎨 Visual Aesthetic Approach

### Decision: Hybrid Retro 3D (Option 5)
**Chosen:** Native low-res rendering + color palette quantization + dithering
**Date:** 2025-01-23
**Status:** ✅ Decided

**Rationale:**
- Works perfectly with procedural generation (no need for 2,700+ textures)
- Authentic PSX/Saturn era aesthetic
- Performance benefit from rendering fewer pixels
- Strong visual identity and cohesion
- Scales well to large city environments

**Alternatives Considered:**
1. **Post-processing pixelation** - Current approach, too simple, no performance gain
2. **Low-res viewport only** - Similar but less rich without palette/dithering
3. **Pixel art textures** - Doesn't scale to procedural generation
4. **Voxel style + palette** - Less detailed, simpler look
5. **Hybrid (chosen)** - Best of all approaches

**Implementation:**
- SubViewport rendering at low resolution
- Palette quantization shader
- Bayer matrix dithering
- Nearest-neighbor upscaling

---

## 📺 Base Resolution

### Decision: 480×360 (default, configurable)
**Date:** 2025-01-23
**Status:** ✅ Decided

**Rationale:**
- Strong retro feel without losing readability
- 7x fewer pixels than 1080p (performance boost)
- Buildings and roads remain recognizable
- Sweet spot for PSX/Saturn aesthetic
- 3:4 aspect ratio scales cleanly to 720p/1080p

**Alternatives Considered:**
- **320×240** - Too low, city details become unreadable
- **640×480** - Softer retro look, less pronounced effect
- **960×540** - Too subtle, defeats the purpose

**Configurability:**
Will support runtime presets: 240p, 360p, 480p, 540p for experimentation

---

## 🎨 Color Palette Size

### Decision: 64 colors (default, configurable)
**Date:** 2025-01-23
**Status:** ✅ Decided

**Rationale:**
- Authentic mid-90s console aesthetic (6-bit color)
- Enough variety for procedural buildings/materials
- Creates cohesive, stylized look
- Not too restrictive for varied content
- PSX/Saturn era accurate

**Alternatives Considered:**
- **32 colors** - Too restrictive, too stylized
- **256 colors** - Too flexible, loses retro constraint
- **No limit** - Defeats the purpose

**Configurability:**
Will support presets: 32, 64, 256, custom palettes

---

## ⚡ Performance Fix Approach

### Decision: Frame-Budget Queue System
**Chosen:** Frame-budget work queue (not threading)
**Date:** 2025-01-23
**Status:** ✅ Decided

**Rationale:**
- Simpler to implement and debug
- No thread safety concerns
- Fine-grained control over frame time
- GDScript-friendly (no threading complexity)
- Perfect for sporadic stutters (not constant load)
- Can add threading later if needed

**Alternatives Considered:**
1. **Threading/async** - Complex, harder to debug, overkill for this case
2. **Simplify meshes** - Doesn't solve root cause (unbounded work per frame)
3. **Increase chunk update interval** - Delays loading, doesn't solve stuttering

**Implementation:**
- Create LoadingQueue class
- Track work items with frame time budget
- Target: ≤5ms of loading work per frame
- Spread mesh generation across multiple frames
- Fix unbounded _load_distant_water() calls

**Frame Budget:**
- Target: 5ms per frame for loading work
- 60fps = 16.67ms per frame total
- Leaves 11.67ms for rendering, physics, etc.

---

## 🏗️ Architecture Approach

### Decision: Native Low-Res SubViewport
**Chosen:** SubViewport architecture (not post-processing)
**Date:** 2025-01-23
**Status:** ✅ Decided

**Rationale:**
- Actually renders fewer pixels (performance gain)
- More authentic retro look
- Clean separation of concerns
- Long-term benefits outweigh migration effort
- Enables other optimizations (shader complexity)

**Alternatives Considered:**
1. **Post-process downscale/upscale** - Simpler but no performance gain
2. **Render texture approach** - Similar complexity, less clean

**Architecture:**
```
CityRenderer (Node3D)
├── SubViewport (480×360, renders 3D scene)
│   ├── Camera3D
│   ├── DirectionalLight3D
│   ├── WorldEnvironment
│   └── Chunk_X_Y (all city chunks)
├── CanvasLayer (layer -1, upscaling display)
│   └── TextureRect (fullscreen)
│       ├── texture = SubViewport.get_texture()
│       └── ShaderMaterial (palette + dithering)
└── DebugUI (CanvasLayer, native resolution)
```

**Migration Impact:**
- Major: city_renderer.gd (_ready() refactor)
- Medium: camera_controller.gd (camera reference changes)
- Medium: chunk_manager.gd (scene_root reference)
- Minor: debug_ui.gd (ensure native res rendering)

---

## 🎮 Configurability Strategy

### Decision: Runtime-Adjustable Settings
**Date:** 2025-01-23
**Status:** ✅ Decided

**Rationale:**
- Allows experimentation without code changes
- User can find their preferred aesthetic
- Easy to A/B test different settings
- Debug UI provides immediate feedback

**Settings to Expose:**
- Resolution presets (240p, 360p, 480p, 540p)
- Palette presets (32, 64, 256, custom)
- Dithering intensity (0-100%)
- Optional: outline shader toggle

**Implementation:**
- Debug UI dropdown menus
- Apply changes instantly (no restart)
- Save preferences to config file

---

## 📁 Documentation Strategy

### Decision: .planning_docs/ Multi-Session System
**Date:** 2025-01-23
**Status:** ✅ Decided

**Rationale:**
- Work may span multiple sessions with fresh Claude contexts
- Need bootstrap procedure for new sessions
- Living documentation keeps everyone aligned
- Gitignored to keep repo clean

**Structure:**
- Bootstrap procedure (README.md)
- Progress tracker (PROGRESS.md)
- Decision log (this file)
- Detailed plans (plan/, performance/, visuals/)
- Session logs (sessions/)

**Maintenance:**
- Update PROGRESS.md frequently
- Create session log per session
- Document all changes
- Keep synchronized with code

---

## 🔮 Future Considerations

### Potential Future Enhancements
- **LOD system** - Different detail levels based on distance
- **Threading** - If frame-budget queue proves insufficient
- **Procedural textures** - Generate pixel art textures procedurally
- **Palette animation** - Day/night cycle via palette swaps
- **Advanced dithering** - Blue noise, error diffusion
- **Outline shader** - Optional edge detection for shapes
- **Dynamic resolution** - Adaptive resolution based on performance

### Deferred Decisions
- Exact dithering pattern (Bayer 4x4 vs 8x8)
- Whether to combine shaders or use multiple passes
- Custom palette format (JSON, image, embedded)
- Water rendering approach (affects palette)
- Shadow dithering vs solid shadows

---

## 📊 Success Criteria

### Performance
- ✅ No perceptible stuttering during camera movement
- ✅ Maintain 60fps consistently
- ✅ Smooth chunk loading/unloading

### Visual
- ✅ Authentic PSX/Saturn retro aesthetic
- ✅ Cohesive color palette across all elements
- ✅ Smooth gradients via dithering
- ✅ Readable buildings and streets
- ✅ Adjustable to user preference

### Code Quality
- ✅ Clean, maintainable architecture
- ✅ Well-documented changes
- ✅ Configurable without code changes
- ✅ Future-proof for enhancements

---

Last Updated: 2025-01-23
