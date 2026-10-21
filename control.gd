extends Control

@onready var time_label: Label = $StatusBarBackground/StatusBar/TimeLabel
@onready var battery_label: Label = $StatusBarBackground/StatusBar/BatteryLabel
@onready var battery_icon: TextureRect = $StatusBarBackground/StatusBar/BatteryIcon
@onready var user_label: Label = $StatusBarBackground/StatusBar/UserLabel
@onready var user_pic: TextureRect = $StatusBarBackground/StatusBar/UserPic
var steam_username: String = ""

var selected_category: int = 0

@onready var category_bar: HFlowContainer = $CategoryBar
@onready var categories: Array = category_bar.get_children()

var selected_option: int = 0
var option_tween: Tween

var options_viewport: Control
var power_options: VBoxContainer
var power_labels: Array = []

func _ready() -> void:
	selected_category = categories.find(
		category_bar.get_node("GameCategory")
	)

	update_current_options()
	initialise_steam()
	update_category_selection()
	update_clock()
	update_option_selection()

	await get_tree().process_frame
	centre_selected_category()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_right"):
		selected_category = (selected_category + 1) % categories.size()
		update_current_options()
		update_category_selection()
		position_options_under_category()
		centre_selected_category()
		update_option_selection()

	elif event.is_action_pressed("ui_left"):
		selected_category = (selected_category - 1 + categories.size()) % categories.size()
		update_current_options()
		update_category_selection()
		position_options_under_category()
		centre_selected_category()
		update_option_selection()
	elif event.is_action_pressed("ui_down"):
		selected_option = min(
			selected_option + 1,
			power_labels.size() - 1
		)
		update_option_selection()

	elif event.is_action_pressed("ui_up"):
		selected_option = max(
			selected_option - 1,
			0
		)
	update_option_selection()

func update_clock() -> void:
	var time := Time.get_time_dict_from_system()
	time_label.text = "%02d:%02d" % [
		time.hour,
		time.minute
	]
	update_battery()

var battery_percentage: int = -1

func get_battery_percentage() -> int:
	var path := "/sys/class/power_supply/BAT0/capacity"
	var file := FileAccess.open(path, FileAccess.READ)

	if file == null:
		push_error("Cannot open battery file")
		return -1

	var bytes := file.get_buffer(16)
	file.close()

	var value := bytes.get_string_from_ascii().strip_edges()
	print("Battery raw bytes: <", value, ">")
	if value.is_valid_int():
		return value.to_int()
	return int(value)

func update_battery() -> void:
	battery_percentage = get_battery_percentage()
	battery_label.text = "%d%%" % battery_percentage
	if battery_percentage <= 25:
		battery_icon.texture = load("res://assets/battery25.png")
	elif battery_percentage <= 50 and battery_percentage >= 25:
		battery_icon.texture = load("res://assets/battery50.png")
	elif battery_percentage <= 75 and battery_percentage >= 50:
		battery_icon.texture = load("res://assets/battery75.png")
	elif battery_percentage <= 100 and battery_percentage >= 75:
		battery_icon.texture = load("res://assets/batteryfull.png")

func initialise_steam() -> void:
	var result: Dictionary = Steam.steamInitEx()

	print("Steam initialisation: ", result)

	if result["status"] == 0:
		steam_username = Steam.getPersonaName()
		user_label.text = steam_username
		if not Steam.avatar_loaded.is_connected(_on_avatar_loaded):
			Steam.avatar_loaded.connect(_on_avatar_loaded)

		Steam.getPlayerAvatar(3)
	else:
		push_warning("Steam initialisation failed: " + str(result))

func _on_avatar_loaded(steam_id: int, avatar_size: int, avatar_buffer: Array) -> void:
	print("Avatar loaded for Steam ID: ", steam_id)

	var image := Image.create_from_data(
		avatar_size,
		avatar_size,
		false,
		Image.FORMAT_RGBA8,
		PackedByteArray(avatar_buffer)
	)

	user_pic.texture = ImageTexture.create_from_image(image)

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

	# Find the category's centre in global coordinates.
	var category_centre: Vector2 = category.global_position \
		+ category.size / 2.0

	# Find the viewport's horizontal centre in global coordinates.
	var viewport_centre_x: float = get_viewport_rect().size.x / 2.0

	# Move CategoryBar by the difference.
	category_bar.position.x += viewport_centre_x - category_centre.x

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

	var icon_bottom: float = icon.position.y + icon.size.y

	options.position = Vector2(
		icon.position.x,
		icon_bottom + 30.0
	)
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
