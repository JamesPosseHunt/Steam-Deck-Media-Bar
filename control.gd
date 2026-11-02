
extends Control

@onready var time_label: Label = $StatusBarBackground/StatusBar/TimeLabel
@onready var battery_label: Label = $StatusBarBackground/StatusBar/BatteryLabel
@onready var battery_icon: TextureRect = $StatusBarBackground/StatusBar/BatteryIcon
@onready var user_label: Label = $StatusBarBackground/StatusBar/UserLabel
@onready var user_pic: TextureRect = $StatusBarBackground/StatusBar/UserPic

@onready var category_bar: HFlowContainer = $CategoryBar
@onready var categories: Array = category_bar.get_children()

@onready var game_options: VBoxContainer = $CategoryBar/GameCategory/OptionsViewport/GameOptions
@onready var all_games_entry: Control = $CategoryBar/GameCategory/OptionsViewport/GameOptions/AllGames

@onready var steam_name_request: HTTPRequest = $SteamNameRequest

const GAME_NAME_CACHE_PATH := "user://steam_game_names.json"
const FOLDER_ICON_PATH := "res://assets/CarlyImage.png"

var game_library = preload("res://scripts/game_library.gd").new()
var system_info = preload("res://scripts/system_info.gd").new()
var steam_manager = preload("res://scripts/steam_manager.gd").new()

var battery_percentage: int = -1

var selected_category: int = 0
var selected_option: int = 0

var option_tween: Tween
var options_viewport: Control
var power_options: VBoxContainer
var power_labels: Array = []

var game_name_cache: Dictionary = {}

var all_games_open: bool = false
var all_games_labels: Array[Control] = []
var all_games_selected: int = 0

var power_confirmation: ConfirmationDialog
var pending_power_action: String = ""

var pictures_path: String = OS.get_environment("HOME").path_join("Pictures")
var current_image_path: String = ""

var image_path_history: Array[String] = []
var image_labels: Array[Control] = []
var image_selected: int = 0

var image_thumbnail_cache: Dictionary = {}

func _ready() -> void:
	setup_power_confirmation()

	steam_manager.steam_initialized.connect(_on_steam_initialized)
	steam_manager.avatar_loaded.connect(_on_steam_avatar_loaded)
	steam_manager.initialise_steam()

	selected_category = categories.find(
		category_bar.get_node("GameCategory")
	)

	update_current_options()
	update_category_selection()
	update_clock()
	update_option_selection()

	await get_tree().process_frame

	current_image_path = pictures_path
	populate_image_options()

	centre_selected_category()
	load_game_name_cache()
	populate_game_options()

func _input(event: InputEvent) -> void:
	if all_games_open:
		if event.is_action_pressed("ui_down"):
			if not all_games_labels.is_empty():
				all_games_selected = min(
					all_games_selected + 1,
					all_games_labels.size() - 1
				)
				update_all_games_selection()

			return

		elif event.is_action_pressed("ui_up"):
			if not all_games_labels.is_empty():
				all_games_selected = max(
					all_games_selected - 1,
					0
				)
				update_all_games_selection()

			return

		elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_cancel"):
			close_all_games()
			return

		elif event.is_action_pressed("ui_accept"):
			if not all_games_labels.is_empty():
				var selected_entry: Control = all_games_labels[all_games_selected]

				if selected_entry.name.begins_with("Game_"):
					var appid_text: String = selected_entry.name.trim_prefix("Game_")
					steam_manager.launch_game(int(appid_text))

			return

		return

	if categories[selected_category].name == "ImageCategory":
		if event.is_action_pressed("ui_down"):
			if not image_labels.is_empty():
				image_selected = min(
					image_selected + 1,
					image_labels.size() - 1
				)
				selected_option = image_selected
				update_image_selection()
			return

		elif event.is_action_pressed("ui_up"):
			if not image_labels.is_empty():
				image_selected = max(
					image_selected - 1,
					0
				)
				selected_option = image_selected
				update_image_selection()
			return

		elif event.is_action_pressed("ui_accept"):
			if not image_labels.is_empty():
				var selected_entry: Control = image_labels[image_selected]

				if selected_entry.name.begins_with("Folder_"):
					var folder_name: String = selected_entry.name.trim_prefix("Folder_")
					enter_image_folder(folder_name)
			return

		elif event.is_action_pressed("ui_cancel"):
			if not image_path_history.is_empty():
				go_back_image_folder()
			return

	if event.is_action_pressed("ui_right"):
		change_category(1)

	elif event.is_action_pressed("ui_left"):
		change_category(-1)

	elif event.is_action_pressed("ui_down"):
		if not power_labels.is_empty():
			selected_option = min(
				selected_option + 1,
				power_labels.size() - 1
			)

	elif event.is_action_pressed("ui_up"):
		if not power_labels.is_empty():
			selected_option = max(
				selected_option - 1,
				0
			)

	elif event.is_action_pressed("ui_accept"):
		if not power_labels.is_empty():
			var selected_entry: Control = power_labels[selected_option]
			var current_category: String = str(categories[selected_category].name)

			match current_category:
				"GameCategory":
					if selected_entry.name == "AllGames":
						open_all_games()
						return

					elif selected_entry.name.begins_with("Game_"):
						var appid_text: String = selected_entry.name.trim_prefix("Game_")
						steam_manager.launch_game(int(appid_text))

				"PowerCategory":
					activate_power_option()

	update_option_selection()

func change_category(direction: int) -> void:
	if categories.is_empty():
		return

	selected_category = (
		selected_category + direction + categories.size()
	) % categories.size()

	update_current_options()
	update_category_selection()
	position_options_under_category()
	centre_selected_category()
	update_option_selection()

func update_category_selection() -> void:
	for i in range(categories.size()):
		var category: Control = categories[i]
		var icon: TextureRect = category.get_node("Icon")
		var options: Control = category.get_node("OptionsViewport")

		if i == selected_category:
			icon.scale = Vector2(1.5, 1.5)
			options.show()
		else:
			icon.scale = Vector2.ONE
			options.hide()

func centre_selected_category() -> void:
	var category: Control = categories[selected_category]

	var category_centre_x: float = (
		category.global_position.x + category.size.x / 2.0
	)

	var viewport_centre_x: float = (
		get_viewport_rect().size.x / 2.0
	)

	category_bar.position.x += (
		viewport_centre_x - category_centre_x
	)

func position_options_under_category() -> void:
	var category: Control = categories[selected_category]
	var icon: TextureRect = category.get_node("Icon")
	var options: Control = category.get_node("OptionsViewport")

	options.position = Vector2(
		icon.position.x,
		icon.position.y + icon.size.y + 30.0
	)

func update_current_options() -> void:
	var current_category: Control = categories[selected_category]

	options_viewport = current_category.get_node("OptionsViewport")

	power_labels.clear()
	power_options = null

	if current_category.name == "ImageCategory":
		selected_option = image_selected
		return

	power_options = options_viewport.get_child(0) as VBoxContainer

	if power_options == null:
		return

	for child in power_options.get_children():
		power_labels.append(child)

	selected_option = 0

func update_option_selection() -> void:
	if categories[selected_category].name == "ImageCategory":
		return

	if all_games_open:
		return

	if power_labels.is_empty() or power_options == null:
		return

	await get_tree().process_frame

	if not is_instance_valid(power_options):
		return

	if power_labels.is_empty():
		return

	selected_option = clampi(
		selected_option,
		0,
		power_labels.size() - 1
	)

	var selected_label: Control = power_labels[selected_option]

	if not is_instance_valid(selected_label):
		return

	var viewport_centre: float = options_viewport.size.y / 2.0

	var label_centre: float = (
		selected_label.position.y + selected_label.size.y / 2.0
	)

	var target_y: float = viewport_centre - label_centre

	if option_tween:
		option_tween.kill()

	option_tween = create_tween()

	option_tween.tween_property(
		power_options,
		"position:y",
		target_y,
		0.2
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	for i in range(power_labels.size()):
		var label: Control = power_labels[i]

		if is_instance_valid(label):
			label.modulate.a = 1.0 if i == selected_option else 0.6

func update_clock() -> void:
	var time_text: String = system_info.get_clock_text()
	time_label.text = time_text.substr(0, 5)
	update_battery()

func update_battery() -> void:
	battery_percentage = system_info.get_battery_percentage()

	if battery_percentage < 0:
		battery_label.text = "--%"
		return

	battery_label.text = "%d%%" % battery_percentage

	if battery_percentage <= 25:
		battery_icon.texture = load("res://assets/battery25.png")

	elif battery_percentage <= 50:
		battery_icon.texture = load("res://assets/battery50.png")

	elif battery_percentage <= 75:
		battery_icon.texture = load("res://assets/battery75.png")

	else:
		battery_icon.texture = load("res://assets/batteryfull.png")

func create_game_entry(game: Dictionary) -> Control:
	var entry := Control.new()
	entry.name = "Game_" + str(game["appid"])
	entry.custom_minimum_size = Vector2(400, 110)

	var logo := TextureRect.new()
	logo.name = "Logo"
	logo.position = Vector2(0, 0)
	logo.size = Vector2(128, 128)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var home := OS.get_environment("HOME")

	var library_path := home.path_join(
		".steam/steam/appcache/librarycache/" + str(game["appid"])
	)

	var artwork_files := [
		"logo.png",
		"library_capsule.jpg",
		"library_header.jpg",
		"library_hero.jpg"
	]

	var artwork_paths: Array[String] = []

	for artwork in artwork_files:
		var direct_path := library_path.path_join(artwork)

		if FileAccess.file_exists(direct_path):
			artwork_paths.append(direct_path)

	var dir := DirAccess.open(library_path)

	if dir != null:
		dir.list_dir_begin()
		var folder := dir.get_next()

		while folder != "":
			if dir.current_is_dir() and not folder.begins_with("."):
				for artwork in artwork_files:
					var candidate := (
						library_path.path_join(folder).path_join(artwork)
					)

					if FileAccess.file_exists(candidate):
						artwork_paths.append(candidate)

			folder = dir.get_next()

		dir.list_dir_end()

	for artwork_path in artwork_paths:
		var image := Image.new()
		var error := image.load(artwork_path)

		if error == OK and not image.is_empty():
			logo.texture = ImageTexture.create_from_image(image)
			break

		else:
			push_warning("Skipping unsupported artwork: " + artwork_path)

	entry.add_child(logo)

	var game_name := Label.new()
	game_name.name = "Name"
	game_name.text = str(game["name"])
	game_name.position = Vector2(175, 30)
	game_name.size = Vector2(220, 40)

	entry.add_child(game_name)

	return entry

func populate_game_options() -> void:
	for child in game_options.get_children():
		if child != all_games_entry:
			game_options.remove_child(child)
			child.queue_free()

	if all_games_entry.get_parent() != game_options:
		game_options.add_child(all_games_entry)

	game_options.move_child(all_games_entry, 0)

	for game in game_library.get_installed_games():
		var entry := create_game_entry(game)
		game_options.add_child(entry)

	update_current_options()
	update_option_selection()

func populate_all_games_list() -> void:
	for child in game_options.get_children():
		if child == all_games_entry:
			continue

		game_options.remove_child(child)
		child.queue_free()

	all_games_labels.clear()

	var games: Array[Dictionary] = game_library.get_all_games()

	for game in games:
		var appid := str(game["appid"])

		if not await is_game_app(appid):
			continue

		var game_name := str(game["name"])

		if game_name.begins_with("App "):
			game_name = await resolve_game_name(appid)

		var named_game := game.duplicate()
		named_game["name"] = game_name

		var entry := create_game_entry(named_game)
		game_options.add_child(entry)
		all_games_labels.append(entry)

	all_games_selected = 0

func open_all_games() -> void:
	all_games_open = true
	all_games_selected = 0

	if all_games_entry.get_parent() == game_options:
		game_options.remove_child(all_games_entry)

	await populate_all_games_list()

	if all_games_labels.is_empty():
		close_all_games()
		return

	update_all_games_selection()

func close_all_games() -> void:
	all_games_open = false
	all_games_labels.clear()
	all_games_selected = 0

	populate_game_options()

	selected_option = 0
	update_option_selection()

func update_all_games_selection() -> void:
	if all_games_labels.is_empty():
		return

	all_games_selected = clampi(
		all_games_selected,
		0,
		all_games_labels.size() - 1
	)

	await get_tree().process_frame

	if not is_instance_valid(game_options):
		return

	if all_games_selected >= all_games_labels.size():
		return

	var selected_entry: Control = all_games_labels[all_games_selected]

	if not is_instance_valid(selected_entry):
		return

	var viewport_centre: float = options_viewport.size.y / 2.0

	var entry_centre: float = (
		selected_entry.position.y + selected_entry.size.y / 2.0
	)

	var target_y: float = viewport_centre - entry_centre

	if option_tween:
		option_tween.kill()

	option_tween = create_tween()

	option_tween.tween_property(
		game_options,
		"position:y",
		target_y,
		0.2
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	for i in range(all_games_labels.size()):
		var entry: Control = all_games_labels[i]

		if is_instance_valid(entry):
			entry.modulate.a = 1.0 if i == all_games_selected else 0.6

func test_game_name_lookup(appid: String) -> void:
	var url := (
		"https://store.steampowered.com/api/appdetails/"
		+ "?appids=" + appid
		+ "&l=english"
	)

	var error := steam_name_request.request(url)

	if error != OK:
		push_warning("Could not start Steam name lookup.")
		return

	var response: Array = await steam_name_request.request_completed

	var response_code: int = response[1]
	var body: PackedByteArray = response[3]

	if response_code != 200:
		push_warning("Steam lookup failed. HTTP: " + str(response_code))
		return

	var json = JSON.parse_string(body.get_string_from_utf8())

	if not json is Dictionary or not json.has(appid):
		push_warning("Invalid Steam response for AppID " + appid)
		return

	var app_data: Dictionary = json[appid]

	if app_data.get("success", false):
		var game_name: String = app_data["data"]["name"]
		print("Resolved ", appid, " as ", game_name)

	else:
		print("Steam couldn't resolve AppID ", appid)

func load_game_name_cache() -> void:
	if not FileAccess.file_exists(GAME_NAME_CACHE_PATH):
		return

	var file := FileAccess.open(
		GAME_NAME_CACHE_PATH,
		FileAccess.READ
	)

	if file == null:
		return

	var data = JSON.parse_string(file.get_as_text())
	file.close()

	if data is Dictionary:
		game_name_cache = data

func save_game_name_cache() -> void:
	var file := FileAccess.open(
		GAME_NAME_CACHE_PATH,
		FileAccess.WRITE
	)

	if file == null:
		push_warning("Could not save game name cache.")
		return

	file.store_string(JSON.stringify(game_name_cache, "\t"))
	file.close()

func resolve_game_name(appid: String) -> String:
	if game_name_cache.has(appid):
		var cached = game_name_cache[appid]

		if cached is Dictionary:
			return str(cached.get("name", "App " + appid))

		return str(cached)

	var url := (
		"https://store.steampowered.com/api/appdetails/"
		+ "?appids=" + appid
		+ "&l=english"
	)

	var error := steam_name_request.request(url)

	if error != OK:
		return "App " + appid

	var response: Array = await steam_name_request.request_completed

	if response[1] != 200:
		return "App " + appid

	var json = JSON.parse_string(
		response[3].get_string_from_utf8()
	)

	if not json is Dictionary or not json.has(appid):
		return "App " + appid

	var app_data: Dictionary = json[appid]

	if not app_data.get("success", false):
		return "App " + appid

	var data: Dictionary = app_data["data"]

	var game_name := str(data.get("name", "App " + appid))
	var app_type := str(data.get("type", ""))

	game_name_cache[appid] = {
		"name": game_name,
		"type": app_type
	}

	save_game_name_cache()

	return game_name

func is_game_app(appid: String) -> bool:
	if game_name_cache.has(appid):
		var cached = game_name_cache[appid]

		if cached is Dictionary:
			var cached_type := str(cached.get("type", ""))

			if cached_type != "":
				return cached_type == "game"

	await resolve_game_name(appid)

	var updated = game_name_cache.get(appid, {})

	if updated is Dictionary:
		return str(updated.get("type", "")) == "game"

	return true

func _on_steam_initialized(username: String) -> void:
	user_label.text = username

func _on_steam_avatar_loaded(texture: Texture2D) -> void:
	user_pic.texture = texture

func setup_power_confirmation() -> void:
	power_confirmation = ConfirmationDialog.new()
	power_confirmation.title = "Confirm Power Action"
	power_confirmation.dialog_text = "Are you sure?"

	power_confirmation.confirmed.connect(
		_on_power_confirmation_confirmed
	)

	add_child(power_confirmation)

func activate_power_option() -> void:
	if power_labels.is_empty():
		return

	var selected_entry: Control = power_labels[selected_option]

	match selected_entry.name:
		"SleepLabel":
			pending_power_action = "suspend"
			power_confirmation.dialog_text = "Put the system to sleep?"

		"RestartLabel":
			pending_power_action = "reboot"
			power_confirmation.dialog_text = "Are you sure you want to restart?"

		"ShutdownLabel":
			pending_power_action = "poweroff"
			power_confirmation.dialog_text = "Are you sure you want to shut down?"

		"SwitchAccountLabel":
			print("Switch Account selected")
			return

		_:
			return

	power_confirmation.popup_centered()

func _on_power_confirmation_confirmed() -> void:
	match pending_power_action:
		"suspend":
			OS.execute("systemctl", ["suspend"])

		"reboot":
			OS.execute("systemctl", ["reboot"])

		"poweroff":
			OS.execute("systemctl", ["poweroff"])

	pending_power_action = ""

func populate_image_options() -> void:
	var image_category: Control = category_bar.get_node("ImageCategory")

	var image_options: VBoxContainer = image_category.get_node(
		"OptionsViewport/ImageOptions"
	)

	image_labels.clear()
	image_selected = 0
	selected_option = 0

	for child in image_options.get_children():
		child.queue_free()

	var dir := DirAccess.open(current_image_path)

	if dir == null:
		push_warning("Could not open directory: " + current_image_path)
		return

	var folders: Array[String] = []
	var images: Array[String] = []

	var supported_extensions := [
		"png", "jpg", "jpeg", "webp", "gif", "bmp"
	]

	dir.list_dir_begin()

	var file_name := dir.get_next()

	while file_name != "":
		if not file_name.begins_with("."):
			if dir.current_is_dir():
				folders.append(file_name)
			elif file_name.get_extension().to_lower() in supported_extensions:
				images.append(file_name)

		file_name = dir.get_next()

	dir.list_dir_end()

	folders.sort()
	images.sort()

	for folder_name in folders:
		var folder_entry := create_image_entry(folder_name, true)
		image_options.add_child(folder_entry)
		image_labels.append(folder_entry)

	for image_name in images:
		var image_entry := create_image_entry(image_name, false)
		image_options.add_child(image_entry)
		image_labels.append(image_entry)

	update_image_selection()

func enter_image_folder(folder_name: String) -> void:
	image_path_history.append(current_image_path)

	current_image_path = current_image_path.path_join(folder_name)

	populate_image_options()

func go_back_image_folder() -> void:
	if image_path_history.is_empty():
		return

	current_image_path = image_path_history.pop_back()

	populate_image_options()

func update_image_selection() -> void:
	if image_labels.is_empty():
		return

	image_selected = clampi(
		image_selected,
		0,
		image_labels.size() - 1
	)

	selected_option = image_selected

	var image_category: Control = category_bar.get_node("ImageCategory")
	var image_viewport: Control = image_category.get_node("OptionsViewport")
	var image_options: VBoxContainer = image_category.get_node(
		"OptionsViewport/ImageOptions"
	)

	await get_tree().process_frame

	if not is_instance_valid(image_options):
		return

	if image_selected >= image_labels.size():
		return

	var selected_entry: Control = image_labels[image_selected]

	if not is_instance_valid(selected_entry):
		return

	var viewport_centre: float = image_viewport.size.y / 2.0

	var entry_centre: float = (
		selected_entry.position.y + selected_entry.size.y / 2.0
	)

	var target_y: float = viewport_centre - entry_centre

	if option_tween:
		option_tween.kill()

	option_tween = create_tween()

	option_tween.tween_property(
		image_options,
		"position:y",
		target_y,
		0.2
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	for i in range(image_labels.size()):
		var entry: Control = image_labels[i]

		if is_instance_valid(entry):
			entry.modulate.a = 1.0 if i == image_selected else 0.6

func create_image_entry(entry_name: String, is_folder: bool) -> Control:
	var entry := Control.new()

	entry.name = (
		"Folder_" if is_folder else "Image_"
	) + entry_name

	entry.custom_minimum_size = Vector2(0, 80)

	var icon := TextureRect.new()
	icon.name = "Icon"

	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	icon.position = Vector2(0, 5)
	icon.size = Vector2(70, 70)

	if is_folder:
		icon.texture = load(FOLDER_ICON_PATH) as Texture2D

	else:
		var image_path: String = current_image_path.path_join(entry_name)
		icon.texture = get_image_thumbnail(image_path)

	entry.add_child(icon)

	var label := Label.new()
	label.name = "Name"
	label.text = entry_name

	label.position = Vector2(90, 0)
	label.size = Vector2(400, 80)

	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	entry.add_child(label)

	return entry

func get_image_thumbnail(image_path: String) -> Texture2D:
	if image_thumbnail_cache.has(image_path):
		return image_thumbnail_cache[image_path] as Texture2D

	var image := Image.new()
	var error := image.load(image_path)

	if error != OK:
		push_warning("Could not load image: " + image_path)
		return load(FOLDER_ICON_PATH) as Texture2D

	var scale_factor: float = minf(
		140.0 / image.get_width(),
		140.0 / image.get_height()
	)

	var thumbnail_width: int = maxi(
		roundi(image.get_width() * scale_factor),
		1
	)

	var thumbnail_height: int = maxi(
		roundi(image.get_height() * scale_factor),
		1
	)

	image.resize(
		thumbnail_width,
		thumbnail_height,
		Image.INTERPOLATE_LANCZOS
	)

	var texture := ImageTexture.create_from_image(image)

	image_thumbnail_cache[image_path] = texture

	return texture
