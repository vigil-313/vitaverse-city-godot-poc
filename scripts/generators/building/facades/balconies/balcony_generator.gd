extends Node
class_name BalconyGenerator

## Balcony generator coordinator
## Creates balconies for residential buildings with slabs, railings, and brackets

const BalconySlab = preload("res://scripts/generators/building/facades/balconies/balcony_slab.gd")
const RailingGenerator = preload("res://scripts/generators/building/facades/balconies/railing_generator.gd")
const GlassPanel = preload("res://scripts/generators/building/facades/balconies/glass_panel.gd")
const BracketGenerator = preload("res://scripts/generators/building/facades/balconies/bracket_generator.gd")
const GeometryUtils = preload("res://scripts/generators/building/core/geometry_utils.gd")

## Balcony dimensions
const BALCONY_DEPTH = 1.2      # 1.2m projection from wall
const BALCONY_WIDTH = 2.5      # 2.5m wide
const SLAB_THICKNESS = 0.15    # 15cm thick floor slab
const RAILING_HEIGHT = 1.1     # 1.1m railing height

## Placement parameters
const MIN_WALL_LENGTH = 4.0    # Minimum wall length for balconies
const BALCONY_CHANCE = 0.6     # 60% chance per eligible position
const FLOOR_SPACING = 2        # Balcony every N floors (alternating)

## Main entry point - generates balconies for residential building
static func generate(context, surfaces: Dictionary, wall_segments: Array) -> void:
	if context.levels <= 1:  # Need at least 2 floors
		return

	var wall_surface = surfaces["wall"]
	var glass_surface = surfaces["glass"]
	var frame_surface = surfaces["frame"]

	# Determine railing style based on building ID (consistent per building)
	var use_glass_railings = (context.building_id % 3) == 0  # ~33% modern glass

	# Process each wall segment
	for segment in wall_segments:
		if segment.length < MIN_WALL_LENGTH:
			continue

		# Generate balconies on upper floors
		for floor_num in range(1, context.levels):  # Skip ground floor
			# Alternating pattern - balconies every other floor
			if floor_num % FLOOR_SPACING != 1:
				continue

			# Random chance for this balcony
			var seed_val = context.building_id * 1000 + segment.index * 100 + floor_num
			var rng = RandomNumberGenerator.new()
			rng.seed = seed_val
			if rng.randf() > BALCONY_CHANCE:
				continue

			_generate_balcony(
				segment,
				floor_num,
				context,
				wall_surface,
				glass_surface,
				frame_surface,
				use_glass_railings
			)

## Generate a single balcony
static func _generate_balcony(
	segment: Dictionary,
	floor_num: int,
	context,
	wall_surface,
	glass_surface,
	frame_surface,
	use_glass_railings: bool
) -> void:
	var p1 = segment.p1
	var p2 = segment.p2
	var wall_normal = segment.normal
	var wall_length = segment.length

	# Calculate balcony position (centered on wall)
	var balcony_width = min(BALCONY_WIDTH, wall_length * 0.6)
	var balcony_center_t = 0.5
	var balcony_half_width_t = (balcony_width / 2.0) / wall_length

	var balcony_left_t = balcony_center_t - balcony_half_width_t
	var balcony_right_t = balcony_center_t + balcony_half_width_t

	# Calculate positions
	var left_pos = p1.lerp(p2, balcony_left_t)
	var right_pos = p1.lerp(p2, balcony_right_t)

	# Floor height
	var floor_bottom = floor_num * context.floor_height
	var balcony_floor_y = floor_bottom + 0.1  # Slight offset above floor line

	# Generate balcony slab
	BalconySlab.generate(
		left_pos, right_pos,
		balcony_floor_y,
		BALCONY_DEPTH,
		SLAB_THICKNESS,
		wall_normal,
		wall_surface
	)

	# Generate railings
	if use_glass_railings:
		GlassPanel.generate(
			left_pos, right_pos,
			balcony_floor_y,
			BALCONY_DEPTH,
			RAILING_HEIGHT,
			wall_normal,
			glass_surface,
			frame_surface
		)
	else:
		RailingGenerator.generate(
			left_pos, right_pos,
			balcony_floor_y,
			BALCONY_DEPTH,
			RAILING_HEIGHT,
			wall_normal,
			frame_surface
		)

	# Generate support brackets
	BracketGenerator.generate(
		left_pos, right_pos,
		balcony_floor_y,
		BALCONY_DEPTH,
		wall_normal,
		wall_surface
	)
