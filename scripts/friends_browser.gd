extends Node

var controller: Control
var friends_options: VBoxContainer
var steam_manager: RefCounted


func initialise(
	main_controller: Control,
	main_friends_options: VBoxContainer,
	main_steam_manager: RefCounted
) -> void:
	controller = main_controller
	friends_options = main_friends_options
	steam_manager = main_steam_manager


func populate_friends() -> void:
	for child in friends_options.get_children():
		child.queue_free()

	var friends: Array[Dictionary] = steam_manager.get_friends()

	for friend in friends:
		var entry := create_friend_entry(friend)
		friends_options.add_child(entry)

	if controller.get_current_category_name() == "FriendsCategory":
		controller.update_current_options()
		controller.update_selection_display()


func create_friend_entry(friend: Dictionary) -> Control:
	var entry := Control.new()
	entry.name = "Friend_" + str(friend["steam_id"])
	entry.custom_minimum_size = Vector2(0, 80)
	
	var avatar := TextureRect.new()
	avatar.name = "Avatar"
	avatar.position = Vector2(10, 8)
	avatar.size = Vector2(64, 64)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	var avatar_texture: Texture2D = steam_manager.get_friend_avatar(
		int(friend["steam_id"])
	)

	if avatar_texture != null:
		avatar.texture = avatar_texture

	entry.add_child(avatar)
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = str(friend["name"])
	name_label.position = Vector2(90, 5)
	name_label.size = Vector2(400, 35)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	entry.add_child(name_label)

	var status_label := Label.new()
	status_label.name = "Status"
	status_label.text = str(friend["status"])
	status_label.position = Vector2(90, 40)
	status_label.size = Vector2(400, 30)
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	entry.add_child(status_label)

	return entry
