extends Node
class_name WindowSystem

## Window system coordinator
## Generates complete windows (reveal + glass + frame)

const RevealGenerator = preload("res://scripts/generators/building/windows/components/reveal_generator.gd")
const GlassGenerator = preload("res://scripts/generators/building/windows/components/glass_generator.gd")
const FrameGenerator = preload("res://scripts/generators/building/windows/components/frame_generator.gd")
const EmissionController = preload("res://scripts/generators/building/windows/features/emission_controller.gd")

## Add a complete window (reveal + glass + frame)
## If emission_color is not provided, generates one automatically
static func add_window(
	p1: Vector2, p2: Vector2,
	window_left_t: float, window_right_t: float,
	window_bottom: float, window_top: float,
	wall_normal: Vector3,
	wall_surface,
	glass_surface,
	frame_surface,
	emission_color: Color = Color.BLACK  # Optional pre-generated emission
) -> Color:
	# Add window reveal (goes to wall surface - shows wall thickness)
	RevealGenerator.add_window_reveal(
		p1, p2,
		window_left_t, window_right_t,
		window_bottom, window_top,
		wall_normal,
		wall_surface.vertices,
		wall_surface.normals,
		wall_surface.uvs,
		wall_surface.indices
	)

	# Generate emission color if not provided
	if emission_color == Color.BLACK:
		emission_color = EmissionController.generate_window_emission()

	# Add window glass (goes to glass surface)
	GlassGenerator.add_window_glass(
		p1, p2,
		window_left_t, window_right_t,
		window_bottom, window_top,
		wall_normal,
		glass_surface.vertices,
		glass_surface.normals,
		glass_surface.uvs,
		glass_surface.colors,
		glass_surface.indices,
		emission_color
	)

	# Add window frame (goes to frame surface)
	FrameGenerator.add_window_frame(
		p1, p2,
		window_left_t, window_right_t,
		window_bottom, window_top,
		wall_normal,
		frame_surface.vertices,
		frame_surface.normals,
		frame_surface.uvs,
		frame_surface.indices
	)

	return emission_color  # Return the emission for tracking
