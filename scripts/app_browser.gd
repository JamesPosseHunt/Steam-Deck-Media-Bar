
extends Node

var controller: Control
var app_library: Node
var app_options: VBoxContainer


func initialise(
	main_controller: Control,
	main_app_library: Node,
	main_app_options: VBoxContainer
) -> void:
	controller = main_controller
	app_library = main_app_library
	app_options = main_app_options


func populate_app_options() -> void:
	for child in app_options.get_children():
		child.queue_free()

	var apps: Array[Dictionary] = app_library.get_installed_apps()

	for app in apps:
		var entry := create_app_entry(app)
		app_options.add_child(entry)

	if controller.get_current_category_name() == "AppCategory":
		controller.update_current_options()
		controller.update_selection_display()


func create_app_entry(app: Dictionary) -> Control:
	var entry := Control.new()
	entry.name = "App_" + str(app["name"]).validate_node_name()
	entry.custom_minimum_size = Vector2(0, 80)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.position = Vector2(0, 5)
	icon.size = Vector2(70, 70)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var icon_path: String = str(app["icon"])
	icon.texture = find_app_icon(icon_path)

	if icon_path.begins_with("/") and FileAccess.file_exists(icon_path):
		var image := Image.new()

		if image.load(icon_path) == OK:
			icon.texture = ImageTexture.create_from_image(image)

	elif not icon_path.is_empty():
		var pixmap_path := "/usr/share/pixmaps".path_join(icon_path)

		if FileAccess.file_exists(pixmap_path):
			var image := Image.new()

			if image.load(pixmap_path) == OK:
				icon.texture = ImageTexture.create_from_image(image)

	entry.add_child(icon)

	var app_name := Label.new()
	app_name.name = "Name"
	app_name.text = str(app["name"])
	app_name.position = Vector2(90, 0)
	app_name.size = Vector2(400, 80)
	app_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	entry.add_child(app_name)

	return entry


func find_app_icon(icon_name: String) -> Texture2D:
	if icon_name.is_empty():
		return null

	# If the desktop file provides an absolute path.
	if icon_name.begins_with("/"):
		if FileAccess.file_exists(icon_name):
			return load_icon_texture(icon_name)

		return null

	var icon_directories: Array[String] = [
		"/usr/share/icons",
		"/usr/local/share/icons",
		"/usr/share/pixmaps",
		OS.get_environment("HOME").path_join(".local/share/icons"),
		OS.get_environment("HOME").path_join(".icons")
	]

	var extensions: Array[String] = [
		".png",
		".svg",
		".xpm"
	]

	for directory in icon_directories:
		for extension in extensions:
			var matches := find_icon_files(
				directory,
				icon_name + extension
			)

			if not matches.is_empty():
				return load_icon_texture(matches[0])

	return null


func find_icon_files(directory_path: String, target_file: String) -> Array[String]:
	var matches: Array[String] = []
	var directory := DirAccess.open(directory_path)

	if directory == null:
		return matches

	directory.list_dir_begin()

	var item := directory.get_next()

	while item != "":
		var full_path := directory_path.path_join(item)

		if directory.current_is_dir():
			if not item.begins_with("."):
				matches.append_array(
					find_icon_files(full_path, target_file)
				)

		elif item == target_file:
			matches.append(full_path)

		item = directory.get_next()

	directory.list_dir_end()

	return matches


func load_icon_texture(path: String) -> Texture2D:
	var image := Image.new()
	var error := image.load(path)

	if error != OK:
		return null

	return ImageTexture.create_from_image(image)
