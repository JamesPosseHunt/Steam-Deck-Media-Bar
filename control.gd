extends Control

@onready var user_label: Label = $StatusBarBackground/StatusBar/UserLabel
@onready var user_pic: TextureRect = $StatusBarBackground/StatusBar/UserPic

@onready var category_bar: HFlowContainer = $CategoryBar
@onready var categories: Array = category_bar.get_children()

@onready var game_options: VBoxContainer = $CategoryBar/GameCategory/OptionsViewport/GameOptions
@onready var all_games_entry: Control = $CategoryBar/GameCategory/OptionsViewport/GameOptions/AllGames

var status_bar = preload("res://scripts/status_bar.gd").new()
var game_library = preload("res://scripts/game_library.gd").new()
var game_browser = preload("res://scripts/game_browser.gd").new()
var power_manager = preload("res://scripts/power_manager.gd").new()
var steam_manager = preload("res://scripts/steam_manager.gd").new()
var media_browser = preload("res://scripts/media_browser.gd").new()

var selected_category: int = 0
var selected_option: int = 0

var option_tween: Tween
var options_viewport: Control
var current_options: VBoxContainer

func _ready() -> void:
	add_child(game_library)
	game_library.initialise()

	add_child(game_browser)
	game_browser.initialise(
		self,
		game_library,
		steam_manager,
		game_options,
		all_games_entry
	)

	add_child(power_manager)
	power_manager.initialise(self)

	add_child(media_browser)
	media_browser.initialise(self)

	steam_manager.steam_initialized.connect(_on_steam_initialized)
	steam_manager.avatar_loaded.connect(_on_steam_avatar_loaded)
	steam_manager.initialise_steam()

	selected_category = categories.find(
		category_bar.get_node("GameCategory")
	)

	update_current_options()
	update_category_selection()

	add_child(status_bar)
	status_bar.initialise(
		$StatusBarBackground/StatusBar/TimeLabel,
		$StatusBarBackground/StatusBar/BatteryLabel,
		$StatusBarBackground/StatusBar/BatteryIcon
	)

	await get_tree().process_frame

	for category_name in media_browser.media_paths:
		media_browser.populate_media_options(category_name)

	centre_selected_category()
	game_browser.populate_game_options()

func _input(event: InputEvent) -> void:
	var current_category: String = get_current_category_name()

	# Back closes the All Games view first.
	if game_browser.all_games_open and event.is_action_pressed("ui_cancel"):
		game_browser.close_all_games()
		return
		
	# Back inside a media folder goes up one level.
	if media_browser.media_paths.has(current_category) and event.is_action_pressed("ui_cancel"):
		go_back()
		return

	# Left closes All Games, otherwise changes category.
	if event.is_action_pressed("ui_left"):
		if game_browser.all_games_open:
			game_browser.close_all_games()
		else:
			change_category(-1)

	if event.is_action_pressed("ui_right"):
		if not game_browser.all_games_open:
			change_category(1)
		return

	if event.is_action_pressed("ui_down"):
		move_selection(1)
		return

	if event.is_action_pressed("ui_up"):
		move_selection(-1)
		return

	if event.is_action_pressed("ui_accept"):
		activate_selected_entry()
		return


func get_current_category_name() -> String:
	if categories.is_empty():
		return ""

	return str(categories[selected_category].name)


func get_current_options() -> VBoxContainer:
	if game_browser.all_games_open:
		return game_options

	if current_options != null and is_instance_valid(current_options):
		return current_options

	return null

func get_current_entries() -> Array[Control]:
	var entries: Array[Control] = []

	if game_browser.all_games_open:
		for entry in game_browser.all_games_labels:
			if is_instance_valid(entry):
				entries.append(entry)

		return entries

	var options: VBoxContainer = get_current_options()

	if options == null:
		return entries

	for child in options.get_children():
		if child is Control:
			entries.append(child)

	return entries


func move_selection(direction: int) -> void:
	var entries: Array[Control] = get_current_entries()

	if entries.is_empty():
		selected_option = 0
		return

	selected_option = clampi(
		selected_option + direction,
		0,
		entries.size() - 1
	)

	update_selection_display()


func update_selection_display() -> void:
	var entries: Array[Control] = get_current_entries()
	var options: VBoxContainer = get_current_options()

	if entries.is_empty() or options == null:
		return

	selected_option = clampi(
		selected_option,
		0,
		entries.size() - 1
	)

	await get_tree().process_frame

	if not is_instance_valid(options):
		return

	entries = get_current_entries()

	if entries.is_empty():
		return

	selected_option = clampi(
		selected_option,
		0,
		entries.size() - 1
	)

	var selected_entry: Control = entries[selected_option]

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
		options,
		"position:y",
		target_y,
		0.2
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	for i in range(entries.size()):
		var entry: Control = entries[i]

		if is_instance_valid(entry):
			entry.modulate.a = 1.0 if i == selected_option else 0.6


func activate_selected_entry() -> void:
	var entries: Array[Control] = get_current_entries()

	if entries.is_empty():
		return

	if selected_option < 0 or selected_option >= entries.size():
		return

	var selected_entry: Control = entries[selected_option]
	var current_category: String = get_current_category_name()

	if current_category == "GameCategory":
		game_browser.activate_game_entry(selected_entry)
		return

	if media_browser.media_paths.has(current_category):
		media_browser.activate_selected_entry(
			current_category,
			selected_entry
		)
		return

	if current_category == "PowerCategory":
		power_manager.activate_option(selected_entry)
		return

	# Other categories can add their own activation behaviour here.

func go_back() -> void:
	var current_category: String = get_current_category_name()

	if game_browser.all_games_open:
		game_browser.close_all_games()
		return

	if media_browser.media_paths.has(current_category):
		media_browser.go_back(current_category)


func update_current_options() -> void:
	var category: Control = categories[selected_category]

	options_viewport = category.get_node("OptionsViewport")

	current_options = null

	if options_viewport.get_child_count() > 0:
		current_options = options_viewport.get_child(0) as VBoxContainer

	selected_option = 0


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
	update_selection_display()


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

func _on_steam_initialized(username: String) -> void:
	user_label.text = username


func _on_steam_avatar_loaded(texture: Texture2D) -> void:
	user_pic.texture = texture
