@abstract class_name BaseTrackUI
extends Control

signal event_moved(event: TrackEvent, new_time: float, new_track_index: int)
signal event_created(event: TrackEvent, track_index: int)

var track_data: TrackData
var project: Project
var track_index: int

var _min_event_width: float = 10.0 # Minimum width for events

# Selection
var _selected_events: Array[TrackEvent] = []
var _selection_rect: Rect2
var _is_selecting: bool = false
var _selection_start: Vector2

# Dragging
var _is_dragging: bool = false
var _dragged_event: TrackEvent
var _drag_offset: Vector2
var _drag_original_positions: Dictionary = {}

# Touch handling
var _touch_timer: float = -1.0
var _touch_position: Vector2
var _long_press_threshold: float = 0.5
var _touch_moved: bool = false

# Event creation
var _pending_event_position: Vector2 = Vector2.ZERO

# Preview
var _pending_selection_ids: Array[String] = []

@onready var _selection_toolbar: Control = $SelectionToolbar


@abstract func _get_event_rect(event: TrackEvent) -> Rect2

@abstract func _get_event_at_position(position: Vector2) -> TrackEvent

@abstract func _create_event_at(position: Vector2) -> void

@abstract func _get_event_id(event: TrackEvent) -> String

@abstract func _draw_background() -> void

@abstract func _draw_event(event: TrackEvent, rect: Rect2, is_selected: bool, is_dragging: bool) -> void

func _preview_event(event: TrackEvent) -> void:
	# Override if preview is needed
	pass

# --- Public API ---

func set_track_data(p_project: Project, p_track_index: int):
	project = p_project
	track_index = p_track_index
	track_data = project.tracks[track_index]

func refresh_events():
	# Restore pending selections if any
	if not _pending_selection_ids.is_empty():
		_selected_events.clear()
		for event in track_data.events:
			var event_id = _get_event_id(event)
			if event_id in _pending_selection_ids:
				_selected_events.append(event)
		_pending_selection_ids.clear()
	
	queue_redraw()

# --- Lifecycle ---

func _ready():
	set_process_unhandled_key_input(true)
	
	if _selection_toolbar:
		_selection_toolbar.delete_pressed.connect(_delete_selected_events)
		_selection_toolbar.duplicate_pressed.connect(_duplicate_selected_events)
		_selection_toolbar.select_all_pressed.connect(_select_all_events)
		_selection_toolbar.deselect_pressed.connect(_clear_selection)

func _process(delta: float):
	if _touch_timer >= 0.0:
		_touch_timer += delta
		if _touch_timer >= _long_press_threshold and not _touch_moved:
			_start_selection_at(_touch_position)
			_touch_timer = -1.0

# --- Drawing ---

func _draw():
	if not project: return
	
	_draw_background()
	
	# Draw events
	for event in track_data.events:
		var rect = _get_event_rect(event)
		var is_selected = event in _selected_events
		var is_dragging = _is_dragging and event in _selected_events
		_draw_event(event, rect, is_selected, is_dragging)
	
	# Draw selection rectangle
	if _is_selecting and _selection_rect.size != Vector2.ZERO:
		draw_rect(_selection_rect, Color(0.5, 0.5, 1.0, 0.3))
		draw_rect(_selection_rect, Color(0.5, 0.5, 1.0, 0.8), false, 2.0)

# --- Input Handling ---

func _gui_input(event: InputEvent):
	if not project: return
	
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_timer = 0.0
			_touch_position = event.position
			_touch_moved = false
		else:
			if _touch_timer >= 0.0 and _touch_timer < _long_press_threshold and not _touch_moved:
				var clicked_event = _get_event_at_position(event.position)
				if clicked_event:
					_toggle_event_selection(clicked_event)
				else:
					_create_event_at(event.position)
			_touch_timer = -1.0
			_touch_moved = false
			
			if _is_dragging:
				_finish_dragging_events()
			if _is_selecting:
				_end_selection()
		get_viewport().set_input_as_handled()
		return
	
	if event is InputEventScreenDrag:
		_touch_moved = true
		if _is_dragging and _dragged_event:
			_update_dragged_event_position(event.position)
		elif _is_selecting:
			_update_selection_rect(event.position)
		get_viewport().set_input_as_handled()
		return
	
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_handle_left_click_pressed(event.position, event.shift_pressed, event.ctrl_pressed)
				else:
					_handle_left_click_released()
			MOUSE_BUTTON_RIGHT:
				if event.pressed:
					_start_selection_at(event.position)
				else:
					_end_selection()
		get_viewport().set_input_as_handled()
	
	elif event is InputEventMouseMotion:
		if _is_dragging:
			_update_dragged_event_position(event.position)
		elif _is_selecting:
			_update_selection_rect(event.position)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent):
	if not project or not is_visible_in_tree():
		return
	
	var handled = false
	
	if event.is_action_pressed("delete_events") and not _selected_events.is_empty():
		_delete_selected_events()
		handled = true
	elif event.is_action_pressed("duplicate_events") and not _selected_events.is_empty():
		_duplicate_selected_events()
		handled = true
	elif event.is_action_pressed("select_all_events"):
		_select_all_events()
		handled = true
	elif event.is_action_pressed("deselect_events") and not _selected_events.is_empty():
		_clear_selection()
		handled = true
	
	if handled:
		get_viewport().set_input_as_handled()

# --- Mouse/Touch Action Handlers ---

func _handle_left_click_pressed(position: Vector2, shift_pressed: bool, ctrl_pressed: bool):
	var clicked_event = _get_event_at_position(position)
	
	if clicked_event:
		if ctrl_pressed:
			_toggle_event_selection(clicked_event)
		elif shift_pressed and not _selected_events.is_empty():
			_range_select_to_event(clicked_event)
		elif clicked_event in _selected_events:
			_start_dragging_events(clicked_event, position)
		else:
			_selected_events.clear()
			_selected_events.append(clicked_event)
			_start_dragging_events(clicked_event, position)
	else:
		if not shift_pressed and not ctrl_pressed:
			_selected_events.clear()
		_pending_event_position = position
	
	queue_redraw()
	_update_selection_display()

func _handle_left_click_released():
	if _is_dragging:
		_finish_dragging_events()
	elif _pending_event_position != Vector2.ZERO:
		_create_event_at(_pending_event_position)
		_pending_event_position = Vector2.ZERO

# --- Selection Functions ---

func _update_selection_display():
	if _selection_toolbar:
		_selection_toolbar.set_selection_count(_selected_events.size())
		if _selected_events.size() > 0:
			_selection_toolbar.show_toolbar()
			_position_toolbar_near_selection()
		else:
			_selection_toolbar.hide_toolbar()

func _position_toolbar_near_selection():
	if _selected_events.is_empty():
		return
	
	var avg_pos = Vector2.ZERO
	var min_y = INF
	
	for event in _selected_events:
		var rect = _get_event_rect(event)
		avg_pos += rect.get_center()
		min_y = min(min_y, rect.position.y)
	
	avg_pos /= _selected_events.size()
	
	var toolbar_pos = Vector2(
		clamp(avg_pos.x - 100, 10, size.x - 210),
		max(10, min_y - 60)
	)
	
	_selection_toolbar.position = toolbar_pos

func _start_selection_at(position: Vector2):
	_is_selecting = true
	_selection_start = position
	_selection_rect = Rect2(position, Vector2.ZERO)
	queue_redraw()

func _update_selection_rect(position: Vector2):
	_selection_rect = Rect2(
		Vector2(min(_selection_start.x, position.x), min(_selection_start.y, position.y)),
		Vector2(abs(position.x - _selection_start.x), abs(position.y - _selection_start.y))
	)
	queue_redraw()

func _end_selection():
	if _is_selecting:
		_is_selecting = false
		_select_events_in_rect(_selection_rect)
		_selection_rect = Rect2()
		queue_redraw()

func _select_events_in_rect(rect: Rect2):
	if rect.size.length() < 5:
		return
		
	_selected_events.clear()
	for event in track_data.events:
		var event_rect = _get_event_rect(event)
		if rect.intersects(event_rect):
			_selected_events.append(event)
	queue_redraw()
	_update_selection_display()

func _toggle_event_selection(event: TrackEvent):
	if event in _selected_events:
		_selected_events.erase(event)
	else:
		_selected_events.append(event)
	queue_redraw()
	_update_selection_display()

func _range_select_to_event(target_event: TrackEvent):
	# Subclasses should override this for specific range selection logic
	pass

func _select_all_events():
	_selected_events.clear()
	for event in track_data.events:
		_selected_events.append(event)
	queue_redraw()
	_update_selection_display()

func _clear_selection():
	_selected_events.clear()
	queue_redraw()
	_update_selection_display()

# --- Event Manipulation Functions ---

func _delete_selected_events():
	if _selected_events.is_empty():
		return
	
	for event in _selected_events:
		track_data.events.erase(event)
	
	_selected_events.clear()
	queue_redraw()
	
	CurrentProject.project_changed.emit(CurrentProject.project)

func _duplicate_selected_events():
	if _selected_events.is_empty():
		return
		
	var time_offset = 60.0 / project.bpm
	_pending_selection_ids.clear()
	
	for event in _selected_events:
		var new_event = event.duplicate()
		new_event.start_time_sec += time_offset
		track_data.events.append(new_event)
		_pending_selection_ids.append(_get_event_id(new_event))
	
	CurrentProject.project_changed.emit(CurrentProject.project)

# --- Dragging Functions ---

func _start_dragging_events(clicked_event: TrackEvent, position: Vector2):
	_is_dragging = true
	_dragged_event = clicked_event
	_drag_offset = position - _get_event_rect(clicked_event).position
	
	_drag_original_positions.clear()
	for event in _selected_events:
		_drag_original_positions[event] = {
			"time": event.start_time_sec
		}

func _update_dragged_event_position(position: Vector2):
	# Subclasses should override for specific dragging logic
	pass

func _finish_dragging_events():
	if not _is_dragging:
		return
		
	_is_dragging = false
	_dragged_event = null
	_drag_original_positions.clear()
	
	CurrentProject.project_changed.emit(CurrentProject.project)

# --- Helper Functions ---

func _pos_to_time(x_pos: float) -> float:
	return max(0.0, x_pos / project.view_zoom)

func _can_drop_data(position: Vector2, data) -> bool:
	if data is Dictionary and data.has("type") and data["type"] == "instrument":
		return true
	return false

func _drop_data(position: Vector2, data):
	if data is Dictionary and data.has("type") and data["type"] == "instrument":
		_create_event_at(position)

func get_selected_events() -> Array[TrackEvent]:
	return _selected_events.duplicate()

func set_selected_events(events: Array):
	_selected_events.clear()
	for event in events:
		if event in track_data.events:
			_selected_events.append(event)
	queue_redraw()
