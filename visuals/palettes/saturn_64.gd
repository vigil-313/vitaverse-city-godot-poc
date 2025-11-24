extends Resource
class_name PaletteSaturn64

## Saturn 64-Color Palette
##
## Retro Sega Saturn-style color palette featuring:
##   - Brighter than PSX palette
##   - More saturated colors
##   - Cleaner primary colors
##   - Vibrant aesthetic
##
## This palette emphasizes clarity and pop, suitable for
## more colorful retro rendering.

const PALETTE = [
	# Blacks and dark grays (0-7)
	Vector3(0.0, 0.0, 0.0),           # Pure black
	Vector3(0.12, 0.12, 0.15),        # Dark blue-gray
	Vector3(0.15, 0.1, 0.05),         # Dark brown
	Vector3(0.05, 0.12, 0.08),        # Dark green
	Vector3(0.18, 0.18, 0.18),        # Dark gray
	Vector3(0.2, 0.15, 0.1),          # Deep brown
	Vector3(0.1, 0.15, 0.25),         # Deep blue
	Vector3(0.1, 0.2, 0.1),           # Deep green

	# Mid-dark tones (8-15)
	Vector3(0.3, 0.25, 0.2),          # Brown
	Vector3(0.35, 0.3, 0.25),         # Light brown
	Vector3(0.2, 0.3, 0.2),           # Olive
	Vector3(0.2, 0.25, 0.35),         # Slate blue
	Vector3(0.35, 0.2, 0.15),         # Rust
	Vector3(0.4, 0.3, 0.2),           # Tan brown
	Vector3(0.25, 0.35, 0.25),        # Forest green
	Vector3(0.3, 0.2, 0.35),          # Purple

	# Mid tones (16-31)
	Vector3(0.5, 0.4, 0.3),           # Sand
	Vector3(0.55, 0.45, 0.35),        # Desert
	Vector3(0.4, 0.5, 0.35),          # Sage
	Vector3(0.35, 0.45, 0.55),        # Steel blue
	Vector3(0.6, 0.5, 0.4),           # Beige
	Vector3(0.65, 0.55, 0.45),        # Light sand
	Vector3(0.45, 0.55, 0.4),         # Olive green
	Vector3(0.5, 0.4, 0.6),           # Lavender

	Vector3(0.7, 0.6, 0.5),           # Cream tan
	Vector3(0.6, 0.65, 0.55),         # Khaki
	Vector3(0.55, 0.6, 0.7),          # Light blue
	Vector3(0.65, 0.55, 0.5),         # Warm tan
	Vector3(0.5, 0.65, 0.5),          # Mint
	Vector3(0.6, 0.5, 0.45),          # Terracotta
	Vector3(0.45, 0.5, 0.6),          # Dusty blue
	Vector3(0.55, 0.5, 0.65),         # Mauve

	# Bright tones (32-47)
	Vector3(0.8, 0.7, 0.6),           # Light tan
	Vector3(0.75, 0.8, 0.65),         # Light olive
	Vector3(0.7, 0.75, 0.85),         # Sky blue
	Vector3(0.85, 0.75, 0.65),        # Peach
	Vector3(0.65, 0.8, 0.65),         # Light green
	Vector3(0.8, 0.65, 0.6),          # Salmon
	Vector3(0.65, 0.65, 0.8),         # Periwinkle
	Vector3(0.75, 0.7, 0.65),         # Warm gray

	Vector3(0.9, 0.8, 0.7),           # Cream
	Vector3(0.8, 0.9, 0.75),          # Pale yellow
	Vector3(0.75, 0.85, 0.95),        # Light sky
	Vector3(0.85, 0.8, 0.75),         # Off-white tan
	Vector3(0.75, 0.9, 0.8),          # Pale mint
	Vector3(0.9, 0.75, 0.7),          # Light peach
	Vector3(0.7, 0.75, 0.9),          # Pale blue
	Vector3(0.8, 0.75, 0.85),         # Pale lavender

	# Vibrant colors (48-55) - Saturn signature bright colors
	Vector3(0.9, 0.2, 0.15),          # Bright red
	Vector3(0.95, 0.4, 0.2),          # Orange-red
	Vector3(0.95, 0.7, 0.2),          # Golden yellow
	Vector3(0.2, 0.7, 0.3),           # Bright green
	Vector3(0.2, 0.6, 0.9),           # Bright blue
	Vector3(0.6, 0.3, 0.9),           # Bright purple
	Vector3(0.9, 0.5, 0.7),           # Pink
	Vector3(0.3, 0.9, 0.8),           # Cyan

	# Very light tones (56-63)
	Vector3(0.92, 0.88, 0.8),         # Warm white
	Vector3(0.88, 0.92, 0.85),        # Cool white
	Vector3(0.85, 0.9, 0.95),         # Sky white
	Vector3(0.95, 0.9, 0.85),         # Cream white
	Vector3(0.9, 0.95, 0.92),         # Mint white
	Vector3(0.95, 0.85, 0.9),         # Pink white
	Vector3(0.95, 0.95, 0.9),         # Warm near-white
	Vector3(0.98, 0.98, 0.98)         # Near white
]

# Metadata
const PALETTE_NAME = "Saturn 64"
const PALETTE_DESCRIPTION = "Brighter, more saturated - Sega Saturn aesthetic"
const PALETTE_SIZE = 64
