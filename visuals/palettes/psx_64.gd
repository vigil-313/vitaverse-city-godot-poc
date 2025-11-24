extends Resource
class_name PalettePSX64

## PSX 64-Color Palette
##
## Retro PlayStation-style color palette featuring:
##   - Muted saturation for authentic PSX aesthetic
##   - Warm earth tones
##   - Good hue coverage across the spectrum
##   - Balanced distribution of darks, mids, and lights
##
## This palette is optimized for outdoor city scenes with buildings,
## roads, vegetation, and sky.

const PALETTE = [
	# Blacks and dark grays (0-7)
	Vector3(0.0, 0.0, 0.0),           # Pure black
	Vector3(0.1, 0.1, 0.12),          # Dark blue-gray
	Vector3(0.12, 0.1, 0.08),         # Dark brown-gray
	Vector3(0.08, 0.1, 0.08),         # Dark green-gray
	Vector3(0.15, 0.15, 0.15),        # Dark gray
	Vector3(0.2, 0.18, 0.16),         # Charcoal brown
	Vector3(0.18, 0.2, 0.22),         # Charcoal blue
	Vector3(0.16, 0.18, 0.16),        # Charcoal green

	# Mid-dark tones (8-15) - Earth tones
	Vector3(0.25, 0.22, 0.18),        # Dark tan
	Vector3(0.28, 0.24, 0.2),         # Brown
	Vector3(0.22, 0.26, 0.22),        # Dark olive
	Vector3(0.2, 0.24, 0.28),         # Dark slate blue
	Vector3(0.3, 0.25, 0.22),         # Warm brown
	Vector3(0.32, 0.28, 0.2),         # Clay brown
	Vector3(0.24, 0.28, 0.24),        # Moss green
	Vector3(0.26, 0.22, 0.3),         # Dark purple-gray

	# Mid tones (16-31) - Saturated earth
	Vector3(0.4, 0.35, 0.25),         # Tan
	Vector3(0.45, 0.38, 0.28),        # Light brown
	Vector3(0.35, 0.42, 0.3),         # Olive green
	Vector3(0.3, 0.38, 0.45),         # Steel blue
	Vector3(0.5, 0.4, 0.3),           # Sand
	Vector3(0.55, 0.45, 0.35),        # Desert sand
	Vector3(0.38, 0.5, 0.35),         # Sage green
	Vector3(0.4, 0.35, 0.5),          # Muted purple

	Vector3(0.6, 0.5, 0.4),           # Beige
	Vector3(0.5, 0.55, 0.45),         # Khaki
	Vector3(0.45, 0.5, 0.6),          # Light slate
	Vector3(0.55, 0.48, 0.42),        # Warm beige
	Vector3(0.42, 0.55, 0.42),        # Faded green
	Vector3(0.5, 0.42, 0.38),         # Terracotta
	Vector3(0.38, 0.42, 0.5),         # Dusty blue
	Vector3(0.48, 0.45, 0.52),        # Muted lavender

	# Bright earth tones (32-47)
	Vector3(0.7, 0.6, 0.45),          # Light tan
	Vector3(0.65, 0.7, 0.55),         # Light olive
	Vector3(0.6, 0.65, 0.7),          # Powder blue
	Vector3(0.75, 0.65, 0.5),         # Pale sand
	Vector3(0.5, 0.65, 0.5),          # Pale green
	Vector3(0.7, 0.55, 0.45),         # Salmon
	Vector3(0.55, 0.55, 0.7),         # Periwinkle
	Vector3(0.65, 0.6, 0.55),         # Warm gray

	Vector3(0.8, 0.7, 0.55),          # Cream
	Vector3(0.7, 0.75, 0.6),          # Pale yellow-green
	Vector3(0.6, 0.7, 0.8),           # Sky blue
	Vector3(0.75, 0.7, 0.65),         # Light beige
	Vector3(0.65, 0.75, 0.65),        # Mint green
	Vector3(0.8, 0.65, 0.55),         # Peach
	Vector3(0.6, 0.6, 0.75),          # Light blue-gray
	Vector3(0.7, 0.65, 0.7),          # Pale mauve

	# Vibrant accents (48-55) - Roads, buildings, details
	Vector3(0.5, 0.5, 0.55),          # Concrete gray
	Vector3(0.35, 0.35, 0.4),         # Asphalt gray
	Vector3(0.6, 0.25, 0.2),          # Brick red
	Vector3(0.7, 0.3, 0.25),          # Bright brick
	Vector3(0.25, 0.5, 0.3),          # Forest green
	Vector3(0.3, 0.6, 0.35),          # Grass green
	Vector3(0.4, 0.5, 0.65),          # Building blue
	Vector3(0.5, 0.6, 0.75),          # Glass blue

	# Very light tones (56-63) - Sky, highlights
	Vector3(0.85, 0.8, 0.7),          # Off-white warm
	Vector3(0.8, 0.85, 0.75),         # Off-white cool
	Vector3(0.75, 0.8, 0.85),         # Sky white
	Vector3(0.9, 0.85, 0.75),         # Warm white
	Vector3(0.8, 0.9, 0.85),          # Pale cyan
	Vector3(0.85, 0.75, 0.8),         # Pale pink
	Vector3(0.9, 0.9, 0.85),          # Almost white warm
	Vector3(0.95, 0.95, 0.95)         # Near white
]

# Metadata
const PALETTE_NAME = "PSX 64"
const PALETTE_DESCRIPTION = "Muted, warm earth tones - PlayStation aesthetic"
const PALETTE_SIZE = 64
