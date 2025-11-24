extends Resource
class_name PaletteLimited32

## Limited 32-Color Palette
##
## Highly constrained artistic palette featuring:
##   - Strong color constraint (only 32 colors)
##   - High contrast between adjacent colors
##   - Fewer mid-tones, more dramatic lighting
##   - Bold, stylized aesthetic
##
## This palette creates a more artistic, graphic look
## with pronounced dithering and stark color transitions.

const PALETTE = [
	# Blacks and darks (0-7)
	Vector3(0.0, 0.0, 0.0),           # Pure black
	Vector3(0.1, 0.1, 0.1),           # Very dark gray
	Vector3(0.15, 0.1, 0.08),         # Dark brown
	Vector3(0.08, 0.12, 0.1),         # Dark green
	Vector3(0.1, 0.1, 0.15),          # Dark blue
	Vector3(0.2, 0.2, 0.2),           # Dark gray
	Vector3(0.25, 0.2, 0.15),         # Brown-gray
	Vector3(0.15, 0.2, 0.25),         # Blue-gray

	# Mid-darks (8-15)
	Vector3(0.35, 0.3, 0.25),         # Brown
	Vector3(0.3, 0.35, 0.3),          # Olive
	Vector3(0.3, 0.3, 0.4),           # Slate
	Vector3(0.4, 0.35, 0.3),          # Tan
	Vector3(0.4, 0.25, 0.2),          # Rust
	Vector3(0.25, 0.4, 0.25),         # Forest green
	Vector3(0.25, 0.3, 0.45),         # Steel blue
	Vector3(0.4, 0.3, 0.4),           # Mauve

	# Mids (16-23)
	Vector3(0.5, 0.5, 0.5),           # Mid gray
	Vector3(0.6, 0.5, 0.4),           # Sand
	Vector3(0.5, 0.6, 0.5),           # Sage
	Vector3(0.5, 0.5, 0.65),          # Light blue
	Vector3(0.7, 0.6, 0.5),           # Beige
	Vector3(0.6, 0.7, 0.6),           # Light green
	Vector3(0.6, 0.6, 0.75),          # Periwinkle
	Vector3(0.7, 0.65, 0.7),          # Lavender

	# Lights (24-31)
	Vector3(0.75, 0.75, 0.75),        # Light gray
	Vector3(0.85, 0.8, 0.7),          # Cream
	Vector3(0.8, 0.85, 0.8),          # Pale green
	Vector3(0.8, 0.8, 0.9),           # Pale blue
	Vector3(0.9, 0.85, 0.75),         # Warm white
	Vector3(0.85, 0.9, 0.85),         # Cool white
	Vector3(0.95, 0.95, 0.95),        # Near white
	Vector3(1.0, 1.0, 1.0)            # Pure white
]

# Metadata
const PALETTE_NAME = "Limited 32"
const PALETTE_DESCRIPTION = "High contrast, artistic constraint - 32 colors"
const PALETTE_SIZE = 32
