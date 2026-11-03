extends Control

@onready var image_display: TextureRect = $ImageContainer/Image
@onready var filename_label: Label = $Header/FilenameLabel

var image_paths: Array[String] = []
var current_image_index: int = 0

func _ready() -> void:
	WallpaperManager.wallpaper_changed.connect(_on_wallpaper_changed)

	if WallpaperManager.current_wallpaper != null:
		_on_wallpaper_changed(WallpaperManager.current_wallpaper)


func _on_wallpaper_changed(texture: Texture2D) -> void:
	$Background.texture = texture
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close_viewer()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_left"):
		previous_image()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_right"):
		next_image()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_select"):
		if not image_paths.is_empty():
			WallpaperManager.set_wallpaper(
				image_paths[current_image_index]
			)

		get_viewport().set_input_as_handled()


func close_viewer() -> void:
	queue_free()
	
func open_image(image_path: String) -> void:
	var image: Image = ImageLoader.load_image_file(image_path)

	if image == null:
		push_error("Could not load image: " + image_path)
		return

	image_display.texture = ImageTexture.create_from_image(image)
	filename_label.text = image_path.get_file()
func set_image_list(paths: Array[String], selected_path: String) -> void:
	image_paths = paths

	current_image_index = image_paths.find(selected_path)

	if current_image_index == -1:
		current_image_index = 0

	show_current_image()


func show_current_image() -> void:
	if image_paths.is_empty():
		return

	open_image(image_paths[current_image_index])


func next_image() -> void:
	if image_paths.is_empty():
		return

	current_image_index = (current_image_index + 1) % image_paths.size()
	show_current_image()


func previous_image() -> void:
	if image_paths.is_empty():
		return

	current_image_index = (
		current_image_index - 1 + image_paths.size()
	) % image_paths.size()

	show_current_image()
