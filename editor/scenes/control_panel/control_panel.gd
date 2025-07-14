extends Control

signal play()
signal pause()
signal stop()

@onready var buttons = {
	"Play": %PlayButton,
	"Pause": %PauseButton,
	"Stop": %StopButton,
	#"Add": %AddButton,
}

func _on_PlayButton_pressed():
	play.emit()
	buttons.Play.disabled = true
	buttons.Pause.disabled = false
	buttons.Stop.disabled = false

func _on_PauseButton_pressed():
	pause.emit()
	buttons.Play.disabled = false
	buttons.Pause.disabled = true
	buttons.Stop.disabled = false

func _on_StopButton_pressed():
	stop.emit()
	buttons.Play.disabled = false
	buttons.Pause.disabled = true
	buttons.Stop.disabled = true

func _on_finished(_n = ""):
	await get_tree().process_frame
	buttons.Play.disabled = false
	buttons.Pause.disabled = true
	buttons.Stop.disabled = true
