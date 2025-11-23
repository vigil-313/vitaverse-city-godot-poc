# Making It Look Like a Pixel Art Game

## ✅ What I Just Added:

### 1. **Pixelation Shader**
- Located in `shaders/pixelate.gdshader`
- Renders the 3D scene then pixelates it
- **Adjustable**: Change `pixel_size` in the shader (currently 3)
  - Lower value = more pixels (smoother)
  - Higher value = fewer pixels (chunkier, more retro)

### 2. **Decorative Elements**
- **Plants** on either side of entrance (brown pots with green tops)
- **Sign** above the door (orange/coffee colored)
- **Awning** over the entrance (angled overhang)

### 3. **Better Material Setup**
- All objects now use proper materials
- Pixel-perfect texture filtering enabled in project settings

## 🎨 Current Pixel Art Features:

✅ Pixelation effect (makes 3D look retro)
✅ Low-poly voxel style
✅ Flat shaded materials
✅ No texture filtering (crisp pixels)
✅ Golden hour color palette
✅ Simple geometric shapes

## 🚀 Next Steps to Enhance:

### Easy Improvements:

1. **Adjust Pixelation**
   - Open `scenes/pixelate_layer.tscn`
   - Change `shader_parameter/pixel_size` value
   - Try 2 (subtle), 4 (medium), 6 (chunky)

2. **Add More Props**
   - Copy the plant/decoration code
   - Add trash cans, benches, mailboxes
   - Street lamps outside

3. **Color Palette**
   - Limit to specific colors (like 16-32 total)
   - Use a palette shader to quantize colors

### Medium Improvements:

4. **Pixel Art Textures**
   - Create 16x16 or 32x32 textures in Aseprite/Pixaki
   - Apply to walls, floors, furniture
   - Examples:
     - Brick wall texture
     - Wood grain for furniture
     - Tile pattern for floor

5. **Outline Shader**
   - Add edge detection to make shapes pop
   - Creates that "toon shader" look

6. **Character Sprite Animation**
   - Use billboard sprites instead of 3D character
   - Create 4-8 frame walk cycle
   - Rotate sprite to face camera

### Advanced Improvements:

7. **Dithering**
   - Add dither shader for shadows
   - Creates retro gradient effect

8. **Viewport Resolution**
   - Render at 320x240 or 640x480
   - Scale up to window size
   - More authentic retro look

9. **Color Quantization**
   - Limit entire scene to specific palette
   - EGA, VGA, or GB-style colors

## 📝 How to Add Textures:

1. **Create pixel art texture** (16x16 or 32x32 PNG)
2. Import to `assets/textures/`
3. In Godot Inspector, set **Filter** to **Nearest**
4. Apply to material's Albedo Texture

Example texture setup:
```gdscript
[sub_resource type="StandardMaterial3D" id="Material_brick"]
albedo_texture = preload("res://assets/textures/brick_16x16.png")
texture_filter = 0  # Nearest (pixel perfect)
```

## 🎮 Recommended Settings:

**For Best Pixel Art Look:**
- Pixel size: 3-4
- Resolution: 640x480 base (scaled to 1280x720)
- Texture size: 16x16 or 32x32
- Color palette: 32 colors max
- Anti-aliasing: OFF (already set)

**For More Modern Pixel Look:**
- Pixel size: 2
- Resolution: 1280x720
- Texture size: 64x64
- More colors allowed
- Subtle outlines

## 📚 Resources for Pixel Art:

- **Aseprite**: Best tool for creating pixel art
- **Lospec.com**: Pixel art palettes
- **OpenGameArt.org**: Free pixel art assets
- **itch.io**: Pixel art asset packs

## 🔧 Quick Tweaks to Try Now:

1. **Make it chunkier**: Change pixel_size to 5 or 6
2. **Add more lights**: OmniLight3D nodes with warm colors
3. **Add street**: CSGBox3D outside the building (gray)
4. **Add sidewalk**: Different colored ground near building
5. **Add second building**: Duplicate CafeBuilding, move it

## Current Look:
- ✅ Proper building structure
- ✅ Pixelation effect active
- ✅ Decorative elements (plants, sign, awning)
- ✅ Interior furniture and lighting
- ✅ Warm cafe atmosphere

**Next priority**: Add actual pixel art textures to replace solid colors!
