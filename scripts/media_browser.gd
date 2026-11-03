
extends Node

const FOLDER_ICON_PATH := "res://assets/CarlyImage.png"

const MEDIA_EXTENSIONS: Dictionary = {
	"ImageCategory": ["png", "jpg", "jpeg", "webp", "gif", "bmp"],
	"MusicCategory": ["mp3", "ogg", "wav", "flac", "m4a", "aac", "opus", "wma"],
	"VideoCategory": ["mp4", "mkv", "avi", "mov", "webm", "m4v", "mpg", "mpeg"]
}

const MEDIA_FILE_ICONS: Dictionary = {
	"MusicCategory": "♫",
	"VideoCategory": "▶"
}

var controller: Control

var media_paths: Dictionary = {
	"ImageCategory": OS.get_environment("HOME").path_join("Pictures"),
	"MusicCategory": OS.get_environment("HOME").path_join("Ceol"),
	"VideoCategory": OS.get_environment("HOME").path_join("Físeáin")
}

var media_current_paths: Dictionary = {}
var media_path_history: Dictionary = {}
var media_labels: Dictionary = {}
var media_thumbnail_cache: Dictionary = {}
var media_thumbnail_jobs: Dictionary = {}


func initialise(main_controller: Control) -> void:
	controller = main_controller

	for category_name in media_paths:
		media_current_paths[category_name] = media_paths[category_name]
		media_path_history[category_name] = []
		media_labels[category_name] = []


# --------------------------------------------------
# MEDIA OPTIONS
# --------------------------------------------------

func get_media_options(category_name: String) -> VBoxContainer:
	var category: Control = controller.category_bar.get_node(category_name)
	var options_name: String = category_name.replace("Category", "") + "Options"

	return category.get_node(
		"OptionsViewport/" + options_name
	) as VBoxContainer


func populate_media_options(category_name: String) -> void:
	if not media_paths.has(category_name):
		return

	var media_options: VBoxContainer = get_media_options(category_name)
	var current_path: String = str(media_current_paths[category_name])

	var labels: Array[Control] = []
	media_labels[category_name] = labels

	for child in media_options.get_children():
		media_options.remove_child(child)
		child.queue_free()

	var dir := DirAccess.open(current_path)

	if dir == null:
		push_warning("Could not open directory: " + current_path)
		return

	var folders: Array[String] = []
	var files: Array[String] = []

	var supported_extensions: Array = MEDIA_EXTENSIONS[category_name]

	dir.list_dir_begin()

	var file_name: String = dir.get_next()

	while file_name != "":
		if not file_name.begins_with("."):
			if dir.current_is_dir():
				folders.append(file_name)
			elif file_name.get_extension().to_lower() in supported_extensions:
				files.append(file_name)

		file_name = dir.get_next()

	dir.list_dir_end()

	folders.sort()
	files.sort()

	for folder_name in folders:
		var entry: Control = create_media_entry(
			category_name,
			folder_name,
			true
		)

		media_options.add_child(entry)
		labels.append(entry)

	for file_name_entry in files:
		var entry: Control = create_media_entry(
			category_name,
			file_name_entry,
			false
		)

		media_options.add_child(entry)
		labels.append(entry)

	media_labels[category_name] = labels

	if category_name == controller.get_current_category_name():
		controller.selected_option = 0
		controller.update_selection_display()


func create_media_entry(
	category_name: String,
	entry_name: String,
	is_folder: bool
) -> Control:
	var entry := Control.new()

	var prefix: String = "Folder_" if is_folder else "File_"
	entry.name = prefix + entry_name
	entry.custom_minimum_size = Vector2(0, 80)

	var thumbnail: Texture2D = null

	if is_folder:
		thumbnail = load(FOLDER_ICON_PATH) as Texture2D

	elif category_name == "ImageCategory":
		var image_path: String = str(media_current_paths[category_name]).path_join(entry_name)
		entry.set_meta("path", image_path)
		thumbnail = get_image_thumbnail(image_path)

	else:
		var media_path: String = str(media_current_paths[category_name]).path_join(entry_name)
		thumbnail = get_media_thumbnail(category_name, media_path)

	if thumbnail != null:
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.texture = thumbnail
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(0, 5)
		icon.size = Vector2(70, 70)
		entry.add_child(icon)

	else:
		var media_icon := Label.new()
		media_icon.name = "Icon"
		media_icon.text = "▰" if is_folder else str(MEDIA_FILE_ICONS.get(category_name, ""))
		media_icon.position = Vector2(0, 0)
		media_icon.size = Vector2(70, 80)
		media_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		media_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		media_icon.add_theme_font_size_override("font_size", 32)
		entry.add_child(media_icon)

	var label := Label.new()
	label.name = "Name"
	label.text = entry_name
	label.position = Vector2(90, 0)
	label.size = Vector2(400, 80)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	entry.add_child(label)

	return entry


# --------------------------------------------------
# MEDIA ACTIVATION AND FOLDER NAVIGATION
# --------------------------------------------------

func activate_selected_entry(category_name: String, entry: Control) -> void:
	if entry.name.begins_with("Folder_"):
		var folder_name: String = entry.name.trim_prefix("Folder_")
		enter_folder(category_name, folder_name)
		return

	if category_name == "ImageCategory":
		var image_path: String = entry.get_meta("path", "")

		if image_path.is_empty():
			return

		var image_paths: Array[String] = []

		for media_entry in media_labels[category_name]:
			if media_entry.has_meta("path"):
				image_paths.append(media_entry.get_meta("path"))

		var viewer_scene = preload("res://scenes/apps/image_viewer.tscn")
		var viewer = viewer_scene.instantiate()

		get_tree().root.add_child(viewer)
		viewer.set_image_list(image_paths, image_path)


func enter_folder(category_name: String, folder_name: String) -> void:
	var current_path: String = str(media_current_paths[category_name])
	var new_path: String = current_path.path_join(folder_name)

	if not DirAccess.dir_exists_absolute(new_path):
		return

	var history: Array = media_path_history[category_name]
	history.append(current_path)

	media_path_history[category_name] = history
	media_current_paths[category_name] = new_path

	controller.selected_option = 0
	populate_media_options(category_name)


func go_back(category_name: String) -> void:
	var history: Array = media_path_history[category_name]

	if history.is_empty():
		return

	var previous_path: String = str(history.pop_back())

	media_path_history[category_name] = history
	media_current_paths[category_name] = previous_path

	controller.selected_option = 0
	populate_media_options(category_name)


# --------------------------------------------------
# IMAGE THUMBNAILS
# --------------------------------------------------
func load_image_file(image_path: String) -> Image:
	var image := Image.new()
	var file_data: PackedByteArray = FileAccess.get_file_as_bytes(image_path)

	if file_data.is_empty():
		return null

	# Detect WebP files regardless of their extension.
	if (
		file_data.size() >= 12
		and file_data.slice(0, 4) == "RIFF".to_ascii_buffer()
		and file_data.slice(8, 12) == "WEBP".to_ascii_buffer()
	):
		if image.load_webp_from_buffer(file_data) != OK:
			return null
	else:
		if image.load(image_path) != OK:
			return null

	return image
func get_image_thumbnail(image_path: String) -> Texture2D:
	if media_thumbnail_cache.has(image_path):
		return media_thumbnail_cache[image_path] as Texture2D

	var image: Image = ImageLoader.load_image_file(image_path)

	if image == null:
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
	media_thumbnail_cache[image_path] = texture

	return texture

# --------------------------------------------------
# MUSIC AND VIDEO THUMBNAILS
# --------------------------------------------------

func get_media_thumbnail(category_name: String, media_path: String) -> Texture2D:
	if category_name != "MusicCategory" and category_name != "VideoCategory":
		return null

	if not FileAccess.file_exists(media_path):
		return null

	var cache_dir: String = "user://media_thumbnails/" + category_name
	var absolute_cache_dir: String = ProjectSettings.globalize_path(cache_dir)

	DirAccess.make_dir_recursive_absolute(absolute_cache_dir)

	var cache_key: String = str(media_path.hash()) + "_" + str(
		FileAccess.get_modified_time(media_path)
	)

	var cache_path: String = cache_dir.path_join(cache_key + ".png")
	var absolute_cache_path: String = ProjectSettings.globalize_path(cache_path)

	if FileAccess.file_exists(cache_path):
		return load_thumbnail_texture(cache_path)

	if media_thumbnail_jobs.has(media_path):
		return null

	media_thumbnail_jobs[media_path] = true

	WorkerThreadPool.add_task(
		_generate_media_thumbnail.bind(
			category_name,
			media_path,
			cache_path,
			absolute_cache_path
		)
	)

	return null


func find_nearby_album_art(media_path: String) -> String:
	var folder: String = media_path.get_base_dir()
	var basename: String = media_path.get_basename()

	var candidates: PackedStringArray = [
		"cover.jpg",
		"cover.png",
		"folder.jpg",
		"folder.png",
		"front.jpg",
		"front.png",
		"album.jpg",
		"album.png",
		basename + ".jpg",
		basename + ".png",
		basename + ".webp"
	]

	for candidate in candidates:
		var candidate_path: String = folder.path_join(candidate)

		if FileAccess.file_exists(candidate_path):
			return candidate_path

	return ""


func load_thumbnail_texture(image_path: String) -> Texture2D:
	var image := Image.new()

	if image.load(image_path) != OK:
		return null

	return ImageTexture.create_from_image(image)


func _generate_media_thumbnail(
	category_name: String,
	media_path: String,
	cache_path: String,
	absolute_cache_path: String
) -> void:
	var success: bool = false
	var result: int = -1

	if category_name == "MusicCategory":
		var nearby_art: String = find_nearby_album_art(media_path)

		if nearby_art != "":
			var art_image := Image.new()

			if art_image.load(nearby_art) == OK:
				art_image.resize(320, 320, Image.INTERPOLATE_LANCZOS)

				if art_image.save_png(absolute_cache_path) == OK:
					success = true

	if not success:
		var ffmpeg_args: PackedStringArray = ["-y"]

		if category_name == "MusicCategory":
			ffmpeg_args.append_array([
				"-i", media_path,
				"-map", "0:v:0",
				"-frames:v", "1",
				"-vf", "scale=320:320:force_original_aspect_ratio=decrease",
				absolute_cache_path
			])

		elif category_name == "VideoCategory":
			ffmpeg_args.append_array([
				"-ss", "10",
				"-i", media_path,
				"-frames:v", "1",
				"-vf", "scale=320:-1",
				absolute_cache_path
			])

		var output: Array = []
		result = OS.execute("ffmpeg", ffmpeg_args, output, true)

		if result != 0 and category_name == "VideoCategory":
			ffmpeg_args = [
				"-y",
				"-ss", "1",
				"-i", media_path,
				"-frames:v", "1",
				"-vf", "scale=320:-1",
				absolute_cache_path
			]

			output.clear()
			result = OS.execute("ffmpeg", ffmpeg_args, output, true)

		success = result == 0 and FileAccess.file_exists(cache_path)

	call_deferred(
		"_on_media_thumbnail_ready",
		category_name,
		media_path,
		cache_path,
		success
	)


func _on_media_thumbnail_ready(
	category_name: String,
	media_path: String,
	cache_path: String,
	success: bool
) -> void:
	media_thumbnail_jobs.erase(media_path)

	if not success:
		push_warning("Could not generate thumbnail: " + media_path)
		return

	var thumbnail: Texture2D = load_thumbnail_texture(cache_path)

	if thumbnail == null:
		return

	if not media_current_paths.has(category_name):
		return

	if media_path.get_base_dir() != str(media_current_paths[category_name]):
		return

	var options: VBoxContainer = get_media_options(category_name)
	var entry_name: String = "File_" + media_path.get_file()

	var entry: Control = options.get_node_or_null(entry_name) as Control

	if entry == null:
		return

	var old_icon: Node = entry.get_node_or_null("Icon")

	if old_icon != null:
		old_icon.queue_free()

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = thumbnail
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(0, 5)
	icon.size = Vector2(70, 70)

	entry.add_child(icon)
