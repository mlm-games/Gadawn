class_name TrackHeaderUI
extends PanelContainer

var track_data: TrackData

@onready var track_name: Label = %TrackName
@onready var mute_button: Button = %MuteButton
@onready var solo_button: Button = %SoloButton

func set_track_data(p_track_data: TrackData):
	track_data = p_track_data
	track_name.text = track_data.track_name
	mute_button.button_pressed = track_data.is_muted
	solo_button.button_pressed = track_data.is_solo
	mute_button.toggled.connect(_on_mute_toggled)
	solo_button.toggled.connect(_on_solo_toggled)

func _on_mute_toggled(is_pressed: bool):
	track_data.is_muted = is_pressed

func _on_solo_toggled(is_pressed: bool):
	track_data.is_solo = is_pressed