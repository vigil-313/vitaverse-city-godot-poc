extends Resource
class_name PaletteExtended256

## Extended 256-Color Palette
##
## Maximum flexibility palette featuring:
##   - 256 colors for subtle quantization
##   - Comprehensive RGB coverage
##   - Smooth gradients possible
##   - Minimal artistic constraint
##
## This palette provides near-photorealistic quantization
## while still maintaining the retro dithering aesthetic.
##
## Generated using systematic RGB subdivision for even coverage.

const PALETTE = [
	# Grayscale ramp (0-15) - 16 shades from black to white
	Vector3(0.0, 0.0, 0.0),
	Vector3(0.067, 0.067, 0.067),
	Vector3(0.133, 0.133, 0.133),
	Vector3(0.2, 0.2, 0.2),
	Vector3(0.267, 0.267, 0.267),
	Vector3(0.333, 0.333, 0.333),
	Vector3(0.4, 0.4, 0.4),
	Vector3(0.467, 0.467, 0.467),
	Vector3(0.533, 0.533, 0.533),
	Vector3(0.6, 0.6, 0.6),
	Vector3(0.667, 0.667, 0.667),
	Vector3(0.733, 0.733, 0.733),
	Vector3(0.8, 0.8, 0.8),
	Vector3(0.867, 0.867, 0.867),
	Vector3(0.933, 0.933, 0.933),
	Vector3(1.0, 1.0, 1.0),

	# RGB cube - 6×6×6 = 216 colors (16-231)
	# R increases every 36 colors, G every 6 colors, B every color
	# Levels: 0.0, 0.2, 0.4, 0.6, 0.8, 1.0

	# R=0.0 (16-51)
	Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.2), Vector3(0.0, 0.0, 0.4), Vector3(0.0, 0.0, 0.6), Vector3(0.0, 0.0, 0.8), Vector3(0.0, 0.0, 1.0),
	Vector3(0.0, 0.2, 0.0), Vector3(0.0, 0.2, 0.2), Vector3(0.0, 0.2, 0.4), Vector3(0.0, 0.2, 0.6), Vector3(0.0, 0.2, 0.8), Vector3(0.0, 0.2, 1.0),
	Vector3(0.0, 0.4, 0.0), Vector3(0.0, 0.4, 0.2), Vector3(0.0, 0.4, 0.4), Vector3(0.0, 0.4, 0.6), Vector3(0.0, 0.4, 0.8), Vector3(0.0, 0.4, 1.0),
	Vector3(0.0, 0.6, 0.0), Vector3(0.0, 0.6, 0.2), Vector3(0.0, 0.6, 0.4), Vector3(0.0, 0.6, 0.6), Vector3(0.0, 0.6, 0.8), Vector3(0.0, 0.6, 1.0),
	Vector3(0.0, 0.8, 0.0), Vector3(0.0, 0.8, 0.2), Vector3(0.0, 0.8, 0.4), Vector3(0.0, 0.8, 0.6), Vector3(0.0, 0.8, 0.8), Vector3(0.0, 0.8, 1.0),
	Vector3(0.0, 1.0, 0.0), Vector3(0.0, 1.0, 0.2), Vector3(0.0, 1.0, 0.4), Vector3(0.0, 1.0, 0.6), Vector3(0.0, 1.0, 0.8), Vector3(0.0, 1.0, 1.0),

	# R=0.2 (52-87)
	Vector3(0.2, 0.0, 0.0), Vector3(0.2, 0.0, 0.2), Vector3(0.2, 0.0, 0.4), Vector3(0.2, 0.0, 0.6), Vector3(0.2, 0.0, 0.8), Vector3(0.2, 0.0, 1.0),
	Vector3(0.2, 0.2, 0.0), Vector3(0.2, 0.2, 0.2), Vector3(0.2, 0.2, 0.4), Vector3(0.2, 0.2, 0.6), Vector3(0.2, 0.2, 0.8), Vector3(0.2, 0.2, 1.0),
	Vector3(0.2, 0.4, 0.0), Vector3(0.2, 0.4, 0.2), Vector3(0.2, 0.4, 0.4), Vector3(0.2, 0.4, 0.6), Vector3(0.2, 0.4, 0.8), Vector3(0.2, 0.4, 1.0),
	Vector3(0.2, 0.6, 0.0), Vector3(0.2, 0.6, 0.2), Vector3(0.2, 0.6, 0.4), Vector3(0.2, 0.6, 0.6), Vector3(0.2, 0.6, 0.8), Vector3(0.2, 0.6, 1.0),
	Vector3(0.2, 0.8, 0.0), Vector3(0.2, 0.8, 0.2), Vector3(0.2, 0.8, 0.4), Vector3(0.2, 0.8, 0.6), Vector3(0.2, 0.8, 0.8), Vector3(0.2, 0.8, 1.0),
	Vector3(0.2, 1.0, 0.0), Vector3(0.2, 1.0, 0.2), Vector3(0.2, 1.0, 0.4), Vector3(0.2, 1.0, 0.6), Vector3(0.2, 1.0, 0.8), Vector3(0.2, 1.0, 1.0),

	# R=0.4 (88-123)
	Vector3(0.4, 0.0, 0.0), Vector3(0.4, 0.0, 0.2), Vector3(0.4, 0.0, 0.4), Vector3(0.4, 0.0, 0.6), Vector3(0.4, 0.0, 0.8), Vector3(0.4, 0.0, 1.0),
	Vector3(0.4, 0.2, 0.0), Vector3(0.4, 0.2, 0.2), Vector3(0.4, 0.2, 0.4), Vector3(0.4, 0.2, 0.6), Vector3(0.4, 0.2, 0.8), Vector3(0.4, 0.2, 1.0),
	Vector3(0.4, 0.4, 0.0), Vector3(0.4, 0.4, 0.2), Vector3(0.4, 0.4, 0.4), Vector3(0.4, 0.4, 0.6), Vector3(0.4, 0.4, 0.8), Vector3(0.4, 0.4, 1.0),
	Vector3(0.4, 0.6, 0.0), Vector3(0.4, 0.6, 0.2), Vector3(0.4, 0.6, 0.4), Vector3(0.4, 0.6, 0.6), Vector3(0.4, 0.6, 0.8), Vector3(0.4, 0.6, 1.0),
	Vector3(0.4, 0.8, 0.0), Vector3(0.4, 0.8, 0.2), Vector3(0.4, 0.8, 0.4), Vector3(0.4, 0.8, 0.6), Vector3(0.4, 0.8, 0.8), Vector3(0.4, 0.8, 1.0),
	Vector3(0.4, 1.0, 0.0), Vector3(0.4, 1.0, 0.2), Vector3(0.4, 1.0, 0.4), Vector3(0.4, 1.0, 0.6), Vector3(0.4, 1.0, 0.8), Vector3(0.4, 1.0, 1.0),

	# R=0.6 (124-159)
	Vector3(0.6, 0.0, 0.0), Vector3(0.6, 0.0, 0.2), Vector3(0.6, 0.0, 0.4), Vector3(0.6, 0.0, 0.6), Vector3(0.6, 0.0, 0.8), Vector3(0.6, 0.0, 1.0),
	Vector3(0.6, 0.2, 0.0), Vector3(0.6, 0.2, 0.2), Vector3(0.6, 0.2, 0.4), Vector3(0.6, 0.2, 0.6), Vector3(0.6, 0.2, 0.8), Vector3(0.6, 0.2, 1.0),
	Vector3(0.6, 0.4, 0.0), Vector3(0.6, 0.4, 0.2), Vector3(0.6, 0.4, 0.4), Vector3(0.6, 0.4, 0.6), Vector3(0.6, 0.4, 0.8), Vector3(0.6, 0.4, 1.0),
	Vector3(0.6, 0.6, 0.0), Vector3(0.6, 0.6, 0.2), Vector3(0.6, 0.6, 0.4), Vector3(0.6, 0.6, 0.6), Vector3(0.6, 0.6, 0.8), Vector3(0.6, 0.6, 1.0),
	Vector3(0.6, 0.8, 0.0), Vector3(0.6, 0.8, 0.2), Vector3(0.6, 0.8, 0.4), Vector3(0.6, 0.8, 0.6), Vector3(0.6, 0.8, 0.8), Vector3(0.6, 0.8, 1.0),
	Vector3(0.6, 1.0, 0.0), Vector3(0.6, 1.0, 0.2), Vector3(0.6, 1.0, 0.4), Vector3(0.6, 1.0, 0.6), Vector3(0.6, 1.0, 0.8), Vector3(0.6, 1.0, 1.0),

	# R=0.8 (160-195)
	Vector3(0.8, 0.0, 0.0), Vector3(0.8, 0.0, 0.2), Vector3(0.8, 0.0, 0.4), Vector3(0.8, 0.0, 0.6), Vector3(0.8, 0.0, 0.8), Vector3(0.8, 0.0, 1.0),
	Vector3(0.8, 0.2, 0.0), Vector3(0.8, 0.2, 0.2), Vector3(0.8, 0.2, 0.4), Vector3(0.8, 0.2, 0.6), Vector3(0.8, 0.2, 0.8), Vector3(0.8, 0.2, 1.0),
	Vector3(0.8, 0.4, 0.0), Vector3(0.8, 0.4, 0.2), Vector3(0.8, 0.4, 0.4), Vector3(0.8, 0.4, 0.6), Vector3(0.8, 0.4, 0.8), Vector3(0.8, 0.4, 1.0),
	Vector3(0.8, 0.6, 0.0), Vector3(0.8, 0.6, 0.2), Vector3(0.8, 0.6, 0.4), Vector3(0.8, 0.6, 0.6), Vector3(0.8, 0.6, 0.8), Vector3(0.8, 0.6, 1.0),
	Vector3(0.8, 0.8, 0.0), Vector3(0.8, 0.8, 0.2), Vector3(0.8, 0.8, 0.4), Vector3(0.8, 0.8, 0.6), Vector3(0.8, 0.8, 0.8), Vector3(0.8, 0.8, 1.0),
	Vector3(0.8, 1.0, 0.0), Vector3(0.8, 1.0, 0.2), Vector3(0.8, 1.0, 0.4), Vector3(0.8, 1.0, 0.6), Vector3(0.8, 1.0, 0.8), Vector3(0.8, 1.0, 1.0),

	# R=1.0 (196-231)
	Vector3(1.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.2), Vector3(1.0, 0.0, 0.4), Vector3(1.0, 0.0, 0.6), Vector3(1.0, 0.0, 0.8), Vector3(1.0, 0.0, 1.0),
	Vector3(1.0, 0.2, 0.0), Vector3(1.0, 0.2, 0.2), Vector3(1.0, 0.2, 0.4), Vector3(1.0, 0.2, 0.6), Vector3(1.0, 0.2, 0.8), Vector3(1.0, 0.2, 1.0),
	Vector3(1.0, 0.4, 0.0), Vector3(1.0, 0.4, 0.2), Vector3(1.0, 0.4, 0.4), Vector3(1.0, 0.4, 0.6), Vector3(1.0, 0.4, 0.8), Vector3(1.0, 0.4, 1.0),
	Vector3(1.0, 0.6, 0.0), Vector3(1.0, 0.6, 0.2), Vector3(1.0, 0.6, 0.4), Vector3(1.0, 0.6, 0.6), Vector3(1.0, 0.6, 0.8), Vector3(1.0, 0.6, 1.0),
	Vector3(1.0, 0.8, 0.0), Vector3(1.0, 0.8, 0.2), Vector3(1.0, 0.8, 0.4), Vector3(1.0, 0.8, 0.6), Vector3(1.0, 0.8, 0.8), Vector3(1.0, 0.8, 1.0),
	Vector3(1.0, 1.0, 0.0), Vector3(1.0, 1.0, 0.2), Vector3(1.0, 1.0, 0.4), Vector3(1.0, 1.0, 0.6), Vector3(1.0, 1.0, 0.8), Vector3(1.0, 1.0, 1.0),

	# Additional earth tones and skin tones (232-255) - 24 colors
	Vector3(0.55, 0.45, 0.35), Vector3(0.65, 0.55, 0.45), Vector3(0.75, 0.65, 0.55), Vector3(0.85, 0.75, 0.65),
	Vector3(0.5, 0.4, 0.3), Vector3(0.6, 0.5, 0.4), Vector3(0.7, 0.6, 0.5), Vector3(0.8, 0.7, 0.6),
	Vector3(0.45, 0.35, 0.25), Vector3(0.55, 0.45, 0.35), Vector3(0.65, 0.55, 0.45), Vector3(0.75, 0.65, 0.55),
	Vector3(0.9, 0.8, 0.7), Vector3(0.85, 0.75, 0.65), Vector3(0.8, 0.7, 0.6), Vector3(0.75, 0.65, 0.55),
	Vector3(0.7, 0.6, 0.5), Vector3(0.65, 0.55, 0.45), Vector3(0.6, 0.5, 0.4), Vector3(0.55, 0.45, 0.35),
	Vector3(0.95, 0.85, 0.75), Vector3(0.9, 0.8, 0.7), Vector3(0.85, 0.75, 0.65), Vector3(0.8, 0.7, 0.6)
]

# Metadata
const PALETTE_NAME = "Extended 256"
const PALETTE_DESCRIPTION = "Maximum flexibility - 256 colors for subtle quantization"
const PALETTE_SIZE = 256
