class_name NewTrackDialog
extends ConfirmationDialog

@onready var track_type_option: OptionButton = %TrackTypeOption
@onready var instrument_label: Label = %InstrumentLabel
@onready var instrument_option: OptionButton = %InstrumentOption

var _instrument_ids: Array[String] = []

func _ready():
	track_type_option.clear()
	track_type_option.add_item("Audio Track")
	track_type_option.set_item_metadata(0, TrackData.TrackType.AUDIO)
	track_type_option.add_item("Instrument Track")
	track_type_option.set_item_metadata(1, TrackData.TrackType.INSTRUMENT)
	track_type_option.item_selected.connect(_on_track_type_selected)
	_populate_instruments()
	_on_track_type_selected(0)

func get_selected_type() -> TrackData.TrackType:
	var selected_index = track_type_option.selected
	if selected_index >= 0:
		return track_type_option.get_item_metadata(selected_index)
	return TrackData.TrackType.AUDIO

func get_selected_instrument() -> String:
	if instrument_option.selected >= 0 and instrument_option.selected < _instrument_ids.size():
		var instrument_id = _instrument_ids[instrument_option.selected]
		var scene = InstrumentRegistry.get_instrument_scene(instrument_id)
		if scene:
			return scene.resource_path # HACK: definitely not optimal
	return ""

func _populate_instruments():
	_instrument_ids.clear()
	instrument_option.clear()
	
	var instruments = InstrumentRegistry.get_all_instruments()
	
	# Sort by name for consistent ordering
	var sorted_ids = instruments.keys()
	sorted_ids.sort_custom(func(a, b): return instruments[a]["name"] < instruments[b]["name"])
	
	for id in sorted_ids:
		_instrument_ids.append(id)
		instrument_option.add_item(instruments[id]["name"])
		
	if _instrument_ids.is_empty():
		instrument_option.add_item("No instruments found")
		instrument_option.disabled = true

func _on_track_type_selected(index: int):
	var is_instrument = track_type_option.get_item_metadata(index) == TrackData.TrackType.INSTRUMENT
	instrument_label.visible = is_instrument
	instrument_option.visible = is_instrument
