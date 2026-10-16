extends Control

var selected_category: int = 0
var category_tween: Tween
var option_tween: Tween
@onready var category_bar: HBoxContainer = $CategoryViewport/CategoryBar
@onready var categories = category_bar.get_children()
var category_options = {
	"SettingsCategory": ["System", "Internet", "Storage", "Bluetooth", "Display", "Power", "Audio", "Controller", "Keyboard", "Customization", "Accessibility", "Security", "Notifications", "Friends and Chat", "Downloads", "Cloud", "In Game", "Compatibility", "Family", "Remote Play", "Game Recording", "Home", "Library", "Store"],
	"MusicCategory": ["Music Library", "Playlists"],
	"PhotoCategory": ["Photo Library", "Albums"],
	"VideoCategory": ["Video Library", "Films"],
	"GamesCategory": ["Great on Deck", "All Games", "Installed", "Collections", "Non-Steam"],
	"SteamCategory": ["Store", "Friends and Chat", "Media", "Downloads"]
}
var selected_option: int = 0
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	update_selection()
	await get_tree().process_frame
	centre_selected_category()
	rebuild_option_list()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_right"):
		selected_category = min(selected_category + 1, 5)
		print(selected_category)
		update_selection()
		centre_selected_category()
		rebuild_option_list()
		selected_option = 0
		position_option_list()
		centre_selected_option()
	elif event.is_action_pressed("ui_left"):
		selected_category = max(selected_category - 1, 0)
		print(selected_category)
		update_selection()
		centre_selected_category()
		rebuild_option_list()
		selected_option = 0
		position_option_list()
		centre_selected_option()
	elif event.is_action_pressed("ui_down"):
		var option_count = $CategoryViewport/OptionList.get_child_count()
		if option_count > 0:
			selected_option = min(selected_option + 1, option_count - 1)
			update_option_selection()
			centre_selected_option()
	elif event.is_action_pressed("ui_up"):
		var option_count = $CategoryViewport/OptionList.get_child_count()
		if option_count > 0:
			selected_option = max(selected_option - 1, 0)
			update_option_selection()
			centre_selected_option()
	
	elif event.is_action_pressed("ui_accept"):
		var option_list = $CategoryViewport/OptionList
		var options = option_list.get_children()

		if options.size() > 0:
			print("Selected: ", options[selected_option].text)
func update_selection() -> void:
	for i in range(categories.size()):
		var category = categories[i]

		if i == selected_category:
			category.add_theme_font_size_override("font_size", 32)
		else:
			category.add_theme_font_size_override("font_size", 22)
func centre_selected_category() -> void:
	var selected_label = categories[selected_category]
	var viewport = $CategoryViewport
	var screen_centre = viewport.size.x / 2
	var label_centre = selected_label.position.x + selected_label.size.x / 2
	var target_x = screen_centre - label_centre

	if category_tween:
		category_tween.kill()

	category_tween = create_tween()
	category_tween.tween_property(category_bar, "position:x", target_x, 0.35)
	var option_list = $CategoryViewport/OptionList
	var target_option_x = target_x + label_centre - option_list.size.x / 2

	category_tween.tween_property(option_list, "position:x", target_option_x, 0.35)
func position_option_list() -> void:
	var selected_label = categories[selected_category]
	var label_centre = category_bar.position.x + selected_label.position.x + selected_label.size.x / 2
	var option_list = $CategoryViewport/OptionList

	option_list.position.x = label_centre - option_list.size.x / 2

func rebuild_option_list() -> void:
	var option_list = $CategoryViewport/OptionList
	var selected_name = categories[selected_category].name
	var options = category_options[selected_name]

	for child in option_list.get_children():
		child.queue_free()

	for option_name in options:
		var label = Label.new()
		label.text = option_name
		option_list.add_child(label)
		update_option_selection()
func update_option_selection() -> void:
	var option_list = $CategoryViewport/OptionList
	var options = option_list.get_children()

	for i in range(options.size()):
		if i == selected_option:
			options[i].add_theme_font_size_override("font_size", 28)
		else:
			options[i].add_theme_font_size_override("font_size", 22)
func centre_selected_option() -> void:
	var option_list = $CategoryViewport/OptionList
	var options = option_list.get_children()

	if options.is_empty():
		return

	var selected_label = options[selected_option]
	var viewport = $CategoryViewport
	var screen_centre = viewport.size.y / 2
	var label_centre = selected_label.position.y + selected_label.size.y / 2
	var target_y = screen_centre - label_centre

	if option_tween:
		option_tween.kill()

	option_tween = create_tween()
	option_tween.tween_property(option_list, "position:y", target_y, 0.35)
