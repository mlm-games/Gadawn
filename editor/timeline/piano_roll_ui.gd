# This is a custom control that draws a piano roll for an Instrument Track.
# It handles all the drawing and input for creating/editing notes.
class_name PianoRollUI
extends Control

signal event_moved(event: TrackEvent, new_time: float, new_track_index: int)
signal event_created(event: TrackEvent, track_index: int)

var track_data: TrackData
var project: Project
var track_index: int

var _key_height: float = 20.0  # Increased for touch-friendliness
var _min_note_width: float = 10.0  # Minimum width for notes

# Selection
var _selected_notes: Array[NoteEvent] = []
var _selection_rect: Rect2
var _is_selecting: bool = false
var _selection_start: Vector2

# Dragging
var _is_dragging_note: bool = false
var _dragged_note_event: NoteEvent
var _drag_offset: Vector2
var _drag_original_positions: Dictionary = {}

# Touch handling
var _touch_timer: float = -1.0
var _touch_position: Vector2
var _long_press_threshold: float = 0.5
var _touch_moved: bool = false

# Note creation
var _pending_note_position: Vector2 = Vector2.ZERO

# Preview
var _preview_instrument: SynthesizerInstrument

# --- Public API ---

func set_track_data(p_project: Project, p_track_index: int):
	project = p_project
	track_index = p_track_index
	track_data = project.tracks[track_index]
	queue_redraw()

# --- Lifecycle ---

func _ready():
	# Create preview instrument
	var synth_script = preload("res://instruments/synthesizer/instrument.gd")
	_preview_instrument = synth_script.new()
	_preview_instrument.waveform = SynthesizerInstrument.Waveform.SINE
	_preview_instrument.attack_sec = 0.01
	_preview_instrument.decay_sec = 0.1
	_preview_instrument.sustain_level = 0.5
	_preview_instrument.release_sec = 0.1
	add_child(_preview_instrument)
	
	set_process_unhandled_key_input(true)


func _process(delta: float):
	if _touch_timer >= 0.0:
		_touch_timer += delta
		if _touch_timer >= _long_press_threshold and not _touch_moved:
			# Trigger selection mode on long press
			_start_selection_at(_touch_position)
			_touch_timer = -1.0

# --- Drawing Logic ---

func _draw():
	if not project: return
	
	# Draw background grid (horizontal lines for keys)
	var black_keys = [1, 3, 6, 8, 10]
	for i in range(128):
		var key_y = (127 - i) * _key_height
		var line_color = Color(0.2, 0.2, 0.23)
		if i % 12 in black_keys:
			draw_rect(Rect2(0, key_y, get_rect().size.x, _key_height), Color(0.12, 0.12, 0.15))
		
		if i % 12 == 0: # C notes
			line_color = Color(0.3, 0.3, 0.33)
			
		draw_line(Vector2(0, key_y), Vector2(get_rect().size.x, key_y), line_color)

	# Draw vertical grid lines (beats)
	var beat_width_px = (60.0 / project.bpm) * project.view_zoom
	for i in range(int(get_rect().size.x / beat_width_px) + 1):
		var x = i * beat_width_px
		var line_color = Color(0.2, 0.2, 0.23)
		if i % 4 == 0:  # Measure lines
			line_color = Color(0.3, 0.3, 0.33)
		draw_line(Vector2(x, 0), Vector2(x, get_rect().size.y), line_color)

	# Draw note events
	for event in track_data.events:
		if event is NoteEvent:
			var note_rect = _get_note_rect(event)
			var note_color = Color.from_hsv(float(event.key % 12) / 12.0, 0.6, 0.9)
			
			# Modify appearance based on state
			if event in _selected_notes:
				note_color = note_color.lightened(0.3)
				draw_rect(note_rect, note_color)
				draw_rect(note_rect, Color.WHITE, false, 2.0)
			elif _is_dragging_note and event in _selected_notes:
				note_color.a = 0.7
				draw_rect(note_rect, note_color)
				draw_rect(note_rect, note_color.lightened(0.3), false, 1.0)
			else:
				draw_rect(note_rect, note_color)
				draw_rect(note_rect, note_color.lightened(0.3), false, 1.0)
			
			# Draw velocity indicator
			var velocity_height = note_rect.size.y * (event.velocity / 127.0)
			var velocity_rect = Rect2(
				note_rect.position.x, 
				note_rect.position.y + note_rect.size.y - velocity_height,
				4, 
				velocity_height
			)
			draw_rect(velocity_rect, note_color.darkened(0.3))
	
	# Draw selection rectangle
	if _is_selecting and _selection_rect.size != Vector2.ZERO:
		draw_rect(_selection_rect, Color(0.5, 0.5, 1.0, 0.3))
		draw_rect(_selection_rect, Color(0.5, 0.5, 1.0, 0.8), false, 2.0)

# --- Input Handling ---

func _gui_input(event: InputEvent):
	if not project: return
	
	# Handle touch events
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_timer = 0.0
			_touch_position = event.position
			_touch_moved = false
		else:
			if _touch_timer >= 0.0 and _touch_timer < _long_press_threshold and not _touch_moved:
				# Short tap - create note or select
				var clicked_note = _get_note_at_position(event.position)
				if clicked_note:
					_toggle_note_selection(clicked_note)
				else:
					_create_note_at(event.position)
			_touch_timer = -1.0
			_touch_moved = false
			
			# End any ongoing operations
			if _is_dragging_note:
				_finish_dragging_notes()
			if _is_selecting:
				_end_selection()
		get_viewport().set_input_as_handled()
		return
	
	if event is InputEventScreenDrag:
		_touch_moved = true
		if _is_dragging_note and _dragged_note_event:
			_update_dragged_note_position(event.position)
		elif _is_selecting:
			_update_selection_rect(event.position)
		get_viewport().set_input_as_handled()
		return
	
	# Mouse handling with clear separation of actions
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
		if _is_dragging_note:
			_update_dragged_note_position(event.position)
		elif _is_selecting:
			_update_selection_rect(event.position)
		get_viewport().set_input_as_handled()
	

func _unhandled_input(event: InputEvent):
	if not project or not is_visible_in_tree():
		return
	
	var handled = false
	
	if event.is_action_pressed("delete_notes") and not _selected_notes.is_empty():
		_delete_selected_notes()
		handled = true
	elif event.is_action_pressed("duplicate_notes") and not _selected_notes.is_empty():
		_duplicate_selected_notes()
		handled = true
	elif event.is_action_pressed("select_all_notes"):
		_select_all_notes()
		handled = true
	elif event.is_action_pressed("deselect_notes") and not _selected_notes.is_empty():
		_clear_selection()
		handled = true
	
	if handled:
		get_viewport().set_input_as_handled()

# --- Mouse/Touch Action Handlers ---

func _handle_left_click_pressed(position: Vector2, shift_pressed: bool, ctrl_pressed: bool):
	var clicked_note = _get_note_at_position(position)
	
	if clicked_note:
		if ctrl_pressed:
			# Toggle selection
			_toggle_note_selection(clicked_note)
		elif shift_pressed and not _selected_notes.is_empty():
			# Range select
			_range_select_to_note(clicked_note)
		elif clicked_note in _selected_notes:
			# Start dragging selected notes
			_start_dragging_notes(clicked_note, position)
		else:
			# Select only this note and start dragging
			_selected_notes.clear()
			_selected_notes.append(clicked_note)
			_start_dragging_notes(clicked_note, position)
	else:
		# Click on empty space
		if not shift_pressed and not ctrl_pressed:
			_selected_notes.clear()
		_pending_note_position = position
	
	queue_redraw()

func _handle_left_click_released():
	if _is_dragging_note:
		_finish_dragging_notes()
	elif _pending_note_position != Vector2.ZERO:
		_create_note_at(_pending_note_position)
		_pending_note_position = Vector2.ZERO

# --- Selection Functions ---

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
		_select_notes_in_rect(_selection_rect)
		_selection_rect = Rect2()
		queue_redraw()

func _select_notes_in_rect(rect: Rect2):
	if rect.size.length() < 5:  # Ignore tiny selections
		return
		
	_selected_notes.clear()
	for event in track_data.events:
		if event is NoteEvent:
			var note_rect = _get_note_rect(event)
			if rect.intersects(note_rect):
				_selected_notes.append(event)
	queue_redraw()

func _toggle_note_selection(note: NoteEvent):
	if note in _selected_notes:
		_selected_notes.erase(note)
	else:
		_selected_notes.append(note)
	queue_redraw()

func _range_select_to_note(target_note: NoteEvent):
	if _selected_notes.is_empty():
		return
		
	var first_selected = _selected_notes[0]
	var start_time = min(first_selected.start_time_sec, target_note.start_time_sec)
	var end_time = max(first_selected.start_time_sec, target_note.start_time_sec)
	var start_key = min(first_selected.key, target_note.key)
	var end_key = max(first_selected.key, target_note.key)
	
	for event in track_data.events:
		if event is NoteEvent:
			if event.start_time_sec >= start_time and event.start_time_sec <= end_time:
				if event.key >= start_key and event.key <= end_key:
					if event not in _selected_notes:
						_selected_notes.append(event)
	queue_redraw()

func _select_all_notes():
	_selected_notes.clear()
	for event in track_data.events:
		if event is NoteEvent:
			_selected_notes.append(event)
	queue_redraw()

func _clear_selection():
	_selected_notes.clear()
	queue_redraw()

# --- Note Manipulation Functions ---

func _get_note_at_position(position: Vector2) -> NoteEvent:
	# Check in reverse order to get topmost note
	for i in range(track_data.events.size() - 1, -1, -1):
		var event = track_data.events[i]
		if event is NoteEvent:
			if _get_note_rect(event).has_point(position):
				return event
	return null

func _create_note_at(position: Vector2):
	var new_note = NoteEvent.new()
	new_note.key = _pos_to_key(position.y)
	new_note.start_time_sec = _pos_to_time(position.x)
	
	# Snap to grid
	var beat_duration = 60.0 / project.bpm
	new_note.start_time_sec = snapped(new_note.start_time_sec, beat_duration / 4.0)
	new_note.duration_sec = beat_duration / 4.0  # Default to 16th note
	new_note.velocity = 100
	
	# Preview the note
	_preview_note(new_note)
	
	# Add to selection
	_selected_notes.clear()
	_selected_notes.append(new_note)
	
	event_created.emit(new_note, track_index)
	queue_redraw()

func _delete_selected_notes():
	if _selected_notes.is_empty():
		return
	
	for note in _selected_notes:
		track_data.events.erase(note)
	
	_selected_notes.clear()
	queue_redraw()
	
	# Notify project of changes
	CurrentProject.project_changed.emit(CurrentProject.project)

func _duplicate_selected_notes():
	if _selected_notes.is_empty():
		return
		
	var new_notes : Array[NoteEvent] = []
	var time_offset = 60.0 / project.bpm  # Offset by one beat
	
	for note in _selected_notes:
		var new_note = note.duplicate()
		new_note.start_time_sec += time_offset
		new_notes.append(new_note)
		track_data.events.append(new_note)
	
	_selected_notes = new_notes
	CurrentProject.project_changed.emit(CurrentProject.project)
	queue_redraw()

# --- Dragging Functions ---

func _start_dragging_notes(clicked_note: NoteEvent, position: Vector2):
	_is_dragging_note = true
	_dragged_note_event = clicked_note
	_drag_offset = position - _get_note_rect(clicked_note).position
	
	# Store original positions of all selected notes
	_drag_original_positions.clear()
	for note in _selected_notes:
		_drag_original_positions[note] = {
			"time": note.start_time_sec,
			"key": note.key
		}

func _update_dragged_note_position(position: Vector2):
	if not _is_dragging_note or not _dragged_note_event:
		return
	
	var new_time = _pos_to_time(position.x - _drag_offset.x)
	var new_key = _pos_to_key(position.y - _drag_offset.y)
	
	# Snap to grid
	var beat_duration = 60.0 / project.bpm
	new_time = snapped(new_time, beat_duration / 4.0)
	new_key = clampi(new_key, 0, 127)
	
	# Calculate delta from the dragged note
	var time_delta = new_time - _drag_original_positions[_dragged_note_event]["time"]
	var key_delta = new_key - _drag_original_positions[_dragged_note_event]["key"]
	
	# Apply delta to all selected notes
	for note in _selected_notes:
		if _drag_original_positions.has(note):
			var original = _drag_original_positions[note]
			note.start_time_sec = max(0.0, original["time"] + time_delta)
			note.key = clampi(original["key"] + key_delta, 0, 127)
	
	queue_redraw()

func _finish_dragging_notes():
	if not _is_dragging_note:
		return
		
	_is_dragging_note = false
	_dragged_note_event = null
	_drag_original_positions.clear()
	
	# Notify project of changes
	CurrentProject.project_changed.emit(CurrentProject.project)

# --- Note Preview ---

func _preview_note(note: NoteEvent):
	if not _preview_instrument:
		return
		
	# Create a temporary note for preview
	var preview_note = note.duplicate()
	preview_note.duration_sec = 0.2  # Short preview
	
	_preview_instrument.play_event(preview_note)
	
	# Stop preview after duration
	get_tree().create_timer(preview_note.duration_sec).timeout.connect(func(): 
		_preview_instrument.stop_event(preview_note))

# --- Helper Functions ---

func _get_note_rect(note: NoteEvent) -> Rect2:
	var x = note.start_time_sec * project.view_zoom
	var w = max(_min_note_width, note.duration_sec * project.view_zoom)
	var y = (127 - note.key) * _key_height
	return Rect2(x, y, w, _key_height)

func _pos_to_key(y_pos: float) -> int:
	return clampi(127 - int(y_pos / _key_height), 0, 127)

func _pos_to_time(x_pos: float) -> float:
	return max(0.0, x_pos / project.view_zoom)

# --- Can Drop Data (for drag and drop from instruments) ---

func _can_drop_data(position: Vector2, data) -> bool:
	if data is Dictionary and data.has("type") and data["type"] == "instrument":
		return true
	return false

func _drop_data(position: Vector2, data):
	if data is Dictionary and data.has("type") and data["type"] == "instrument":
		# Create a note at the drop position
		_create_note_at(position)
