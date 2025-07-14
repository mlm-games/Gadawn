extends PanelContainer

signal play_pressed()
signal pause_pressed()
signal stop_pressed()
signal bpm_changed(bpm: float)

@onready var play_button = %PlayButton
@onready var pause_button = %PauseButton
@onready var stop_button = %StopButton
@onready var bpm_spinbox = %BPMSpinBox

func _ready():
	play_button.disabled = false
	pause_button.disabled = true
	stop_button.disabled = true
	
	# Connect button signals
	play_button.pressed.connect(_on_play_button_pressed)
	pause_button.pressed.connect(_on_pause_button_pressed)
	stop_button.pressed.connect(_on_stop_button_pressed)
	bpm_spinbox.value_changed.connect(func(val): bpm_changed.emit(val))

func _on_play_button_pressed():
	play_pressed.emit()

func _on_pause_button_pressed():
	pause_pressed.emit()

func _on_stop_button_pressed():
	stop_pressed.emit()

func on_playback_started():
	play_button.disabled = true
	pause_button.disabled = false
	stop_button.disabled = false

func on_playback_stopped():
	play_button.disabled = false
	pause_button.disabled = true
	stop_button.disabled = true
