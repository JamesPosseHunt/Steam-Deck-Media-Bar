extends Node

signal wallpaper_changed(texture: Texture2D)

const CONFIG_PATH := "user://wallpaper.cfg"

var current_wallpaper: Texture2D


func set_wallpaper(image_path: String) -> void:
	var image: Image = ImageLoader.load_image_file(image_path)

	if image == null:
		push_warning("Could not load wallpaper: " + image_path)
		return

	current_wallpaper = ImageTexture.create_from_image(image)

	var config := ConfigFile.new()
	config.set_value("wallpaper", "path", image_path)

	var save_error: Error = config.save(CONFIG_PATH)

	if save_error != OK:
		push_error("Could not save wallpaper settings. Error: " + str(save_error))
	else:
		print("Wallpaper settings saved: ", image_path)

	wallpaper_changed.emit(current_wallpaper)

func load_wallpaper() -> void:
	var config := ConfigFile.new()

	if config.load(CONFIG_PATH) != OK:
		return

	var image_path: String = config.get_value(
		"wallpaper",
		"path",
		""
	)

	if image_path.is_empty():
		return

	var image: Image = ImageLoader.load_image_file(image_path)

	if image == null:
		push_warning("Could not load saved wallpaper.")
		return

	current_wallpaper = ImageTexture.create_from_image(image)
	wallpaper_changed.emit(current_wallpaper)
