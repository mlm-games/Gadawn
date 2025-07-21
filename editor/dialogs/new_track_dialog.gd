class_name NewTrackDialog
extends ConfirmationDialog

@onready var track_type_option: OptionButton = %TrackTypeOption
@onready var instrument_label: Label = %InstrumentLabel
@onready var instrument_option: OptionButton = %InstrumentOption

var _instrument_paths: Array[String] = []

func _ready():
	track_type_option.clear()
	track_type_option.add_item("Audio Track")
	track_type_option.set_item_metadata(0, TrackData.TrackType.AUDIO)
	track_type_option.add_item("Instrument Track")
	track_type_option.set_item_metadata(1, TrackData.TrackType.INSTRUMENT)
	track_type_option.item_selected.connect(_on_track_type_selected)
	_scan_instruments()
	_on_track_type_selected(0)

func get_selected_type() -> TrackData.TrackType:
	var selected_index = track_type_option.selected
	if selected_index >= 0:
		return track_type_option.get_item_metadata(selected_index)
	return TrackData.TrackType.AUDIO

func get_selected_instrument() -> String:
	if instrument_option.selected >= 0 and instrument_option.selected < _instrument_paths.size():
		return _instrument_paths[instrument_option.selected]
	return ""

func _scan_instruments():
	_instrument_paths.clear()
	instrument_option.clear()
	
	var path = C.PATHS.INSTRUMENTS_FOLDER
	var dir = DirAccess.open(path)
	if not dir: return

	var subdirs = dir.get_directories()
	for subdir_name in subdirs:
		var scene_path = path.path_join(subdir_name).path_join("instrument.tscn")
		if FileAccess.file_exists(scene_path):
			_instrument_paths.append(scene_path)
			instrument_option.add_item(subdir_name.capitalize())

func _on_track_type_selected(index: int):
	var is_instrument = track_type_option.get_item_metadata(index) == TrackData.TrackType.INSTRUMENT
	instrument_label.visible = is_instrument
	instrument_option.visible = is_instrument
