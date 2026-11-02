extends Node

const GAME_NAME_CACHE_PATH := "user://steam_game_names.json"

var game_name_cache: Dictionary = {}
var steam_name_request: HTTPRequest


func initialise() -> void:
	steam_name_request = HTTPRequest.new()
	add_child(steam_name_request)
	load_game_name_cache()


# --------------------------------------------------
# GAME DISCOVERY
# --------------------------------------------------

func get_all_games() -> Array[Dictionary]:
	var games_by_id: Dictionary = {}

	for game in get_installed_games():
		games_by_id[game["appid"]] = game

	for game in get_previously_played_games():
		if not games_by_id.has(game["appid"]):
			games_by_id[game["appid"]] = game

	var games: Array[Dictionary] = []

	for game in games_by_id.values():
		games.append(game)

	games.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return a["name"].to_lower() < b["name"].to_lower()
	)

	return games


func get_installed_games() -> Array[Dictionary]:
	var games: Array[Dictionary] = []
	var home: String = OS.get_environment("HOME")
	var steamapps_path: String = home.path_join(
		".steam/steam/steamapps"
	)

	var dir := DirAccess.open(steamapps_path)

	if dir == null:
		push_warning("Could not open Steam steamapps directory.")
		return games

	var appid_regex := RegEx.new()
	appid_regex.compile('"appid"\\s+"(\\d+)"')

	var name_regex := RegEx.new()
	name_regex.compile('"name"\\s+"([^"]+)"')

	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		if file_name.begins_with("appmanifest_") and file_name.ends_with(".acf"):
			var file := FileAccess.open(
				steamapps_path.path_join(file_name),
				FileAccess.READ
			)

			if file != null:
				var content: String = file.get_as_text()
				file.close()

				var appid_match = appid_regex.search(content)
				var name_match = name_regex.search(content)

				if appid_match != null and name_match != null:
					games.append({
						"appid": appid_match.get_string(1),
						"name": name_match.get_string(1)
					})

		file_name = dir.get_next()

	dir.list_dir_end()
	return games


func get_previously_played_games() -> Array[Dictionary]:
	var games: Array[Dictionary] = []
	var home: String = OS.get_environment("HOME")
	var userdata_path: String = home.path_join(
		".steam/steam/userdata"
	)

	var userdata_dir := DirAccess.open(userdata_path)

	if userdata_dir == null:
		push_warning("Could not open Steam userdata directory.")
		return games

	userdata_dir.list_dir_begin()
	var user_id: String = userdata_dir.get_next()

	while user_id != "":
		if userdata_dir.current_is_dir() and user_id.is_valid_int():
			var config_path: String = userdata_path.path_join(
				user_id
			).path_join("config/localconfig.vdf")

			if FileAccess.file_exists(config_path):
				var file := FileAccess.open(config_path, FileAccess.READ)

				if file != null:
					var content: String = file.get_as_text()
					file.close()

					var apps_start: int = content.find('"apps"')

					if apps_start != -1:
						var apps_content: String = content.substr(apps_start)

						var app_regex := RegEx.new()
						app_regex.compile(
							'"(\\d+)"\\s*\\{[^}]*"LastPlayed"'
						)

						for match_result in app_regex.search_all(apps_content):
							var appid: String = match_result.get_string(1)

							games.append({
								"appid": appid,
								"name": "App " + appid
							})

		user_id = userdata_dir.get_next()

	userdata_dir.list_dir_end()
	return games


# --------------------------------------------------
# STEAM APP NAME AND TYPE LOOKUP
# --------------------------------------------------

func test_game_name_lookup(appid: String) -> void:
	var url: String = (
		"https://store.steampowered.com/api/appdetails/"
		+ "?appids=" + appid
		+ "&l=english"
	)

	var error: Error = steam_name_request.request(url)

	if error != OK:
		push_warning("Could not start Steam name lookup.")
		return

	var response: Array = await steam_name_request.request_completed

	if response[1] != 200:
		push_warning("Steam lookup failed. HTTP: " + str(response[1]))
		return

	var json = JSON.parse_string(
		response[3].get_string_from_utf8()
	)

	if not json is Dictionary or not json.has(appid):
		push_warning("Invalid Steam response for AppID " + appid)
		return

	var app_data: Dictionary = json[appid]

	if app_data.get("success", false):
		print("Resolved ", appid, " as ", app_data["data"]["name"])
	else:
		print("Steam couldn't resolve AppID ", appid)


func load_game_name_cache() -> void:
	if not FileAccess.file_exists(GAME_NAME_CACHE_PATH):
		return

	var file := FileAccess.open(
		GAME_NAME_CACHE_PATH,
		FileAccess.READ
	)

	if file == null:
		return

	var data = JSON.parse_string(file.get_as_text())
	file.close()

	if data is Dictionary:
		game_name_cache = data


func save_game_name_cache() -> void:
	var file := FileAccess.open(
		GAME_NAME_CACHE_PATH,
		FileAccess.WRITE
	)

	if file == null:
		push_warning("Could not save game name cache.")
		return

	file.store_string(JSON.stringify(game_name_cache, "\t"))
	file.close()


func resolve_game_name(appid: String) -> String:
	if game_name_cache.has(appid):
		var cached = game_name_cache[appid]

		if cached is Dictionary:
			return str(cached.get("name", "App " + appid))

		return str(cached)

	var url: String = (
		"https://store.steampowered.com/api/appdetails/"
		+ "?appids=" + appid
		+ "&l=english"
	)

	var error: Error = steam_name_request.request(url)

	if error != OK:
		return "App " + appid

	var response: Array = await steam_name_request.request_completed

	if response[1] != 200:
		return "App " + appid

	var json = JSON.parse_string(
		response[3].get_string_from_utf8()
	)

	if not json is Dictionary or not json.has(appid):
		return "App " + appid

	var app_data: Dictionary = json[appid]

	if not app_data.get("success", false):
		return "App " + appid

	var data: Dictionary = app_data["data"]

	var game_name: String = str(data.get("name", "App " + appid))
	var app_type: String = str(data.get("type", ""))

	game_name_cache[appid] = {
		"name": game_name,
		"type": app_type
	}

	save_game_name_cache()

	return game_name


func is_game_app(appid: String) -> bool:
	if game_name_cache.has(appid):
		var cached = game_name_cache[appid]

		if cached is Dictionary:
			var cached_type: String = str(cached.get("type", ""))

			if cached_type != "":
				return cached_type == "game"

	await resolve_game_name(appid)

	var updated = game_name_cache.get(appid, {})

	if updated is Dictionary:
		return str(updated.get("type", "")) == "game"

	return true
