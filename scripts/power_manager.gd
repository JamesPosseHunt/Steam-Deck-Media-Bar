
extends Node

var controller: Control
var power_confirmation: ConfirmationDialog
var pending_power_action: String = ""


func initialise(main_controller: Control) -> void:
	controller = main_controller
	setup_confirmation()


func setup_confirmation() -> void:
	power_confirmation = ConfirmationDialog.new()
	power_confirmation.title = "Confirm Power Action"
	power_confirmation.dialog_text = "Are you sure?"

	power_confirmation.confirmed.connect(
		_on_confirmation_confirmed
	)

	add_child(power_confirmation)


func activate_option(selected_entry: Control) -> void:
	match selected_entry.name:
		"SleepLabel":
			pending_power_action = "suspend"
			power_confirmation.dialog_text = "Put the system to sleep?"

		"RestartLabel":
			pending_power_action = "reboot"
			power_confirmation.dialog_text = "Are you sure you want to restart?"

		"ShutdownLabel":
			pending_power_action = "poweroff"
			power_confirmation.dialog_text = "Are you sure you want to shut down?"

		"SwitchAccountLabel":
			print("Switch Account selected")
			return
		"DesktopLabel":
			get_tree().quit()
			return
		_:
			return

	power_confirmation.popup_centered()


func _on_confirmation_confirmed() -> void:
	match pending_power_action:
		"suspend":
			OS.execute("systemctl", ["suspend"])

		"reboot":
			OS.execute("systemctl", ["reboot"])

		"poweroff":
			OS.execute("systemctl", ["poweroff"])

	pending_power_action = ""
