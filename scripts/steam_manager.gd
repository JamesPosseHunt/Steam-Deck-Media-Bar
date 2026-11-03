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


func get_friends() -> Array[Dictionary]:
	var friends: Array[Dictionary] = []

	var friend_flags: int = Steam.FRIEND_FLAG_IMMEDIATE
	var friend_count: int = Steam.getFriendCount(friend_flags)

	if friend_count < 0:
		push_warning("Could not retrieve Steam friends.")
		return friends

	for i in range(friend_count):
		var steam_id: int = Steam.getFriendByIndex(i, friend_flags)

		var friend_name: String = Steam.getFriendPersonaName(steam_id)
		var persona_state: int = Steam.getFriendPersonaState(steam_id)
		var avatar: Texture2D = get_friend_avatar(steam_id)
		print("Avatar for ", friend_name, ": ", avatar != null)
		var status: String = "Offline"

		match persona_state:
			1:
				status = "Online"
			2:
				status = "Busy"
			3:
				status = "Away"
			4:
				status = "Snooze"
			5:
				status = "Looking to Trade"
			6:
				status = "Looking to Play"

		friends.append({
			"steam_id": steam_id,
			"name": friend_name,
			"status": status
		})
	return friends
func get_friend_avatar(steam_id: int) -> Texture2D:
	var image_handle: int = Steam.getLargeFriendAvatar(steam_id)

	if image_handle <= 0:
		return null

	var image_size: Dictionary = Steam.getImageSize(image_handle)

	if image_size.is_empty():
		return null

	var image_result: Dictionary = Steam.getImageRGBA(image_handle)

	if not image_result.get("success", false):
		return null

	var image_data := PackedByteArray(image_result["buffer"])

	var image := Image.create_from_data(
		image_size["width"],
		image_size["height"],
		false,
		Image.FORMAT_RGBA8,
		image_data
	)

	return ImageTexture.create_from_image(image)
