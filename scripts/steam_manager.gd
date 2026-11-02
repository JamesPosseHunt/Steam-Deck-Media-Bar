extends RefCounted

signal steam_initialized(username: String)
signal avatar_loaded(texture: Texture2D)

func initialise_steam() -> void:
	var result: Dictionary = Steam.steamInitEx()
	print("Steam initialisation: ", result)

	if result["status"] == 0:
		var username: String = Steam.getPersonaName()
		steam_initialized.emit(username)

		if not Steam.avatar_loaded.is_connected(_on_avatar_loaded):
			Steam.avatar_loaded.connect(_on_avatar_loaded)

		Steam.getPlayerAvatar(3)
	else:
		push_warning("Steam initialisation failed: " + str(result))

func _on_avatar_loaded(
	steam_id: int,
	avatar_size: int,
	avatar_buffer: Array
) -> void:
	print("Avatar loaded for Steam ID: ", steam_id)

	var image := Image.create_from_data(
		avatar_size,
		avatar_size,
		false,
		Image.FORMAT_RGBA8,
		PackedByteArray(avatar_buffer)
	)

	avatar_loaded.emit(ImageTexture.create_from_image(image))

func launch_game(appid: int) -> void:
	OS.shell_open("steam://run/" + str(appid))
