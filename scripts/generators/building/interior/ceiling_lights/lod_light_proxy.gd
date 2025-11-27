extends Node3D
class_name LODLightProxy

## LOD Light Proxy
##
## Wraps an OmniLight3D with LOD state management. The actual light node
## is created/destroyed based on the current LOD tier to minimize active
## light count in the scene.
##
## Tiers:
##   NEAR (0): Full quality with shadows
##   MID (1):  No shadows, reduced energy/range
##   FAR (2):  No dynamic light, emissive materials only

# ========================================================================
# LOD TIERS (mirror LightingLODManager.LODTier)
# ========================================================================

enum LODTier {
	NEAR = 0,
	MID = 1,
	FAR = 2
}

# ========================================================================
# CONFIGURATION
# ========================================================================

## Transition timing
const TRANSITION_SPEED := 3.0  ## Complete transition in ~0.33 seconds

## Energy multipliers per tier
const NEAR_ENERGY_MULT := 1.0
const MID_ENERGY_MULT := 0.85  ## Keep MID visible (was 0.6)

## Range multiplier for MID tier
const MID_RANGE_MULT := 1.0  ## Keep full range for MID (was 0.8)

# ========================================================================
# STATE
# ========================================================================

## The actual OmniLight3D (created/destroyed based on LOD)
var omni_light: OmniLight3D

## Current LOD tier
var current_tier: int = LODTier.FAR  ## Start at FAR (no light created)

## Transition state
var is_transitioning: bool = false
var transition_progress: float = 1.0
var previous_tier: int = LODTier.FAR

## Reference to LOD manager (set during registration)
var lod_manager = null

## Base light parameters (preserved for tier restoration)
var base_energy: float = 10.0  ## Match ceiling_light_generator default
var base_range: float = 40.0   ## Larger range for city coverage
var base_color: Color = Color(1.0, 0.95, 0.85)  ## Warm white default
var base_attenuation: float = 1.0

## Time fade factor (0.0 = day/off, 1.0 = night/full)
var time_fade: float = 1.0

## Shadow state (can be disabled by budget enforcement)
var _shadow_enabled: bool = true

# ========================================================================
# INITIALIZATION
# ========================================================================

func _init():
	pass

## Initialize with light parameters
func setup(energy: float, range_val: float, color: Color, attenuation: float = 1.0) -> void:
	base_energy = energy
	base_range = range_val
	base_color = color
	base_attenuation = attenuation

func _ready():
	# Auto-register with LOD manager if found
	_find_and_register_with_manager()

func _exit_tree():
	# Unregister when removed from scene
	if lod_manager and lod_manager.has_method("unregister_building_light"):
		lod_manager.unregister_building_light(self)

## Find LOD manager in scene and register
func _find_and_register_with_manager() -> void:
	# Try to find LightingLODManager in the scene
	var root = get_tree().root if get_tree() else null
	if not root:
		return

	# Search for LightingLODManager
	var manager = _find_node_by_class(root, "LightingLODManager")
	if manager:
		lod_manager = manager
		manager.register_building_light(self)

## Recursive search for node by class name
func _find_node_by_class(node: Node, class_name_str: String) -> Node:
	if node.get_class() == class_name_str or (node.get_script() and node.get_script().get_global_name() == class_name_str):
		return node

	for child in node.get_children():
		var found = _find_node_by_class(child, class_name_str)
		if found:
			return found

	return null

# ========================================================================
# LOD TIER CONTROL
# ========================================================================

## Set LOD tier (called by LightingLODManager)
func set_lod_tier(new_tier: int, immediate: bool = false) -> void:
	if new_tier == current_tier:
		return

	previous_tier = current_tier
	current_tier = new_tier

	if immediate:
		transition_progress = 1.0
		_apply_tier_state()
	else:
		transition_progress = 0.0
		is_transitioning = true
		set_process(true)

## Enable/disable shadow (budget-controlled by LODManager)
func set_shadow_enabled(enabled: bool) -> void:
	_shadow_enabled = enabled
	if omni_light:
		omni_light.shadow_enabled = enabled and (current_tier == LODTier.NEAR)

## Set time fade factor (from LightingController via LODManager)
func set_time_fade(fade: float) -> void:
	time_fade = clamp(fade, 0.0, 1.0)
	_update_light_energy()

# ========================================================================
# PROCESS (only enabled during transitions)
# ========================================================================

func _process(delta: float) -> void:
	if not is_transitioning:
		set_process(false)
		return

	transition_progress = min(1.0, transition_progress + delta * TRANSITION_SPEED)
	_update_transition()

	if transition_progress >= 1.0:
		is_transitioning = false
		_apply_tier_state()
		set_process(false)

# ========================================================================
# TRANSITION HANDLING
# ========================================================================

## Update during transition (smooth energy fade)
func _update_transition() -> void:
	var start_energy = _get_tier_energy(previous_tier)
	var end_energy = _get_tier_energy(current_tier)

	# Handle light creation/destruction at transition midpoint
	if transition_progress > 0.5:
		if current_tier == LODTier.FAR and omni_light:
			# FAR tier - destroy light
			omni_light.queue_free()
			omni_light = null
		elif current_tier != LODTier.FAR and not omni_light:
			# NEAR/MID tier - create light
			_create_omni_light()

	# Update energy during transition
	if omni_light:
		var current_energy = lerp(start_energy, end_energy, transition_progress)
		omni_light.light_energy = current_energy * time_fade

## Apply final state for current tier
func _apply_tier_state() -> void:
	match current_tier:
		LODTier.NEAR:
			if not omni_light:
				_create_omni_light()
			omni_light.shadow_enabled = _shadow_enabled
			omni_light.omni_range = base_range
		LODTier.MID:
			if not omni_light:
				_create_omni_light()
			omni_light.shadow_enabled = false
			omni_light.omni_range = base_range * MID_RANGE_MULT
		LODTier.FAR:
			if omni_light:
				omni_light.queue_free()
				omni_light = null

	_update_light_energy()

# ========================================================================
# ENERGY CALCULATION
# ========================================================================

## Get energy for a specific tier (before time fade)
func _get_tier_energy(tier: int) -> float:
	match tier:
		LODTier.NEAR:
			return base_energy * NEAR_ENERGY_MULT
		LODTier.MID:
			return base_energy * MID_ENERGY_MULT
		LODTier.FAR:
			return 0.0
	return 0.0

## Update light energy based on tier and time fade
func _update_light_energy() -> void:
	if omni_light:
		omni_light.light_energy = _get_tier_energy(current_tier) * time_fade

# ========================================================================
# LIGHT CREATION
# ========================================================================

## Create the OmniLight3D node
func _create_omni_light() -> void:
	omni_light = OmniLight3D.new()
	omni_light.name = "OmniLight"

	# Basic properties
	omni_light.light_color = base_color
	omni_light.light_energy = _get_tier_energy(current_tier) * time_fade
	omni_light.omni_range = base_range
	omni_light.omni_attenuation = base_attenuation

	# Shadow properties (only enabled for NEAR tier)
	omni_light.shadow_enabled = _shadow_enabled and (current_tier == LODTier.NEAR)
	omni_light.shadow_opacity = 1.0
	omni_light.shadow_blur = 1.5
	omni_light.shadow_normal_bias = 2.0
	omni_light.shadow_bias = 0.1

	add_child(omni_light)

# ========================================================================
# DEBUG
# ========================================================================

## Get tier name for debugging
func get_tier_name() -> String:
	match current_tier:
		LODTier.NEAR: return "NEAR"
		LODTier.MID: return "MID"
		LODTier.FAR: return "FAR"
		_: return "UNKNOWN"
