class_name AudioClipUI
extends PanelContainer

signal clip_moved(clip_event: AudioClipEvent, new_pos: Vector2)

var clip_event: AudioClipEvent
var project: Project

var _is_dragging = false
var _drag_start_pos: Vector2
var _is_selected = false

func _ready():
	# Set up appearance
	custom_minimum_size = Vector2(80, 60)
	
	# Create label if it doesn't exist
	var label = Label.new()
	label.name = "ClipLabel"
	if clip_event and clip_event.audio_stream:
		label.text = clip_event.audio_stream.resource_path.get_file()
	else:
		label.text = "Audio Clip"
	label.clip_text = true
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	
	# Set theme overrides for visibility
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.3, 0.4, 0.5, 0.8)
	panel_style.border_color = Color(0.5, 0.6, 0.7, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", panel_style)

func _draw():
	if _is_selected:
		draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE, false, 3.0)

func is_selected() -> bool:
	return _is_selected

func set_selected(selected: bool):
	_is_selected = selected
	queue_redraw()

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_is_dragging = true
			_drag_start_pos = event.global_position - global_position
			set_selected(true)
		else:
			_is_dragging = false
		accept_event()
	
	elif event is InputEventMouseMotion and _is_dragging:
		var drag_delta = event.global_position - (global_position + _drag_start_pos)
		position += drag_delta
		clip_moved.emit(clip_event, position)
		accept_event()
