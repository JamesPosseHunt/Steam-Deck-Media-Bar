
extends Control

@onready var path_label: Label = $Header/PathLabel
@onready var entries: VBoxContainer = $FileList/Entries
@onready var controls_label: Label = $Footer/ControlsLabel

var selected_entry_index: int = 0
var current_path: String = ""
var directory_history: Array[String] = []

func _ready() -> void:
	current_path = OS.get_environment("HOME")
	controls_label.text = "A: Open    B: Back"
	load_directory(current_path)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		go_back()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_down"):
		selected_entry_index += 1
		update_entry_selection()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_up"):
		selected_entry_index -= 1
		update_entry_selection()
		get_viewport().set_input_as_handled()
		
func load_directory(path: String) -> void:
	var directory := DirAccess.open(path)

	if directory == null:
		push_error("Could not open directory: " + path)
		return

	current_path = path
	path_label.text = current_path

	# Clear the previous listing.
	for child in entries.get_children():
		child.queue_free()

	# Get folders and files separately.
	var folders := directory.get_directories()
	var files := directory.get_files()

	folders.sort()
	files.sort()

	# Add folders first.
	# Add parent directory entry, unless we're in Home.
	var home_path := OS.get_environment("HOME")

	if current_path != home_path:
		create_entry("..", true)

	# Add folders first.
	for folder in folders:
		create_entry(folder, true)

	# Then add files.
	for file in files:
		create_entry(file, false)
	
	selected_entry_index = 0
	call_deferred("update_entry_selection")


func create_entry(entry_name: String, is_folder: bool) -> void:
	var button := Button.new()

	if is_folder:
		button.text = "📁  " + entry_name
	else:
		var file_path := current_path.path_join(entry_name)
		var file_size := FileAccess.get_file_as_bytes(file_path).size()
		var file_type := get_file_type(entry_name)

		button.text = "📄  " + entry_name + "    " + file_type + "    " + format_file_size(file_size)

	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 60)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color(0.35, 0.65, 0.85, 0.25)
	focus_style.corner_radius_top_left = 8
	focus_style.corner_radius_top_right = 8
	focus_style.corner_radius_bottom_left = 8
	focus_style.corner_radius_bottom_right = 8

	button.add_theme_stylebox_override("focus", focus_style)

	button.pressed.connect(
		func(): open_entry(entry_name, is_folder)
	)

	entries.add_child(button)


func format_file_size(bytes: int) -> String:
	if bytes < 1024:
		return str(bytes) + " B"
	elif bytes < 1024 * 1024:
		return "%.1f KB" % (float(bytes) / 1024.0)
	else:
		return "%.1f MB" % (float(bytes) / (1024.0 * 1024.0))
func open_entry(entry_name: String, is_folder: bool) -> void:
	if is_folder:
		if entry_name == "..":
			go_to_parent_directory()
			return

		directory_history.append(current_path)
		var target_path := current_path.path_join(entry_name)
		load_directory(target_path)
	else:
		open_file(current_path.path_join(entry_name))
		
func go_back() -> void:
	if directory_history.is_empty():
		return

	var previous_path: String = directory_history.pop_back()
	load_directory(previous_path)
func update_entry_selection() -> void:
	var buttons := entries.get_children()

	if buttons.is_empty():
		return

	selected_entry_index = clampi(
		selected_entry_index,
		0,
		buttons.size() - 1
	)

	var selected_button := buttons[selected_entry_index] as Button
	selected_button.grab_focus()

func go_to_parent_directory() -> void:
	var parent_path := current_path.get_base_dir()

	if parent_path == current_path:
		return

	directory_history.append(current_path)
	load_directory(parent_path)

func open_file(file_path: String) -> void:
	var extension := file_path.get_extension().to_lower()

	var image_extensions := [
		"png", "jpg", "jpeg", "webp", "gif", "bmp"
	]

	if extension in image_extensions:
		var viewer_scene := preload("res://scenes/apps/image_viewer.tscn")
		var viewer = viewer_scene.instantiate()

		get_tree().root.add_child(viewer)
		viewer.open_image(file_path)
func get_file_type(file_name: String) -> String:
	var extension := file_name.get_extension().to_lower()

	if extension in ["png", "jpg", "jpeg", "webp", "gif", "bmp"]:
		return "Image"
	elif extension in ["mp3", "ogg", "wav", "flac", "m4a", "aac", "opus", "wma"]:
		return "Audio"
	elif extension in ["mp4", "mkv", "avi", "mov", "webm", "m4v", "mpg", "mpeg"]:
		return "Video"
	elif extension == "pdf":
		return "Document"

	return "File"
