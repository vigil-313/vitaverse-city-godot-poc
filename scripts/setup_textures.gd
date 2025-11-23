extends Node3D

func _ready():
	call_deferred("setup_everything")

func setup_everything():
	setup_building_textures()
	setup_environment_colors()
	print("✅ Textures and colors applied!")

func setup_building_textures():
	var cafe = get_node_or_null("CafeBuilding")
	if not cafe:
		push_error("CafeBuilding not found!")
		return

	var brick_tex = TextureGenerator.create_brick_texture()
	var wood_tex = TextureGenerator.create_wood_texture()
	var floor_tex = TextureGenerator.create_floor_texture()
	var window_tex = TextureGenerator.create_window_texture()
	var grass_tex = TextureGenerator.create_grass_texture()

	# Apply textures to cafe building
	apply_texture_to_node(cafe, "Exterior/BackWall", brick_tex, Color(1, 1, 1))
	apply_texture_to_node(cafe, "Exterior/LeftWall", brick_tex, Color(1, 1, 1))
	apply_texture_to_node(cafe, "Exterior/RightWall", brick_tex, Color(1, 1, 1))
	apply_texture_to_node(cafe, "Exterior/FrontWallLeft", brick_tex, Color(1, 1, 1))
	apply_texture_to_node(cafe, "Exterior/FrontWallRight", brick_tex, Color(1, 1, 1))
	apply_texture_to_node(cafe, "Exterior/FrontWallTop", brick_tex, Color(1, 1, 1))

	apply_texture_to_node(cafe, "Exterior/Floor", floor_tex, Color(1, 1, 1))
	apply_texture_to_node(cafe, "Interior/Counter", wood_tex, Color(0.8, 0.6, 0.4))
	apply_texture_to_node(cafe, "Interior/Table1", wood_tex, Color(0.9, 0.7, 0.5))
	apply_texture_to_node(cafe, "Interior/Table2", wood_tex, Color(0.9, 0.7, 0.5))
	apply_texture_to_node(cafe, "Door/DoorMesh", wood_tex, Color(0.6, 0.4, 0.3))

	apply_texture_to_node(cafe, "Exterior/Window1", window_tex, Color(1, 1, 1))
	apply_texture_to_node(cafe, "Exterior/Window2", window_tex, Color(1, 1, 1))
	apply_texture_to_node(cafe, "Exterior/Window3", window_tex, Color(1, 1, 1))
	apply_texture_to_node(cafe, "Exterior/Window4", window_tex, Color(1, 1, 1))

	# Apply textures to shop building
	var shop = get_node_or_null("ShopBuilding")
	if shop:
		apply_texture_to_node(shop, "Exterior/BackWall", brick_tex, Color(0.35, 0.4, 0.5))
		apply_texture_to_node(shop, "Exterior/LeftWall", brick_tex, Color(0.35, 0.4, 0.5))
		apply_texture_to_node(shop, "Exterior/RightWall", brick_tex, Color(0.35, 0.4, 0.5))
		apply_texture_to_node(shop, "Exterior/FrontWallLeft", brick_tex, Color(0.35, 0.4, 0.5))
		apply_texture_to_node(shop, "Exterior/FrontWallRight", brick_tex, Color(0.35, 0.4, 0.5))
		apply_texture_to_node(shop, "Exterior/FrontWallTop", brick_tex, Color(0.35, 0.4, 0.5))
		apply_texture_to_node(shop, "Exterior/Floor", floor_tex, Color(0.35, 0.4, 0.5))
		apply_texture_to_node(shop, "Exterior/Roof", brick_tex, Color(0.35, 0.4, 0.5))
		apply_texture_to_node(shop, "Exterior/Door", wood_tex, Color(0.45, 0.3, 0.2))
		apply_texture_to_node(shop, "Exterior/Window1", window_tex, Color(1, 1, 1))
		apply_texture_to_node(shop, "Exterior/Window2", window_tex, Color(1, 1, 1))

	# Ground texture
	var ground = get_node_or_null("Ground/MeshInstance3D")
	if ground:
		var mat = StandardMaterial3D.new()
		mat.albedo_texture = grass_tex
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.uv1_scale = Vector3(10, 10, 10)
		ground.material_override = mat

func setup_environment_colors():
	# Make trees blocky and green
	set_node_color("CityProps/Tree1/Trunk", Color(0.35, 0.22, 0.15))
	set_node_color("CityProps/Tree1/Leaves", Color(0.2, 0.6, 0.25))
	set_node_color("CityProps/Tree1/LeavesMid", Color(0.25, 0.65, 0.3))
	set_node_color("CityProps/Tree1/LeavesTop", Color(0.3, 0.7, 0.35))
	set_node_color("CityProps/Tree2/Trunk", Color(0.35, 0.22, 0.15))
	set_node_color("CityProps/Tree2/Leaves", Color(0.2, 0.6, 0.25))
	set_node_color("CityProps/Tree2/LeavesMid", Color(0.25, 0.65, 0.3))
	set_node_color("CityProps/Tree2/LeavesTop", Color(0.3, 0.7, 0.35))
	set_node_color("CityProps/Tree3/Trunk", Color(0.35, 0.22, 0.15))
	set_node_color("CityProps/Tree3/Leaves", Color(0.2, 0.6, 0.25))
	set_node_color("CityProps/Tree3/LeavesMid", Color(0.25, 0.65, 0.3))
	set_node_color("CityProps/Tree3/LeavesTop", Color(0.3, 0.7, 0.35))
	set_node_color("CityProps/Tree4/Trunk", Color(0.35, 0.22, 0.15))
	set_node_color("CityProps/Tree4/Leaves", Color(0.2, 0.6, 0.25))
	set_node_color("CityProps/Tree4/LeavesMid", Color(0.25, 0.65, 0.3))
	set_node_color("CityProps/Tree4/LeavesTop", Color(0.3, 0.7, 0.35))

	# Bushes
	set_node_color("CityProps/Bush1", Color(0.25, 0.55, 0.3))
	set_node_color("CityProps/Bush2", Color(0.25, 0.55, 0.3))
	set_node_color("CityProps/Bush3", Color(0.3, 0.6, 0.35))
	set_node_color("CityProps/Bush4", Color(0.3, 0.6, 0.35))

	# Planters
	set_node_color("CityProps/Planter1/PlanterBase", Color(0.45, 0.3, 0.25))
	set_node_color("CityProps/Planter1/Plant", Color(0.2, 0.65, 0.3))
	set_node_color("CityProps/Planter2/PlanterBase", Color(0.45, 0.3, 0.25))
	set_node_color("CityProps/Planter2/Plant", Color(0.2, 0.65, 0.3))

	# Lamp posts
	set_node_color("CityProps/StreetLamp1/Pole", Color(0.2, 0.2, 0.2))
	set_node_color("CityProps/StreetLamp1/LampHead", Color(0.9, 0.9, 0.7))
	set_node_color("CityProps/StreetLamp2/Pole", Color(0.2, 0.2, 0.2))
	set_node_color("CityProps/StreetLamp2/LampHead", Color(0.9, 0.9, 0.7))

	# Street
	set_node_color("Street", Color(0.3, 0.3, 0.3))
	set_node_color("Street/StreetLine1", Color(0.9, 0.9, 0.9))
	set_node_color("Street/StreetLine2", Color(0.9, 0.9, 0.9))
	set_node_color("Street/StreetLine3", Color(0.9, 0.9, 0.9))
	set_node_color("Sidewalk", Color(0.5, 0.5, 0.5))

	# Cafe decorations
	var cafe = get_node_or_null("CafeBuilding")
	if cafe:
		set_node_color_direct(cafe.get_node("Decorations/WindowBox1/Flowers1"), Color(0.9, 0.3, 0.4))
		set_node_color_direct(cafe.get_node("Decorations/WindowBox2/Flowers2"), Color(0.9, 0.3, 0.4))
		set_node_color_direct(cafe.get_node("Decorations/WindowBox3/Flowers3"), Color(0.8, 0.2, 0.5))
		set_node_color_direct(cafe.get_node("Decorations/WindowBox4/Flowers4"), Color(0.8, 0.2, 0.5))
		set_node_color_direct(cafe.get_node("Decorations/CafeSign/SignText1"), Color(0.1, 0.1, 0.1))
		set_node_color_direct(cafe.get_node("Decorations/CafeSign/SignText2"), Color(0.1, 0.1, 0.1))
		set_node_color_direct(cafe.get_node("Decorations/CafeSign/SignText3"), Color(0.1, 0.1, 0.1))
		set_node_color_direct(cafe.get_node("Decorations/CafeSign/SignText4"), Color(0.1, 0.1, 0.1))
		set_node_color_direct(cafe.get_node("Door/DoorMesh/DoorHandle"), Color(0.8, 0.7, 0.3))

func set_node_color(path: String, color: Color):
	var node = get_node_or_null(path)
	if node and node is GeometryInstance3D:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = color
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.roughness = 0.9
		node.material_override = mat

func set_node_color_direct(node: Node, color: Color):
	if node and node is GeometryInstance3D:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = color
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.roughness = 0.9
		node.material_override = mat

func apply_texture_to_node(parent: Node, path: String, texture: Texture2D, tint: Color = Color(1, 1, 1)):
	var node = parent.get_node_or_null(path)
	if node and node is GeometryInstance3D:
		var mat = StandardMaterial3D.new()
		mat.albedo_texture = texture
		mat.albedo_color = tint
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.roughness = 0.9
		mat.uv1_scale = Vector3(2, 2, 2)
		node.material_override = mat
	else:
		push_warning("Node not found: " + path)
