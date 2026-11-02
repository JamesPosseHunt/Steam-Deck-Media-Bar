extends Control

@onready var time_label: Label = $StatusBarBackground/StatusBar/TimeLabel
@onready var battery_label: Label = $StatusBarBackground/StatusBar/BatteryLabel
@onready var battery_icon: TextureRect = $StatusBarBackground/StatusBar/BatteryIcon
@onready var user_label: Label = $StatusBarBackground/StatusBar/UserLabel
@onready var user_pic: TextureRect = $StatusBarBackground/StatusBar/UserPic
@onready var category_bar: HFlowContainer = $CategoryBar
@onready var categories: Array = category_bar.get_children()
@onready var all_games_panel: PanelContainer = $AllGamesPanel
@onready var all_games_scroll: ScrollContainer = $AllGamesPanel/AllGamesScroll
@onready var all_games_options: VBoxContainer = $AllGamesPanel/AllGamesScroll/AllGamesOptions
@onready var steam_name_request: HTTPRequest = $SteamNameRequest
var game_name_cache: Dictionary = {}
const GAME_NAME_CACHE_PATH := "user://steam_game_names.json"

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
var all_games_open: bool = false
var all_games_labels: Array[Control] = []
var all_games_selected: int = 0

func _ready() -> void:
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
	centre_selected_category()
	load_game_name_cache()
	populate_game_options()

func _input(event: InputEvent) -> void:
	if all_games_open:
		if event.is_action_pressed("ui_down"):
			all_games_selected = min(
				all_games_selected + 1,
				all_games_labels.size() - 1
			)
			update_all_games_selection()

		elif event.is_action_pressed("ui_up"):
			all_games_selected = max(
				all_games_selected - 1,
				0
			)
			update_all_games_selection()

		elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_cancel"):
			close_all_games()

		elif event.is_action_pressed("ui_accept"):
			var selected_entry: Control = all_games_labels[all_games_selected]

			if selected_entry.name.begins_with("Game_"):
				var appid_text := selected_entry.name.trim_prefix("Game_")
				steam_manager.launch_game(int(appid_text))
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
		selected_option = max(selected_option - 1, 0)

	elif event.is_action_pressed("ui_accept"):
		if categories[selected_category].name == "GameCategory" and not power_labels.is_empty():
			var selected_entry: Control = power_labels[selected_option]

			if selected_entry.name == "AllGames":
				open_all_games()

			elif selected_entry.name.begins_with("Game_"):
				var appid_text := selected_entry.name.trim_prefix("Game_")
				steam_manager.launch_game(int(appid_text))

	update_option_selection()

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

		
func update_category_selection() -> void:
	for i in range(categories.size()):
		var category: Control = categories[i]
		var icon: TextureRect = category.get_node("Icon")
		var options: Control = category.get_child(
			category.get_child_count() - 1
		) as Control
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

func update_option_selection() -> void:
	if power_labels.is_empty():
		return
	await get_tree().process_frame
	if selected_option >= power_labels.size():
		selected_option = power_labels.size() - 1
	var selected_label: Control = power_labels[selected_option]
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
		label.modulate.a = 1.0 if i == selected_option else 0.6

func position_options_under_category() -> void:
	var category: Control = categories[selected_category]
	var icon: TextureRect = category.get_node("Icon")
	var options: Control = category.get_node("OptionsViewport")
	options.position = Vector2(
		icon.position.x,
		icon.position.y + icon.size.y + 30.0
	)
func update_current_options() -> void:
	var category: Control = categories[selected_category]
	options_viewport = category.get_node("OptionsViewport")
	power_options = options_viewport.get_child(0) as VBoxContainer
	power_labels = power_options.get_children()
	selected_option = clampi(
		selected_option,
		0,
		maxi(power_labels.size() - 1, 0)
	)

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
	var logo_path := home.path_join(
		".steam/steam/appcache/librarycache/"
		+ str(game["appid"]) + "/logo.png"
	)
	if FileAccess.file_exists(logo_path):
		var image := Image.load_from_file(logo_path)
		if not image.is_empty():
			logo.texture = ImageTexture.create_from_image(image)
	entry.add_child(logo)
	var game_name := Label.new()
	game_name.name = "Name"
	game_name.text = str(game["name"])
	game_name.position = Vector2(175, 30)
	game_name.size = Vector2(220, 40)
	entry.add_child(game_name)
	return entry

func populate_game_options() -> void:
	var game_category: Control = category_bar.get_node("GameCategory")
	var game_options: VBoxContainer = game_category.get_node(
		"OptionsViewport/GameOptions"
	)
	for game in game_library.get_installed_games():
		var entry := create_game_entry(game)
		game_options.add_child(entry)
	update_current_options()
	update_option_selection()

func _on_steam_initialized(username: String) -> void:
	user_label.text = username

func _on_steam_avatar_loaded(texture: Texture2D) -> void:
	user_pic.texture = texture

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

func populate_all_games_panel() -> void:
	for child in all_games_options.get_children():
		child.queue_free()

	all_games_labels.clear()

	var games: Array[Dictionary] = game_library.get_all_games()

	for game in games:
		var appid := str(game["appid"])
		var game_name := str(game["name"])

		if game_name.begins_with("App "):
			game_name = await resolve_game_name(appid)

		var named_game := game.duplicate()
		named_game["name"] = game_name

		var entry := create_game_entry(named_game)

		all_games_options.add_child(entry)
		all_games_labels.append(entry)

	all_games_selected = clampi(
		all_games_selected,
		0,
		maxi(all_games_labels.size() - 1, 0)
	)

func open_all_games() -> void:
	if all_games_labels.is_empty():
		await populate_all_games_panel()

	if all_games_labels.is_empty():
		return

	var all_games_entry: Control = category_bar.get_node(
		"GameCategory/OptionsViewport/GameOptions/AllGames"
	)

	var viewport_size := get_viewport_rect().size
	var panel_width := 500.0
	var panel_height := 600.0
	var gap := 20.0

	# Make sure the panel has the intended dimensions.
	all_games_panel.custom_minimum_size = Vector2(
		panel_width,
		panel_height
	)
	all_games_panel.size = Vector2(
		panel_width,
		panel_height
	)

	# Calculate the position immediately to the right of AllGames.
	var panel_x := (
		all_games_entry.global_position.x
		+ all_games_entry.size.x
		+ gap
	)

	# If there isn't enough room, place it to the left instead.
	if panel_x + panel_width > viewport_size.x:
		panel_x = (
			all_games_entry.global_position.x
			- panel_width
			- gap
		)

	# Keep it inside the screen.
	panel_x = clampf(
		panel_x,
		0.0,
		viewport_size.x - panel_width
	)

	var panel_y := (
		all_games_entry.global_position.y
		+ all_games_entry.size.y / 2.0
		- panel_height / 2.0
	)

	panel_y = clampf(
		panel_y,
		0.0,
		viewport_size.y - panel_height
	)

	all_games_panel.global_position = Vector2(
		panel_x,
		panel_y
	)

	all_games_panel.show()

	all_games_open = true
	all_games_selected = 0
	update_all_games_selection()

	print("All Games entry: ", all_games_entry.get_global_rect())
	print("All Games panel: ", all_games_panel.get_global_rect())
	
	
func close_all_games() -> void:
	all_games_panel.hide()
	all_games_open = false


func update_all_games_selection() -> void:
	if all_games_labels.is_empty():
		return

	await get_tree().process_frame

	all_games_selected = clampi(
		all_games_selected,
		0,
		all_games_labels.size() - 1
	)

	var selected_entry: Control = all_games_labels[all_games_selected]

	# Calculate the scroll position that centres the selected game.
	var viewport_height := all_games_scroll.size.y
	var entry_centre := (
		selected_entry.position.y
		+ selected_entry.size.y / 2.0
	)

	var target_scroll := entry_centre - viewport_height / 2.0

	var scrollbar := all_games_scroll.get_v_scroll_bar()

	all_games_scroll.scroll_vertical = int(clampf(
		target_scroll,
		0.0,
		scrollbar.max_value
	))

	# Highlight the selected game.
	for i in range(all_games_labels.size()):
		all_games_labels[i].modulate.a = (
			1.0 if i == all_games_selected else 0.6
		)
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
		return str(game_name_cache[appid])

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

	var game_name: String = app_data["data"]["name"]

	game_name_cache[appid] = game_name
	save_game_name_cache()

	return game_name
