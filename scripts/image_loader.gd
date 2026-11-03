extends Node


func load_image_file(image_path: String) -> Image:
	var image := Image.new()
	var file_data: PackedByteArray = FileAccess.get_file_as_bytes(image_path)

	if file_data.is_empty():
		return null

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
