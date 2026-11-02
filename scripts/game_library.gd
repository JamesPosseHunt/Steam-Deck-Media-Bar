
extends RefCounted

func get_all_games() -> Array[Dictionary]:
	var games_by_id: Dictionary = {}

	# Add installed games.
	for game in get_installed_games():
		games_by_id[game["appid"]] = game

	# Add games found in local Steam account data.
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
	var steamapps_path := OS.get_environment("HOME") + "/.steam/steam/steamapps"
	var dir := DirAccess.open(steamapps_path)

	if dir == null:
		push_warning("Could not open Steam steamapps directory.")
		return games

	var appid_regex := RegEx.new()
	appid_regex.compile('"appid"\\s+"(\\d+)"')

	var name_regex := RegEx.new()
	name_regex.compile('"name"\\s+"([^"]+)"')

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name.begins_with("appmanifest_") and file_name.ends_with(".acf"):
			var file := FileAccess.open(
				steamapps_path.path_join(file_name),
				FileAccess.READ
			)

			if file != null:
				var content := file.get_as_text()
				file.close()

				var appid_match := appid_regex.search(content)
				var name_match := name_regex.search(content)

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

	var userdata_path := OS.get_environment("HOME").path_join(
        ".steam/steam/userdata"
	)

	var userdata_dir := DirAccess.open(userdata_path)

	if userdata_dir == null:
		push_warning("Could not open Steam userdata directory.")
		return games

	userdata_dir.list_dir_begin()
	var user_id := userdata_dir.get_next()

	while user_id != "":
		if userdata_dir.current_is_dir() and user_id.is_valid_int():
			var config_path := userdata_path.path_join(
				user_id
			).path_join("config/localconfig.vdf")

			if FileAccess.file_exists(config_path):
				var file := FileAccess.open(config_path, FileAccess.READ)

				if file != null:
					var content := file.get_as_text()
					file.close()

					var apps_start := content.find('"apps"')

					if apps_start != -1:
						var apps_content := content.substr(apps_start)

						var app_regex := RegEx.new()
						app_regex.compile(
                            '"(\\d+)"\\s*\\{[^}]*"LastPlayed"'
						)

						for match in app_regex.search_all(apps_content):
							var appid := match.get_string(1)

							games.append({
								"appid": appid,
								"name": "App " + appid
							})

		user_id = userdata_dir.get_next()

	userdata_dir.list_dir_end()
	return games
