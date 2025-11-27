extends Node
class_name LightingLODManager

## LOD-Based Lighting Manager
##
## Manages dynamic light LOD tiers based on camera distance to prevent
## exceeding Godot's Forward+ cluster limits (~128 lights per cluster).
##
## Tier System:
##   NEAR (0-100m):   Full quality OmniLight3D with shadows
##   MID (100-300m):  OmniLight3D without shadows, reduced energy/range
##   FAR (300m+):     Emissive materials only, no dynamic lights

# ========================================================================
# CONFIGURATION CONSTANTS
# ========================================================================

## LOD distance thresholds
const LOD_NEAR_DISTANCE := 200.0    ## 0-200m: Full quality with shadows
const LOD_MID_DISTANCE := 1000.0    ## 200-1000m: No shadows, covers most visible city
const LOD_TRANSITION_RANGE := 20.0  ## Smooth transition band (unused for now)
const HYSTERESIS_BUFFER := 20.0     ## Prevents oscillation at boundaries

## Light budgets - increased since floor lights are now sparse (40% per building)
## With fewer total lights, we can keep more active in NEAR/MID tiers
const MAX_SHADOWED_LIGHTS := 48     ## More shadows affordable with sparse lights
const MAX_TOTAL_LIGHTS := 600       ## Higher budget for city-wide coverage

## Update throttling
const UPDATE_INTERVAL := 0.1        ## Update LOD every 100ms

# ========================================================================
# LOD TIERS
# ========================================================================

enum LODTier {
	NEAR = 0,  ## Full shadows, full energy
	MID = 1,   ## No shadows, reduced energy/range
	FAR = 2    ## Emissive only, no dynamic light
}

# ========================================================================
# SIGNALS
# ========================================================================

## Emitted when light counts change (for debug UI)
signal light_count_changed(shadowed: int, active: int, total_registered: int)

## Emitted when budget is exceeded (for debugging)
signal budget_warning(message: String)

# ========================================================================
# STATE
# ========================================================================

## Tracked building lights (LODLightProxy instances)
var building_lights: Array = []

## Tracked street lights
var street_lights: Array = []

## External references
var camera: Camera3D
var lighting_controller  ## LightingController instance

## Update timer
var _update_timer: float = 0.0

## Stats for debug UI
var stats := {
	"shadowed_count": 0,
	"active_count": 0,
	"total_registered": 0,
	"near_count": 0,
	"mid_count": 0,
	"far_count": 0
}

# ========================================================================
# INITIALIZATION
# ========================================================================

func _ready():
	print("[LightingLODManager] Initialized")
	print("  - NEAR distance: ", LOD_NEAR_DISTANCE, "m (with shadows)")
	print("  - MID distance: ", LOD_MID_DISTANCE, "m (no shadows)")
	print("  - Max shadowed: ", MAX_SHADOWED_LIGHTS)
	print("  - Max total active: ", MAX_TOTAL_LIGHTS)
	print("  - Using horizontal distance (height ignored)")

# ========================================================================
# REGISTRATION
# ========================================================================

## Register a building light (LODLightProxy) with the LOD system
func register_building_light(proxy) -> void:
	if proxy not in building_lights:
		building_lights.append(proxy)
		proxy.lod_manager = self

## Unregister a building light (called during chunk unload)
func unregister_building_light(proxy) -> void:
	building_lights.erase(proxy)

## Register a street light
func register_street_light(lamp) -> void:
	if lamp not in street_lights:
		street_lights.append(lamp)

## Unregister a street light
func unregister_street_light(lamp) -> void:
	street_lights.erase(lamp)

# ========================================================================
# MAIN UPDATE
# ========================================================================

## Main update function - called from CityRenderer._process()
func update_lod(camera_position: Vector3, delta: float) -> void:
	_update_timer += delta
	if _update_timer < UPDATE_INTERVAL:
		return
	_update_timer = 0.0

	# Clean up invalid references
	_cleanup_invalid_references()

	# Update all lights
	_update_building_lights(camera_position)
	_update_street_lights(camera_position)

	# Enforce budget limits
	_enforce_budget(camera_position)

	# Update stats
	stats.total_registered = building_lights.size()

## Remove invalid/freed references from tracking arrays
func _cleanup_invalid_references() -> void:
	building_lights = building_lights.filter(func(p): return is_instance_valid(p))
	street_lights = street_lights.filter(func(l): return is_instance_valid(l))

# ========================================================================
# BUILDING LIGHTS UPDATE
# ========================================================================

## Update all building lights based on horizontal distance (ignore height)
func _update_building_lights(camera_pos: Vector3) -> void:
	for proxy in building_lights:
		if not is_instance_valid(proxy):
			continue

		# Use horizontal distance only (XZ plane) - height shouldn't affect LOD
		var proxy_pos = proxy.global_position
		var horizontal_dist = Vector2(camera_pos.x - proxy_pos.x, camera_pos.z - proxy_pos.z).length()

		var current_tier = proxy.current_tier if proxy.has_method("get_current_tier") else proxy.current_tier
		var new_tier = _get_lod_tier_with_hysteresis(horizontal_dist, current_tier)

		if new_tier != current_tier:
			proxy.set_lod_tier(new_tier)

## Calculate LOD tier with hysteresis to prevent oscillation
func _get_lod_tier_with_hysteresis(distance: float, current_tier: int) -> int:
	match current_tier:
		LODTier.NEAR:
			# Only transition to MID if clearly past threshold
			if distance > LOD_NEAR_DISTANCE + HYSTERESIS_BUFFER:
				return LODTier.MID
		LODTier.MID:
			# Transition back to NEAR if clearly before threshold
			if distance < LOD_NEAR_DISTANCE - HYSTERESIS_BUFFER:
				return LODTier.NEAR
			# Transition to FAR if clearly past threshold
			elif distance > LOD_MID_DISTANCE + HYSTERESIS_BUFFER:
				return LODTier.FAR
		LODTier.FAR:
			# Transition back to MID if clearly before threshold
			if distance < LOD_MID_DISTANCE - HYSTERESIS_BUFFER:
				return LODTier.MID

	return current_tier

# ========================================================================
# STREET LIGHTS UPDATE
# ========================================================================

## Update all street lights based on horizontal distance
func _update_street_lights(camera_pos: Vector3) -> void:
	for lamp in street_lights:
		if not is_instance_valid(lamp):
			continue

		# Use horizontal distance only
		var lamp_pos = lamp.global_position
		var horizontal_dist = Vector2(camera_pos.x - lamp_pos.x, camera_pos.z - lamp_pos.z).length()
		var tier = LODTier.NEAR

		if horizontal_dist > LOD_MID_DISTANCE:
			tier = LODTier.FAR
		elif horizontal_dist > LOD_NEAR_DISTANCE:
			tier = LODTier.MID

		if lamp.has_method("set_lod_tier"):
			lamp.set_lod_tier(tier)

# ========================================================================
# BUDGET ENFORCEMENT
# ========================================================================

## Enforce light budget - closest lights get priority
func _enforce_budget(camera_pos: Vector3) -> void:
	# Collect all non-FAR lights with horizontal distances
	var lights_with_dist: Array = []

	for proxy in building_lights:
		if not is_instance_valid(proxy):
			continue
		if proxy.current_tier == LODTier.FAR:
			continue

		# Use horizontal distance for budget priority
		var proxy_pos = proxy.global_position
		var dist = Vector2(camera_pos.x - proxy_pos.x, camera_pos.z - proxy_pos.z).length()
		lights_with_dist.append({"proxy": proxy, "distance": dist})

	# Sort by distance (closest first)
	lights_with_dist.sort_custom(func(a, b): return a.distance < b.distance)

	# Apply budget
	var shadowed_count := 0
	var active_count := 0
	var near_count := 0
	var mid_count := 0

	for item in lights_with_dist:
		var proxy = item.proxy

		if active_count >= MAX_TOTAL_LIGHTS:
			# Over budget - force to FAR (emissive only)
			proxy.set_lod_tier(LODTier.FAR, true)  # immediate=true
			continue

		# Handle shadow budget for NEAR lights
		if proxy.current_tier == LODTier.NEAR:
			if shadowed_count < MAX_SHADOWED_LIGHTS:
				proxy.set_shadow_enabled(true)
				shadowed_count += 1
			else:
				# Over shadow budget - disable shadows but keep light
				proxy.set_shadow_enabled(false)
			near_count += 1
		else:
			mid_count += 1

		active_count += 1

	# Count FAR lights
	var far_count = building_lights.size() - active_count

	# Update stats
	stats.shadowed_count = shadowed_count
	stats.active_count = active_count
	stats.near_count = near_count
	stats.mid_count = mid_count
	stats.far_count = far_count

	# Emit signal for debug UI
	light_count_changed.emit(shadowed_count, active_count, building_lights.size())

	# Warn if we hit budget limits
	if active_count >= MAX_TOTAL_LIGHTS:
		budget_warning.emit("Light budget exceeded - %d lights forced to FAR" % far_count)

# ========================================================================
# TIME OF DAY INTEGRATION
# ========================================================================

## Called by LightingController when time changes
func on_time_changed(hour: float) -> void:
	var time_fade = _calculate_time_fade(hour)

	for proxy in building_lights:
		if is_instance_valid(proxy) and proxy.has_method("set_time_fade"):
			proxy.set_time_fade(time_fade)

## Calculate time fade factor (0.0 = day/off, 1.0 = night/full)
func _calculate_time_fade(hour: float) -> float:
	# Normalize hour to 0-24
	hour = fmod(hour, 24.0)
	if hour < 0:
		hour += 24.0

	# Night: full brightness (19:00 - 05:00)
	if hour >= 19.0 or hour <= 5.0:
		return 1.0
	# Evening transition: fade in (17:00 - 19:00)
	elif hour > 17.0 and hour < 19.0:
		return (hour - 17.0) / 2.0
	# Morning transition: fade out (05:00 - 06:00)
	elif hour > 5.0 and hour < 6.0:
		return 1.0 - (hour - 5.0)
	# Day: off
	else:
		return 0.0

# ========================================================================
# DEBUG / STATS
# ========================================================================

## Get current stats for debug display
func get_stats() -> Dictionary:
	return stats.duplicate()

## Get tier name for display
static func get_tier_name(tier: int) -> String:
	match tier:
		LODTier.NEAR: return "NEAR"
		LODTier.MID: return "MID"
		LODTier.FAR: return "FAR"
		_: return "UNKNOWN"
