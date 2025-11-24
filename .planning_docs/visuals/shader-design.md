# Shader Design - Palette Quantization & Dithering

## 🎯 Objective
Design the retro shader that transforms low-res 3D rendering into authentic PSX/Saturn aesthetic through palette quantization and dithering.

---

## 🎨 Shader Overview

**Name:** `retro_3d.gdshader`
**Type:** canvas_item (2D shader for TextureRect)
**Input:** SubViewport texture (480×360)
**Output:** Palette-quantized, dithered image

**Processing Pipeline:**
```
SubViewport Texture
    ↓
Sample at UV
    ↓
Apply Dithering (Bayer Matrix)
    ↓
Quantize to Palette (Nearest Color)
    ↓
Output Color
    ↓
Upscale to Screen (Nearest-Neighbor)
```

---

## 🔧 Shader Code

### Complete Implementation

```gdscript
shader_type canvas_item;

// ====================================================================
// UNIFORMS
// ====================================================================

// Screen texture from SubViewport
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest, repeat_disable;

// Palette configuration
uniform int palette_size : hint_range(2, 256) = 64;
uniform vec3 palette[256];  // RGB colors (0.0 - 1.0 range)

// Dithering configuration
uniform float dither_strength : hint_range(0.0, 2.0) = 1.0;
uniform bool enable_dithering = true;
uniform bool use_bayer_8x8 = true;  // false = 4x4

// Debug options
uniform bool show_palette_debug = false;

// ====================================================================
// CONSTANTS - BAYER MATRICES
// ====================================================================

// Bayer 4x4 matrix (0.0 to 1.0 range)
const float bayer4x4[16] = float[](
     0.0/16.0,  8.0/16.0,  2.0/16.0, 10.0/16.0,
    12.0/16.0,  4.0/16.0, 14.0/16.0,  6.0/16.0,
     3.0/16.0, 11.0/16.0,  1.0/16.0,  9.0/16.0,
    15.0/16.0,  7.0/16.0, 13.0/16.0,  5.0/16.0
);

// Bayer 8x8 matrix (0.0 to 1.0 range)
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

// ====================================================================
// HELPER FUNCTIONS
// ====================================================================

// Get Bayer threshold value at screen position
float get_bayer_threshold(vec2 screen_pos) {
    if (use_bayer_8x8) {
        // Bayer 8x8
        int x = int(mod(screen_pos.x, 8.0));
        int y = int(mod(screen_pos.y, 8.0));
        return bayer8x8[y * 8 + x];
    } else {
        // Bayer 4x4
        int x = int(mod(screen_pos.x, 4.0));
        int y = int(mod(screen_pos.y, 4.0));
        return bayer4x4[y * 4 + x];
    }
}

// Find closest color in palette (Euclidean distance in RGB space)
vec3 find_closest_palette_color(vec3 color) {
    float min_dist = 999999.0;
    vec3 closest = palette[0];

    for (int i = 0; i < palette_size; i++) {
        // Calculate Euclidean distance
        vec3 diff = color - palette[i];
        float dist = dot(diff, diff);  // Squared distance (faster than sqrt)

        if (dist < min_dist) {
            min_dist = dist;
            closest = palette[i];
        }
    }

    return closest;
}

// Alternative: Find closest color using perceptual distance (LAB-like)
// More accurate but slower
vec3 find_closest_palette_color_perceptual(vec3 color) {
    float min_dist = 999999.0;
    vec3 closest = palette[0];

    for (int i = 0; i < palette_size; i++) {
        // Weighted RGB distance (approximates perceptual distance)
        vec3 diff = color - palette[i];
        float dist = (diff.r * diff.r * 0.3) +
                     (diff.g * diff.g * 0.59) +
                     (diff.b * diff.b * 0.11);

        if (dist < min_dist) {
            min_dist = dist;
            closest = palette[i];
        }
    }

    return closest;
}

// ====================================================================
// FRAGMENT SHADER
// ====================================================================

void fragment() {
    // Sample from SubViewport texture
    vec4 color = texture(screen_texture, SCREEN_UV);

    // Apply dithering before quantization
    if (enable_dithering) {
        // Get dither threshold (0.0 to 1.0)
        float threshold = get_bayer_threshold(FRAGCOORD.xy);

        // Center threshold around 0 (-0.5 to 0.5)
        float dither = (threshold - 0.5) * dither_strength;

        // Scale dither amount (tune for best look)
        float dither_amount = 0.08;  // ~8% of color range

        // Apply dither to RGB
        color.rgb += dither * dither_amount;

        // Clamp to valid range
        color.rgb = clamp(color.rgb, 0.0, 1.0);
    }

    // Quantize to palette
    color.rgb = find_closest_palette_color(color.rgb);

    // Debug mode: show palette as gradient
    if (show_palette_debug) {
        int palette_index = int(SCREEN_UV.x * float(palette_size));
        palette_index = clamp(palette_index, 0, palette_size - 1);
        color.rgb = palette[palette_index];
    }

    // Output final color
    COLOR = color;
}
```

---

## 🎨 Dithering Algorithms

### Ordered Dithering (Bayer Matrix)

**Concept:** Use a repeating threshold pattern to create the illusion of intermediate colors.

**Bayer 4×4:**
- 16 unique threshold values
- Subtle dithering
- Good for higher color counts (128+)

**Bayer 8×8:**
- 64 unique threshold values
- More pronounced dithering
- Better for lower color counts (32-64)
- **Recommended for PSX/Saturn aesthetic**

**Visual Effect:**
```
Original gradient: ████████████████
With dithering:    █▓▒░░▒▓███▓▒░
```

### Dithering Strength

**dither_strength parameter:**
- `0.0` = No dithering
- `1.0` = Standard dithering (recommended)
- `2.0` = Heavy dithering (very pronounced)

**dither_amount constant:**
- Controls how much color variation
- `0.08` = 8% of color range (good starting point)
- Adjust based on visual testing

---

## 🎨 Color Quantization

### Euclidean Distance (Default)

```gdscript
vec3 diff = color - palette[i];
float dist = dot(diff, diff);  // Squared distance
```

**Pros:**
- Fast (no sqrt needed)
- Simple
- Works well for most cases

**Cons:**
- Not perceptually accurate
- May choose slightly wrong color

### Perceptual Distance (Alternative)

```gdscript
float dist = (diff.r * diff.r * 0.3) +
             (diff.g * diff.g * 0.59) +
             (diff.b * diff.b * 0.11);
```

**Weights based on human color perception:**
- Green: 59% (most sensitive)
- Red: 30%
- Blue: 11% (least sensitive)

**Pros:**
- More accurate to human perception
- Better color matching

**Cons:**
- Slightly slower
- May not matter for retro aesthetic

**Recommendation:** Start with Euclidean, switch to perceptual if colors look wrong.

---

## 🎨 Palette Format

### Palette Array

```gdscript
uniform vec3 palette[256];
```

**Format:** Array of RGB colors (0.0 - 1.0 range)

**Example:**
```gdscript
palette[0] = vec3(0.0, 0.0, 0.0)        // Black
palette[1] = vec3(0.1, 0.1, 0.15)       // Dark blue-gray
palette[2] = vec3(0.2, 0.15, 0.1)       // Dark brown
// ... up to 256 colors
```

### Setting Palette in GDScript

```gdscript
var material = ShaderMaterial.new()
material.shader = load("res://shaders/retro_3d.gdshader")

# Load palette data
var palette_data = [
    Vector3(0.0, 0.0, 0.0),
    Vector3(0.1, 0.1, 0.15),
    # ... more colors
]

# Set palette (full array)
material.set_shader_parameter("palette", palette_data)
material.set_shader_parameter("palette_size", palette_data.size())
```

---

## 🎨 Palette Storage Options

### Option A: GDScript Resource
```gdscript
# palettes/psx_64.gd
extends Resource
class_name PalettePSX64

const PALETTE = [
    Vector3(0.0, 0.0, 0.0),
    # ... 63 more
]
```

**Pros:** Easy to edit, can be preloaded
**Cons:** Manual color entry

### Option B: PNG Image
```gdscript
# Load palette from 256×1 PNG image
var palette_image = Image.load_from_file("res://palettes/psx_64.png")
var palette_data = []
for x in range(64):
    var color = palette_image.get_pixel(x, 0)
    palette_data.append(Vector3(color.r, color.g, color.b))
```

**Pros:** Visual editing in image editor
**Cons:** Requires image loading

### Option C: JSON File
```json
{
    "name": "PSX 64",
    "size": 64,
    "colors": [
        [0.0, 0.0, 0.0],
        [0.1, 0.1, 0.15],
        ...
    ]
}
```

**Pros:** Human-readable, easy to share
**Cons:** Parsing overhead

**Recommendation:** Use Option A (GDScript) for simplicity.

---

## 🎛️ Shader Parameters

### Uniform Parameters

| Parameter | Type | Range | Default | Description |
|-----------|------|-------|---------|-------------|
| `palette_size` | int | 2-256 | 64 | Number of colors in palette |
| `palette` | vec3[] | N/A | N/A | RGB color array |
| `dither_strength` | float | 0.0-2.0 | 1.0 | Dithering intensity |
| `enable_dithering` | bool | N/A | true | Toggle dithering on/off |
| `use_bayer_8x8` | bool | N/A | true | 8×8 matrix (vs 4×4) |
| `show_palette_debug` | bool | N/A | false | Show palette as gradient |

### Runtime Configuration

```gdscript
# Change dithering strength
material.set_shader_parameter("dither_strength", 0.8)

# Toggle dithering
material.set_shader_parameter("enable_dithering", false)

# Switch to 4×4 matrix
material.set_shader_parameter("use_bayer_8x8", false)

# Debug palette
material.set_shader_parameter("show_palette_debug", true)
```

---

## 🎨 Palette Creation Guide

### PSX Palette (64 colors)

**Characteristics:**
- Slightly muted saturation
- Warm tones preferred
- Good coverage across hues
- Emphasis on earth tones

**Color distribution:**
- Grayscale: 8 colors (black → white)
- Blues: 8 colors (navy → sky blue)
- Greens: 8 colors (dark green → lime)
- Reds/oranges: 8 colors (maroon → orange)
- Browns/tans: 8 colors (dark brown → tan)
- Purples/pinks: 8 colors
- Yellows: 4 colors
- Special (concrete gray, etc.): 12 colors

### Saturn Palette (64 colors)

**Characteristics:**
- Brighter than PSX
- More saturated
- Cleaner colors
- Emphasis on primary colors

**Similar distribution but with higher saturation**

### Limited Palette (32 colors)

**Characteristics:**
- Strong artistic constraint
- High contrast
- Fewer mid-tones
- Bold look

**Color distribution:**
- Grayscale: 4 colors
- Primary hues: 20 colors (4-5 per hue)
- Special: 8 colors

---

## 🔬 Performance Analysis

### Shader Cost

**Per-pixel operations:**
1. Texture sample: ~0.1 cycles
2. Dither calculation: ~5 cycles
3. Palette loop (64 colors): ~200 cycles
4. Total: ~205 cycles per pixel

**For 1920×1080:**
- Total pixels: 2,073,600
- Total cycles: ~425 million
- Estimated time: <1ms on modern GPU

**Optimization:** Negligible cost compared to 3D rendering.

### Palette Loop Optimization

**Current: Linear search**
```gdscript
for (int i = 0; i < palette_size; i++) {
    // Check each color
}
```

**Potential optimization: Octree/KD-tree**
- Pre-build color space partitioning
- Faster lookup (O(log n) vs O(n))
- More complex, probably not needed

**Recommendation:** Linear search is fine for ≤256 colors.

---

## 🧪 Testing Scenarios

### Visual Tests

1. **Gradient test**
   - Render smooth gradients
   - Verify dithering creates smooth appearance
   - Check for banding artifacts

2. **Color variety test**
   - Scene with many different colors
   - Verify palette covers most colors well
   - Check for color collisions

3. **Shadow test**
   - Dark areas with shadows
   - Verify dithering in shadows looks good
   - Check for posterization

4. **Movement test**
   - Move camera rapidly
   - Verify dithering pattern doesn't flicker
   - Check for temporal artifacts

### Parameter Tests

1. **Dithering strength**
   - Test 0.0, 0.5, 1.0, 1.5, 2.0
   - Find sweet spot

2. **Matrix size**
   - Compare 4×4 vs 8×8
   - Choose best for aesthetic

3. **Palette size**
   - Test 32, 64, 128, 256
   - Find minimum acceptable

---

## 🔮 Future Enhancements

### Blue Noise Dithering
```gdscript
uniform sampler2D blue_noise_texture;

float get_blue_noise_threshold(vec2 screen_pos) {
    vec2 uv = mod(screen_pos, vec2(64.0)) / 64.0;
    return texture(blue_noise_texture, uv).r;
}
```

**Pros:** Better visual quality, less patterning
**Cons:** Requires blue noise texture

### Error Diffusion (Floyd-Steinberg)
```gdscript
// Requires multiple passes, more complex
// Better gradients but harder to implement in real-time
```

### Chromatic Aberration (PSX effect)
```gdscript
// Sample R, G, B channels at slightly offset UVs
vec2 r_offset = vec2(0.002, 0.0);
vec2 g_offset = vec2(0.0, 0.0);
vec2 b_offset = vec2(-0.002, 0.0);

color.r = texture(screen_texture, SCREEN_UV + r_offset).r;
color.g = texture(screen_texture, SCREEN_UV + g_offset).g;
color.b = texture(screen_texture, SCREEN_UV + b_offset).b;
```

---

Last Updated: 2025-01-23
Status: Design complete, ready for implementation
