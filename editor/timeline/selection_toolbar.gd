class_name SelectionToolbar
extends PanelContainer

signal delete_pressed
signal duplicate_pressed
signal select_all_pressed
signal deselect_pressed

@onready var delete_button: Button = %DeleteButton
@onready var duplicate_button: Button = %DuplicateButton
@onready var select_all_button: Button = %SelectAllButton
@onready var deselect_button: Button = %DeselectButton
@onready var animation_player: AnimationPlayer = %AnimationPlayer

var _is_showing: bool = false

func _ready():
	modulate.a = 0.0
	visible = false

func show_toolbar():
	if _is_showing:
		return
	
	_is_showing = true
	visible = true
	animation_player.play("toolbar/fade_in")

func hide_toolbar():
	if not _is_showing:
		return
	
	_is_showing = false
	animation_player.play("toolbar/fade_out")
	animation_player.animation_finished.connect(_on_fade_out_finished, CONNECT_ONE_SHOT)

func _on_fade_out_finished(_anim_name: String):
	visible = false

func set_selection_count(count: int):
	
	delete_button.disabled = count == 0
	duplicate_button.disabled = count == 0
	deselect_button.disabled = count == 0
	
	
	if count > 1:
		delete_button.tooltip_text = "Delete %d selected notes" % count
		duplicate_button.tooltip_text = "Duplicate %d selected notes" % count
	else:
		delete_button.tooltip_text = "Delete selected note"
		duplicate_button.tooltip_text = "Duplicate selected note"


func _on_delete_button_pressed():
	delete_pressed.emit()
	_provide_haptic_feedback()

func _on_duplicate_button_pressed():
	duplicate_pressed.emit()
	_provide_haptic_feedback()

func _on_select_all_button_pressed():
	select_all_pressed.emit()
	_provide_haptic_feedback()

func _on_deselect_button_pressed():
	deselect_pressed.emit()
	hide_toolbar()
	_provide_haptic_feedback()

func _provide_haptic_feedback():
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(10) 


func _gui_input(event: InputEvent):
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		accept_event()
