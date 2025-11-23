extends Node

func create_brick_texture() -> ImageTexture:
	var img = Image.create(32, 32, false, Image.FORMAT_RGB8)

	# Base brick colors with more variation
	var brick_base = Color(0.6, 0.3, 0.2)
	var brick_light = Color(0.68, 0.35, 0.24)
	var brick_dark = Color(0.52, 0.25, 0.16)
	var brick_reddish = Color(0.65, 0.28, 0.18)
	var mortar_color = Color(0.7, 0.7, 0.6)
	var mortar_dark = Color(0.65, 0.65, 0.55)

	for y in range(32):
		for x in range(32):
			var color = brick_base

			# Mortar lines (horizontal)
			if y % 8 == 0 or y % 8 == 1:
				# Add variation to mortar
				if (x + y) % 5 == 0:
					color = mortar_dark
				else:
					color = mortar_color
			# Mortar lines (vertical, offset every other row)
			elif int(y / 8.0) % 2 == 0:
				if x % 16 == 0 or x % 16 == 1:
					if (x + y) % 5 == 0:
						color = mortar_dark
					else:
						color = mortar_color
			else:
				if (x + 8) % 16 == 0 or (x + 8) % 16 == 1:
					if (x + y) % 5 == 0:
						color = mortar_dark
					else:
						color = mortar_color

			# Add variation to individual bricks
			if color == brick_base:
				var brick_id = int(x / 16.0) + int(y / 8.0) * 2
				if brick_id % 5 == 0:
					color = brick_light
				elif brick_id % 5 == 1:
					color = brick_dark
				elif brick_id % 5 == 2:
					color = brick_reddish

				# Add subtle weathering/texture within bricks
				if (x % 4 == 0 and y % 3 == 0) or (x % 5 == 2 and y % 4 == 1):
					color = color.darkened(0.1)
				elif (x % 6 == 3 and y % 5 == 2):
					color = color.lightened(0.08)

			img.set_pixel(x, y, color)

	return ImageTexture.create_from_image(img)

func create_wood_texture() -> ImageTexture:
	var img = Image.create(32, 32, false, Image.FORMAT_RGB8)

	var wood_base = Color(0.4, 0.25, 0.15)
	var wood_dark = Color(0.3, 0.18, 0.1)
	var wood_light = Color(0.5, 0.32, 0.2)

	for y in range(32):
		for x in range(32):
			var color = wood_base

			# Wood grain lines
			if x % 8 < 2:
				color = wood_dark
			elif x % 8 == 3:
				color = wood_light

			# Knots
			if (x - 16) * (x - 16) + (y - 10) * (y - 10) < 9:
				color = wood_dark

			img.set_pixel(x, y, color)

	return ImageTexture.create_from_image(img)

func create_floor_texture() -> ImageTexture:
	var img = Image.create(32, 32, false, Image.FORMAT_RGB8)

	var tile_base = Color(0.65, 0.55, 0.45)
	var tile_dark = Color(0.55, 0.45, 0.35)
	var grout = Color(0.5, 0.5, 0.5)

	for y in range(32):
		for x in range(32):
			var color = tile_base

			# Tile grid
			if x % 16 == 0 or y % 16 == 0:
				color = grout
			# Variation in tiles
			elif (int(x / 16.0) + int(y / 16.0)) % 2 == 0:
				color = tile_dark

			img.set_pixel(x, y, color)

	return ImageTexture.create_from_image(img)

func create_grass_texture() -> ImageTexture:
	var img = Image.create(32, 32, false, Image.FORMAT_RGB8)

	var grass_base = Color(0.3, 0.45, 0.25)
	var grass_dark = Color(0.25, 0.38, 0.2)
	var grass_light = Color(0.35, 0.5, 0.3)

	for y in range(32):
		for x in range(32):
			var rand_val = (x * 7 + y * 13) % 5
			var color = grass_base

			if rand_val == 0:
				color = grass_dark
			elif rand_val == 1:
				color = grass_light

			img.set_pixel(x, y, color)

	return ImageTexture.create_from_image(img)

func create_window_texture() -> ImageTexture:
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)

	var frame = Color(0.3, 0.25, 0.2, 1.0)
	var glass = Color(0.6, 0.8, 0.9, 0.7)
	var reflection = Color(0.9, 0.95, 1.0, 0.9)

	for y in range(16):
		for x in range(16):
			var color = glass

			# Frame
			if x < 2 or x > 13 or y < 2 or y > 13:
				color = frame
			# Cross divider
			elif x == 7 or x == 8 or y == 7 or y == 8:
				color = frame
			# Reflection
			elif x < 6 and y < 6:
				color = reflection

			img.set_pixel(x, y, color)

	return ImageTexture.create_from_image(img)
