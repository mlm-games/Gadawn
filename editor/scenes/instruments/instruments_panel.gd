extends Control

signal instrument_chosen(instrument)

func reload_instruments():
	var dir = DirAccess.open("res://instruments")

	for instrument in GoDawn.instruments:
		var btn = Button.new()

		var icon = null
		if dir.file_exists("./%s/icon.png" % instrument):
			icon = load("%s/%s/icon.png" % [dir.get_current_dir(), instrument])
		else:
			icon = load("res://themes/default/images/default_icon.png")

		btn.icon = icon
		@warning_ignore("incompatible_ternary")
		btn.text = instrument if instrument.length() <= 20 else instrument.substr(0, 17) + "..."
		btn.flat = false
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_Instrument_pressed.bind(btn))
		%InstrumentsContainer.add_child(btn)

func _on_Instrument_pressed(button) -> void:
	instrument_chosen.emit(button)
