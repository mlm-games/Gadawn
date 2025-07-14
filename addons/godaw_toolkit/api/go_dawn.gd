extends Node

signal loading_progress_max_value_changed(max_value)
signal loading_progress_value_changed()
signal loading_instrument_changed(instrument_named)

var instruments : Dictionary[StringName, PackedScene] = {}

func register_instrument(name: StringName, instrument: PackedScene):
	instruments[name] = instrument

func get_instrument(name: String) -> Instrument:
	return instruments[name].instantiate()

func load_instruments():
	var dir = DirAccess.open("res://instruments")
	dir.list_dir_begin()

	var instruments = []

	var instrument_name = dir.get_next()
	while instrument_name != "":
		if dir.file_exists("./%s/instrument.tscn" % instrument_name):
			instruments.append(instrument_name)
		else:
			push_warning("Instrument %s does not have an instrument.tscn file" % instrument_name)

		instrument_name = dir.get_next()

	loading_progress_max_value_changed.emit(instruments.size())

	for name in instruments:
		loading_instrument_changed.emit(name)

		await get_tree().process_frame
		var instrument: PackedScene = load("%s/%s/instrument.tscn" % [dir.get_current_dir(), name])
		GoDawn.register_instrument(name, instrument)
		loading_progress_value_changed.emit()
