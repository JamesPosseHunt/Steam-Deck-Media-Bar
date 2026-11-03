
extends Node

const APPLICATIONS_PATH := "/usr/share/applications"

func get_installed_apps() -> Array[Dictionary]:
	var apps: Array[Dictionary] = []
	print("Scanning applications directory...")
	var directory := DirAccess.open(APPLICATIONS_PATH)
	print("Directory opened: ", directory != null)

	if directory == null:
		push_warning("Could not open applications directory.")
		return apps

	directory.list_dir_begin()

	var file_name := directory.get_next()

	while file_name != "":
		if not directory.current_is_dir() and file_name.ends_with(".desktop"):
			var app := read_desktop_file(
				APPLICATIONS_PATH.path_join(file_name)
			)

			if not app.is_empty():
				apps.append(app)

		file_name = directory.get_next()

	directory.list_dir_end()

	apps.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return a["name"].to_lower() < b["name"].to_lower()
	)
	print("Applications found: ", apps.size())
	return apps

func read_desktop_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)

	if file == null:
		return {}

	var in_desktop_entry := false
	var values: Dictionary = {}

	while not file.eof_reached():
		var line := file.get_line().strip_edges()

		if line.is_empty() or line.begins_with("#"):
			continue

		if line.begins_with("[") and line.ends_with("]"):
			in_desktop_entry = line == "[Desktop Entry]"
			continue

		if not in_desktop_entry:
			continue

		var separator := line.find("=")

		if separator == -1:
			continue

		var key := line.substr(0, separator).strip_edges()
		var value := line.substr(separator + 1).strip_edges()

		# Ignore translated keys such as Name[en_GB].
		if key.contains("["):
			continue

		values[key] = value

	file.close()

	if values.get("Type", "") != "Application":
		return {}

	if values.get("Hidden", "false").to_lower() == "true":
		return {}

	if values.get("NoDisplay", "false").to_lower() == "true":
		return {}

	var app_name: String = values.get("Name", "")
	var exec: String = values.get("Exec", "")
	var icon: String = values.get("Icon", "")

	if app_name.is_empty() or exec.is_empty():
		return {}

	return {
		"name": app_name,
		"exec": exec,
		"icon": icon,
		"path": path
	}
