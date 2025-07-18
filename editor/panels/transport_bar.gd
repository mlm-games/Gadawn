class_name TransportBar
extends PanelContainer

signal play_pressed
signal stop_pressed
signal playback_scrubbed(time_sec: float)

@onready var play_button: Button = %PlayButton
@onready var stop_button: Button = %StopButton
@onready var time_label: Label = %TimeLabel

func update_time_display(time_sec: float):
	var minutes = int(time_sec / 60)
	var seconds = int(time_sec) % 60
	var millis = int((time_sec - int(time_sec)) * 1000)
	time_label.text = "%02d:%02d:%03d" % [minutes, seconds, millis]

func _on_play_button_pressed():
	play_pressed.emit()

func _on_stop_button_pressed():
	stop_pressed.emit()