
extends RefCounted

func get_clock_text() -> String:
	return Time.get_time_string_from_system()

func get_battery_percentage() -> int:
	var output: Array = []
	var exit_code := OS.execute(
		"/bin/cat",
		["/sys/class/power_supply/BAT0/capacity"],
		output,
		true
	)

	if exit_code != 0 or output.is_empty():
		push_warning("Failed to read battery percentage.")
		return -1

	var value: String = str(output[0]).strip_edges()

	if not value.is_valid_int():
		push_warning("Invalid battery percentage: " + value)
		return -1

	var percentage := value.to_int()

	if percentage < 0 or percentage > 100:
		return -1

	return percentage
