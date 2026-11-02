
extends Node

var controller: Control
var game_library: Node
var steam_manager: RefCounted

var game_options: VBoxContainer
var all_games_entry: Control

var all_games_open: bool = false
var all_games_labels: Array[Control] = []


func initialise(
	main_controller: Control,
	main_game_library: Node,
	main_steam_manager: RefCounted,
	main_game_options: VBoxContainer,
	main_all_games_entry: Control
) -> void:
	controller = main_controller
	game_library = main_game_library
	steam_manager = main_steam_manager
	game_options = main_game_options
	all_games_entry = main_all_games_entry


# --------------------------------------------------
# GAME ENTRY CREATION
# --------------------------------------------------

func create_game_entry(game: Dictionary) -> Control:
	var entry := Control.new()
	entry.name = "Game_" + str(game["appid"])
	entry.custom_minimum_size = Vector2(400, 110)

	var logo := TextureRect.new()
	logo.name = "Logo"
	logo.position = Vector2.ZERO
	logo.size = Vector2(128, 128)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var home: String = OS.get_environment("HOME")

	var library_path: String = home.path_join(
		".steam/steam/appcache/librarycache/" + str(game["appid"])
	)

	var artwork_files: Array[String] = [
		"logo.png",
		"library_capsule.jpg",
		"library_header.jpg",
		"library_hero.jpg"
	]

	var artwork_paths: Array[String] = []

	for artwork in artwork_files:
		var direct_path: String = library_path.path_join(artwork)

		if FileAccess.file_exists(direct_path):
			artwork_paths.append(direct_path)

	var dir := DirAccess.open(library_path)

	if dir != null:
		dir.list_dir_begin()
		var folder: String = dir.get_next()

		while folder != "":
			if dir.current_is_dir() and not folder.begins_with("."):
				for artwork in artwork_files:
					var candidate: String = (
						library_path.path_join(folder).path_join(artwork)
					)

					if FileAccess.file_exists(candidate):
						artwork_paths.append(candidate)

			folder = dir.get_next()

		dir.list_dir_end()

	for artwork_path in artwork_paths:
		var image := Image.new()
		var error: Error = image.load(artwork_path)

		if error == OK and not image.is_empty():
			logo.texture = ImageTexture.create_from_image(image)
			break

	entry.add_child(logo)

	var game_name := Label.new()
	game_name.name = "Name"
	game_name.text = str(game["name"])
	game_name.position = Vector2(175, 30)
	game_name.size = Vector2(220, 40)

	entry.add_child(game_name)

	return entry


# --------------------------------------------------
# INSTALLED GAMES
# --------------------------------------------------

func populate_game_options() -> void:
	for child in game_options.get_children():
		if child != all_games_entry:
			game_options.remove_child(child)
			child.queue_free()

	if all_games_entry.get_parent() != game_options:
		game_options.add_child(all_games_entry)

	game_options.move_child(all_games_entry, 0)

	for game in game_library.get_installed_games():
		game_options.add_child(create_game_entry(game))

	if controller.get_current_category_name() == "GameCategory":
		controller.update_current_options()
		controller.update_selection_display()


func activate_game_entry(entry: Control) -> void:
	if entry.name == "AllGames":
		open_all_games()
		return

	if entry.name.begins_with("Game_"):
		var appid_text: String = entry.name.trim_prefix("Game_")
		steam_manager.launch_game(int(appid_text))


# --------------------------------------------------
# ALL GAMES
# --------------------------------------------------

func populate_all_games_list() -> void:
	for child in game_options.get_children():
		if child != all_games_entry:
			game_options.remove_child(child)
			child.queue_free()

	all_games_labels.clear()

	var games: Array[Dictionary] = game_library.get_all_games()

	for game in games:
		var appid: String = str(game["appid"])

		if not await game_library.is_game_app(appid):
			continue

		var game_name: String = str(game["name"])

		if game_name.begins_with("App "):
			game_name = await game_library.resolve_game_name(appid)

		var named_game: Dictionary = game.duplicate()
		named_game["name"] = game_name

		var entry: Control = create_game_entry(named_game)

		game_options.add_child(entry)
		all_games_labels.append(entry)

	controller.selected_option = 0


func open_all_games() -> void:
	all_games_open = true
	controller.selected_option = 0

	if all_games_entry.get_parent() == game_options:
		game_options.remove_child(all_games_entry)

	await populate_all_games_list()

	if all_games_labels.is_empty():
		close_all_games()
		return

	controller.update_selection_display()


func close_all_games() -> void:
	all_games_open = false
	all_games_labels.clear()
	controller.selected_option = 0

	populate_game_options()
	controller.update_selection_display()
