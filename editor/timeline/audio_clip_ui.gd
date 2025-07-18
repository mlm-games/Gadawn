class_name AudioClipUI
extends PanelContainer

signal clip_moved(clip_event: AudioClipEvent, new_pos: Vector2)

var clip_event: AudioClipEvent
var project: Project

var _is_dragging = false
var _drag_start_pos: Vector2

@onready var clip_label: Label = %ClipLabel

func _ready():
	clip_label.text = clip_event.audio_stream.resource_path.get_file()

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_is_dragging = event.pressed
		if _is_dragging:
			_drag_start_pos = get_global_mouse_position() - global_position
		get_viewport().set_input_as_handled()
	
	if event is InputEventMouseMotion and _is_dragging:
		global_position = get_global_mouse_position() - _drag_start_pos
		clip_moved.emit(clip_event, position)
		get_viewport().set_input_as_handled()
