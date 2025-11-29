class_name GameConfig

## Centralized Configuration Class
##
## Contains all game constants that were previously scattered across files.
## This is a static class - no instantiation needed, just use GameConfig.CONSTANT
##
## Usage:
##   GameConfig.CHUNK_SIZE
##   GameConfig.get_chunk_center(chunk_key)

# ========================================================================
# CHUNK STREAMING
# ========================================================================

## Size of each chunk (meters x meters)
const CHUNK_SIZE: float = 500.0

## Load chunks within this distance from camera (meters)
const CHUNK_LOAD_RADIUS: float = 750.0

## Unload chunks beyond this distance (meters) - should be > CHUNK_LOAD_RADIUS
const CHUNK_UNLOAD_RADIUS: float = 1500.0

## How often to check for chunk updates (seconds)
const CHUNK_UPDATE_INTERVAL: float = 1.0

## Maximum chunks to load/unload per update cycle
const CHUNK_MAX_PER_FRAME: int = 2

# ========================================================================
# LOADING QUEUE
# ========================================================================

## Max time to spend on loading per frame (milliseconds)
const LOADING_FRAME_BUDGET_MS: float = 5.0

## Maximum queue size before rejecting new items
const LOADING_MAX_QUEUE_SIZE: int = 2000

## Maximum failed items to track (for debugging)
const LOADING_MAX_FAILED_ITEMS: int = 100

# ========================================================================
# CAMERA
# ========================================================================

## Normal movement speed (m/s)
const CAMERA_SPEED_NORMAL: float = 20.0

## Fast movement speed with Shift (m/s)
const CAMERA_SPEED_FAST: float = 100.0

## Speed adjustment per scroll wheel tick
const CAMERA_SPEED_INCREMENT: float = 5.0

## Mouse sensitivity for camera rotation
const CAMERA_SENSITIVITY: float = 0.002

# ========================================================================
# LOD DISTANCES
# ========================================================================

## 0-200m: Full quality with shadows
const LOD_NEAR_DISTANCE: float = 200.0

## 200-1000m: No shadows, covers most visible city
const LOD_MID_DISTANCE: float = 1000.0

## Smooth transition band (for future use)
const LOD_TRANSITION_RANGE: float = 20.0

## Prevents oscillation at LOD boundaries
const LOD_HYSTERESIS_BUFFER: float = 20.0

## LOD update interval (seconds)
const LOD_UPDATE_INTERVAL: float = 0.1

# ========================================================================
# LIGHT BUDGETS
# ========================================================================

## Maximum shadowed lights (expensive)
const LIGHT_MAX_SHADOWED: int = 48

## Maximum total active lights (Forward+ cluster limit consideration)
const LIGHT_MAX_TOTAL: int = 600

# ========================================================================
# TERRAIN
# ========================================================================

## Large water body threshold (square meters) for distant loading
const WATER_LARGE_THRESHOLD: float = 50000.0

# ========================================================================
# HELPER FUNCTIONS
# ========================================================================

## Get the world center position of a chunk
static func get_chunk_center(chunk_key: Vector2i) -> Vector2:
	return Vector2(
		chunk_key.x * CHUNK_SIZE + CHUNK_SIZE / 2.0,
		chunk_key.y * CHUNK_SIZE + CHUNK_SIZE / 2.0
	)

## Convert world position to chunk key
static func get_chunk_key(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / CHUNK_SIZE)),
		int(floor(world_pos.y / CHUNK_SIZE))
	)

## Get chunk radius in chunk units for a given world radius
static func get_chunk_radius(world_radius: float) -> int:
	return int(ceil(world_radius / CHUNK_SIZE))
