# Phase 2: Hybrid Retro Aesthetic - Detailed Plan

## 🎯 Objective
Implement native low-resolution rendering with color palette quantization and dithering to achieve an authentic PSX/Saturn era aesthetic.

**Target:** Cohesive retro 3D look with runtime-configurable settings.

---

## 📊 Current State Analysis

### What Exists Now
**File:** `shaders/pixelate.gdshader`
```gdscript
shader_type canvas_item;
uniform int pixel_size = 3;

void fragment() {
    vec2 pixelated_uv = floor(uv * resolution / float(pixel_size)) * float(pixel_size) / resolution;
    COLOR = texture(screen_texture, pixelated_uv);
}
```

**Scene:** `scenes/pixelate_layer.tscn`
- CanvasLayer (layer 128)
- ColorRect with pixelation shader
- Fullscreen overlay

**Limitations:**
- Post-processing only (no performance gain)
- No color palette limiting
- No dithering
- Generic pixelated look

---

## 💡 Solution: Native Low-Res SubViewport

### Architecture Transformation

**Before:**
```
CityRenderer (Node3D)
├── Camera3D                    ← Renders at full resolution
├── DirectionalLight3D
├── WorldEnvironment
├── Chunk_X_Y nodes
└── [PixelateLayer overlay]
```

**After:**
```
CityRenderer (Node3D)
├── SubViewport (480×360)       ← Renders at LOW resolution
│   ├── Camera3D                ← Moved inside
│   ├── DirectionalLight3D      ← Moved inside
│   ├── WorldEnvironment        ← Moved inside
│   └── Chunk_X_Y nodes         ← Created inside
│
├── CanvasLayer (layer -1)      ← Display layer
│   └── TextureRect (fullscreen)
│       ├── texture = SubViewport.get_texture()
│       └── ShaderMaterial      ← Palette + dithering + upscale
│
└── DebugUI (CanvasLayer)       ← Native resolution, unaffected
```

**Key benefit:** Actually renders 7x fewer pixels (480×360 vs 1920×1080)

---

## 📝 Implementation Tasks

### Task 2.1: Design SubViewport Architecture
**Estimate:** 1 hour

**Create:** `visuals/native-lowres-architecture.md`

**Document:**
- Node hierarchy
- Reference flow (how components access camera, etc.)
- Coordinate systems
- Rendering pipeline
- Shader pipeline

**Key decisions:**
- SubViewport rendering mode (Always vs When Visible)
- Texture filtering (nearest-neighbor)
- Transparency handling
- Update mode (frame-by-frame)

---

### Task 2.2: Design Shader System
**Estimate:** 1 hour

**Create:** `visuals/shader-design.md`

**Design decisions:**

1. **Single shader vs multiple passes?**
   - Option A: Combined shader (upscale + palette + dither)
   - Option B: Separate shaders chained together
   - **Recommendation:** Combined (simpler, faster)

2. **Palette storage method?**
   - Option A: Uniform array
   - Option B: Texture lookup
   - Option C: Embedded in shader
   - **Recommendation:** Uniform array (easy to swap)

3. **Dithering algorithm?**
   - Bayer 4×4 matrix (subtle)
   - Bayer 8×8 matrix (more pronounced)
   - **Recommendation:** 8×8 (more retro)

**Shader structure:**
```gdscript
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform int palette_size = 64;
uniform vec3 palette[256];  // Color palette
uniform float dither_strength = 1.0;

// Bayer matrix
const float bayer8x8[64] = { ... };

vec3 quantize_to_palette(vec3 color) { ... }
float get_dither_threshold(vec2 screen_pos) { ... }

void fragment() {
    // 1. Sample from SubViewport
    // 2. Apply dithering
    // 3. Quantize to palette
    // 4. Output (nearest-neighbor upscaling automatic)
}
```

---

### Task 2.3: Research & Create Color Palettes
**Estimate:** 1-2 hours

**Create:** `visuals/palettes/` folder with presets

**Palettes to create:**

1. **PSX (64 colors)**
   - Research PSX color characteristics
   - Muted, slightly desaturated
   - Good variety across hues

2. **Saturn (64 colors)**
   - Slightly brighter than PSX
   - More saturated

3. **Limited (32 colors)**
   - Strong artistic constraint
   - High contrast

4. **Extended (256 colors)**
   - More flexibility
   - Subtle quantization

**Palette format:**
```gdscript
# palettes/psx_64.gd
const PALETTE = [
    Vector3(0.0, 0.0, 0.0),      # Black
    Vector3(0.1, 0.1, 0.15),     # Dark blue-gray
    Vector3(0.2, 0.15, 0.1),     # Dark brown
    # ... 61 more colors
]
```

**Sources:**
- Lospec.com palettes
- PSX game screenshots (analysis)
- Saturn game screenshots
- Manual curation

---

### Task 2.4: Implement Palette + Dithering Shader
**File:** `shaders/retro_3d.gdshader` (new)
**Estimate:** 2-3 hours

**Full shader implementation:**

```gdscript
shader_type canvas_item;

// SubViewport texture (low-res rendering)
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest, repeat_disable;

// Palette settings
uniform int palette_size : hint_range(2, 256) = 64;
uniform vec3 palette[256];

// Dithering settings
uniform float dither_strength : hint_range(0.0, 1.0) = 1.0;
uniform bool enable_dithering = true;

// Bayer 8x8 dithering matrix
const float bayer8x8[64] = float[](
     0.0/64.0, 32.0/64.0,  8.0/64.0, 40.0/64.0,  2.0/64.0, 34.0/64.0, 10.0/64.0, 42.0/64.0,
    48.0/64.0, 16.0/64.0, 56.0/64.0, 24.0/64.0, 50.0/64.0, 18.0/64.0, 58.0/64.0, 26.0/64.0,
    12.0/64.0, 44.0/64.0,  4.0/64.0, 36.0/64.0, 14.0/64.0, 46.0/64.0,  6.0/64.0, 38.0/64.0,
    60.0/64.0, 28.0/64.0, 52.0/64.0, 20.0/64.0, 62.0/64.0, 30.0/64.0, 54.0/64.0, 22.0/64.0,
     3.0/64.0, 35.0/64.0, 11.0/64.0, 43.0/64.0,  1.0/64.0, 33.0/64.0,  9.0/64.0, 41.0/64.0,
    51.0/64.0, 19.0/64.0, 59.0/64.0, 27.0/64.0, 49.0/64.0, 17.0/64.0, 57.0/64.0, 25.0/64.0,
    15.0/64.0, 47.0/64.0,  7.0/64.0, 39.0/64.0, 13.0/64.0, 45.0/64.0,  5.0/64.0, 37.0/64.0,
    63.0/64.0, 31.0/64.0, 55.0/64.0, 23.0/64.0, 61.0/64.0, 29.0/64.0, 53.0/64.0, 21.0/64.0
);

float get_bayer_threshold(vec2 screen_pos) {
    int x = int(mod(screen_pos.x, 8.0));
    int y = int(mod(screen_pos.y, 8.0));
    return bayer8x8[y * 8 + x];
}

vec3 find_closest_palette_color(vec3 color) {
    float min_dist = 999999.0;
    vec3 closest = palette[0];

    for (int i = 0; i < palette_size; i++) {
        float dist = distance(color, palette[i]);
        if (dist < min_dist) {
            min_dist = dist;
            closest = palette[i];
        }
    }

    return closest;
}

void fragment() {
    // Sample from low-res SubViewport
    vec4 color = texture(screen_texture, SCREEN_UV);

    // Apply dithering
    if (enable_dithering) {
        float threshold = get_bayer_threshold(FRAGCOORD.xy);
        vec3 dithered = color.rgb + (threshold - 0.5) * dither_strength * 0.1;
        color.rgb = clamp(dithered, 0.0, 1.0);
    }

    // Quantize to palette
    color.rgb = find_closest_palette_color(color.rgb);

    COLOR = color;
}
```

**Features:**
- Bayer matrix ordered dithering
- Palette quantization via distance check
- Configurable dithering strength
- Nearest-neighbor upscaling (automatic from texture filter)

---

### Task 2.5: Refactor CityRenderer - SubViewport Setup
**File:** `scripts/city_renderer.gd`
**Estimate:** 3-4 hours

**Major refactor of _ready() and _setup_environment():**

```gdscript
# New exports for configuration
@export_group("Retro Rendering")
@export var viewport_width: int = 480
@export var viewport_height: int = 360
@export var current_palette: String = "psx_64"

# New references
var sub_viewport: SubViewport
var display_layer: CanvasLayer
var display_rect: TextureRect

func _ready():
    print("🌆 CITY RENDERER - South Lake Union (Retro Mode)")
    print("============================================================")

    # 1. Create SubViewport first
    _setup_retro_viewport()

    # 2. Load OSM data (same as before)
    var osm_data = OSMDataComplete.new()
    # ...

    # 3. Initialize components (modified to use sub_viewport)
    _initialize_components(osm_data)

    # 4. Setup environment (inside SubViewport)
    _setup_environment()

    # 5. Load palette shader
    _setup_retro_shader()

    print("✅ Retro rendering enabled: ", viewport_width, "x", viewport_height)

func _setup_retro_viewport():
    # Create SubViewport
    sub_viewport = SubViewport.new()
    sub_viewport.size = Vector2i(viewport_width, viewport_height)
    sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    sub_viewport.transparent_bg = false
    add_child(sub_viewport)

    # Create display layer (renders SubViewport texture fullscreen)
    display_layer = CanvasLayer.new()
    display_layer.layer = -1  # Behind UI
    add_child(display_layer)

    # Create fullscreen rect
    display_rect = TextureRect.new()
    display_rect.texture = sub_viewport.get_texture()
    display_rect.stretch_mode = TextureRect.STRETCH_SCALE
    display_rect.anchors_preset = Control.PRESET_FULL_RECT
    display_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    display_layer.add_child(display_rect)

    print("   📺 SubViewport: ", viewport_width, "x", viewport_height)

func _initialize_components(osm_data: OSMDataComplete):
    # ... existing code, but with key change:

    # Camera controller creates camera INSIDE SubViewport
    camera_controller = CameraController.new()
    sub_viewport.add_child(camera_controller)  # Changed!

    var start_position = Vector3(-300, 100, -2000)
    camera_controller.setup_camera(sub_viewport, start_position)  # Changed!

    # Chunk manager uses SubViewport as scene_root
    chunk_manager = ChunkManager.new(feature_factory, sub_viewport)  # Changed!

func _setup_environment():
    # Create lights and environment INSIDE SubViewport
    var light = DirectionalLight3D.new()
    # ... setup light ...
    sub_viewport.add_child(light)  # Changed!

    var world_env = WorldEnvironment.new()
    # ... setup environment ...
    sub_viewport.add_child(world_env)  # Changed!

func _setup_retro_shader():
    # Load palette
    var palette_data = load("res://visuals/palettes/" + current_palette + ".gd")

    # Create shader material
    var shader = load("res://shaders/retro_3d.gdshader")
    var material = ShaderMaterial.new()
    material.shader = shader

    # Set palette uniform
    for i in range(palette_data.PALETTE.size()):
        material.set_shader_parameter("palette[" + str(i) + "]", palette_data.PALETTE[i])

    material.set_shader_parameter("palette_size", palette_data.PALETTE.size())
    material.set_shader_parameter("dither_strength", 1.0)
    material.set_shader_parameter("enable_dithering", true)

    # Apply to display rect
    display_rect.material = material

    print("   🎨 Palette: ", current_palette, " (", palette_data.PALETTE.size(), " colors)")
```

**Key changes:**
1. Create SubViewport before everything else
2. Create display layer to show SubViewport
3. Move Camera, Lights, Environment into SubViewport
4. Change chunk_manager scene_root to SubViewport
5. Apply shader to display rect

---

### Task 2.6: Update CameraController
**File:** `scripts/city/camera_controller.gd`
**Estimate:** 30 minutes

**Changes needed:**

Camera is now created inside SubViewport, but functionality stays the same:

```gdscript
func setup_camera(parent: Node, start_pos: Vector3):
    # parent is now SubViewport instead of CityRenderer
    # Everything else works the same
    camera = Camera3D.new()
    parent.add_child(camera)
    camera.global_position = start_pos
    # ... rest unchanged
```

**Test:**
- Camera movement still works
- Mouse capture still works
- Speed adjustments still work

---

### Task 2.7: Update ChunkManager Scene Root
**File:** `scripts/city/chunk_manager.gd`
**Estimate:** 15 minutes

**Change:**
```gdscript
func _init(p_feature_factory, p_scene_root: Node3D):
    # p_scene_root is now SubViewport instead of CityRenderer
    # All chunks created as children of SubViewport
    feature_factory = p_feature_factory
    scene_root = p_scene_root
```

No other changes needed - chunks just get created in SubViewport instead of root.

---

### Task 2.8: Fix DebugUI Native Resolution
**File:** `scripts/city/debug_ui.gd`
**Estimate:** 30 minutes

**Ensure DebugUI renders at native resolution:**

```gdscript
func setup(parent: Node, chunk_manager_ref):
    # DebugUI is added to CityRenderer (not SubViewport)
    # So it renders at native resolution
    # No changes needed, but verify it works
```

**Test:**
- Debug panel visible
- Text readable
- Chunk visualization works
- Stats update correctly

---

### Task 2.9: Add Retro Settings to Debug UI
**File:** `scripts/city/debug_ui.gd`
**Estimate:** 2 hours

**Add new panel for retro settings:**

```
╔════════════════════════════════════╗
║ RETRO RENDERING SETTINGS           ║
║                                    ║
║ Resolution:                        ║
║ ● 240p (320×240)                   ║
║ ○ 360p (480×360)  [Default]        ║
║ ○ 480p (640×480)                   ║
║ ○ 540p (960×540)                   ║
║                                    ║
║ Palette:                           ║
║ [ PSX 64 colors    ▼ ]             ║
║                                    ║
║ Dithering:                         ║
║ [ █████████░ 90%  ]                ║
║ [x] Enable dithering               ║
║                                    ║
║ [ Apply ] [ Reset ]                ║
╚════════════════════════════════════╝
```

**Features:**
- Resolution radio buttons
- Palette dropdown
- Dithering slider
- Apply button (updates shader + SubViewport)
- Reset to defaults

**Implementation:**
```gdscript
func _create_retro_panel():
    # Create panel with controls
    # Connect signals
    # Update city_renderer when changed

func _on_resolution_changed(resolution: String):
    # Update SubViewport size
    # Emit signal to city_renderer

func _on_palette_changed(palette_name: String):
    # Reload palette
    # Update shader uniforms

func _on_dithering_changed(value: float):
    # Update shader uniform
```

---

### Task 2.10: Create Resolution/Palette Presets
**Estimate:** 1 hour

**Create:** `scripts/retro_presets.gd`

```gdscript
extends Node
class_name RetroPresets

const RESOLUTIONS = {
    "240p": Vector2i(320, 240),
    "360p": Vector2i(480, 360),
    "480p": Vector2i(640, 480),
    "540p": Vector2i(960, 540)
}

const PALETTES = {
    "PSX 64": "psx_64",
    "Saturn 64": "saturn_64",
    "Limited 32": "limited_32",
    "Extended 256": "extended_256"
}

static func get_resolution_list() -> Array:
    return RESOLUTIONS.keys()

static func get_palette_list() -> Array:
    return PALETTES.keys()
```

---

### Task 2.11: Integration & Testing
**Estimate:** 2-3 hours

**Test scenarios:**

1. **Basic rendering**
   - Launch game
   - Verify SubViewport renders correctly
   - Verify upscaling works
   - Check no visual artifacts

2. **Shader effects**
   - Verify palette quantization working
   - Verify dithering visible
   - Test different palettes
   - Test dithering strength

3. **Resolution switching**
   - Try all resolution presets
   - Verify clean switching
   - Check performance at each resolution

4. **Camera/movement**
   - Verify camera controls work
   - Test fast movement
   - Verify chunk loading still works

5. **Debug UI**
   - Verify UI readable at native res
   - Test retro settings panel
   - Verify stats accurate

6. **Performance**
   - Measure FPS at different resolutions
   - Verify performance gain from low-res
   - Check shader performance cost

**Success criteria:**
- [ ] SubViewport renders correctly
- [ ] Palette quantization visible
- [ ] Dithering smooth and configurable
- [ ] All resolutions work
- [ ] All palettes work
- [ ] Camera/movement unchanged
- [ ] Debug UI functional
- [ ] Performance maintained/improved

---

### Task 2.12: Visual Tuning & Polish
**Estimate:** 2-3 hours

**Iterate on:**
- Palette color selection (tweak for best look)
- Dithering strength default
- Resolution default
- Shadow handling (dithered or solid?)
- Fog interaction with palette
- Bloom/glow compatibility

**Create comparison screenshots:**
- Before (current pixelation)
- After (retro rendering)
- Different palettes
- Different resolutions

**Document in:** `visuals/visual-comparison.md`

---

### Task 2.13: Documentation
**Estimate:** 1 hour

**Update:**
- `PROGRESS.md` - Mark Phase 2 complete
- `visuals/` - Add final architecture notes
- `code/files-to-modify.md` - Document all changes
- `sessions/` - Update session logs

**Create:**
- `visuals/user-guide.md` - How to use retro settings
- `visuals/shader-parameters.md` - Shader technical reference
- Screenshots in `visuals/references/`

---

## 📊 Files to Modify

### New Files
- `shaders/retro_3d.gdshader` - Main shader
- `visuals/palettes/psx_64.gd` - PSX palette
- `visuals/palettes/saturn_64.gd` - Saturn palette
- `visuals/palettes/limited_32.gd` - Limited palette
- `visuals/palettes/extended_256.gd` - Extended palette
- `scripts/retro_presets.gd` - Preset constants

### Modified Files
- `scripts/city_renderer.gd` - Major refactor (SubViewport)
- `scripts/city/camera_controller.gd` - Parent reference
- `scripts/city/chunk_manager.gd` - Scene root reference
- `scripts/city/debug_ui.gd` - Add retro settings panel

### Deprecated Files
- `shaders/pixelate.gdshader` - Replaced by retro_3d
- `scenes/pixelate_layer.tscn` - No longer used

---

## ⏱️ Estimated Timeline

| Task | Estimate | Cumulative |
|------|----------|------------|
| 2.1 Architecture Design | 1h | 1h |
| 2.2 Shader Design | 1h | 2h |
| 2.3 Palette Research | 1.5h | 3.5h |
| 2.4 Shader Implementation | 2.5h | 6h |
| 2.5 CityRenderer Refactor | 3.5h | 9.5h |
| 2.6 CameraController | 0.5h | 10h |
| 2.7 ChunkManager | 0.25h | 10.25h |
| 2.8 DebugUI Fix | 0.5h | 10.75h |
| 2.9 Retro Settings UI | 2h | 12.75h |
| 2.10 Presets | 1h | 13.75h |
| 2.11 Integration Testing | 2.5h | 16.25h |
| 2.12 Visual Tuning | 2.5h | 18.75h |
| 2.13 Documentation | 1h | 19.75h |

**Total: ~20 hours** (spread across 3-4 sessions)

---

## 🎯 Success Criteria

- [ ] SubViewport rendering functional
- [ ] Nearest-neighbor upscaling working
- [ ] Palette quantization visible and effective
- [ ] Dithering smooth and configurable
- [ ] 4+ resolution presets working
- [ ] 4+ palette presets working
- [ ] Runtime switching between settings
- [ ] Camera/movement unaffected
- [ ] Chunk loading unaffected
- [ ] Debug UI at native resolution
- [ ] Performance maintained or improved
- [ ] Cohesive retro aesthetic achieved

---

## 🔮 Future Visual Enhancements

- Outline/edge detection shader
- Blue noise dithering
- Custom palette editor
- Palette animation (day/night)
- Shadow dithering options
- Chromatic aberration (PSX wobble)
- Vertex jitter (PSX wobble)
- Affine texture mapping emulation
- CRT scanline overlay

---

Last Updated: 2025-01-23
