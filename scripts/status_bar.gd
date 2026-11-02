extends Node

var system_info = preload("res://scripts/system_info.gd").new()

var time_label: Label
var battery_label: Label
var battery_icon: TextureRect

var battery_percentage: int = -1

var clock_timer: Timer
var battery_timer: Timer


func initialise(
	main_time_label: Label,
	main_battery_label: Label,
	main_battery_icon: TextureRect
) -> void:
	time_label = main_time_label
	battery_label = main_battery_label
	battery_icon = main_battery_icon

	setup_timers()
	update_status()


func setup_timers() -> void:
	clock_timer = Timer.new()
	clock_timer.wait_time = 15.0
	clock_timer.timeout.connect(update_clock)
	add_child(clock_timer)
	clock_timer.start()

	battery_timer = Timer.new()
	battery_timer.wait_time = 30.0
	battery_timer.timeout.connect(update_battery)
	add_child(battery_timer)
	battery_timer.start()


func update_status() -> void:
	update_clock()
	update_battery()


func update_clock() -> void:
	var time_text: String = system_info.get_clock_text()
	time_label.text = time_text.substr(0, 5)


func update_battery() -> void:
	battery_percentage = system_info.get_battery_percentage()

	if battery_percentage < 0:
		battery_label.text = "--%"
		return

	battery_label.text = "%d%%" % battery_percentage

	if battery_percentage <= 25:
		battery_icon.texture = load("res://assets/battery25.png")
	elif battery_percentage <= 50:
		battery_icon.texture = load("res://assets/battery50.png")
	elif battery_percentage <= 75:
		battery_icon.texture = load("res://assets/battery75.png")
	else:
		battery_icon.texture = load("res://assets/batteryfull.png")
