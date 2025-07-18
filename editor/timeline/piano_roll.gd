# This is a custom control that draws a piano roll for an Instrument Track.
# It handles all the drawing and input for creating/editing notes.
class_name PianoRollUI
extends Control

signal event_moved(event: TrackEvent, new_time: float, new_track_index: int)
signal event_created(event: TrackEvent, track_index: int)

var track_data: TrackData
var project: Project
var track_index: int

var _key_height: float = 10.0
var _is_dragging_note = false
var _dragged_note_event: NoteEvent
var _drag_offset: Vector2

# --- Public API ---

func set_track_data(p_project: Project, p_track_index: int):
	project = p_project
	track_index = p_track_index
	track_data = project.tracks[track_index]
	queue_redraw()

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
	for i in range(int(get_rect().size.x / beat_width_px)):
		draw_line(Vector2(i * beat_width_px, 0), Vector2(i * beat_width_px, get_rect().size.y), Color(0.2, 0.2, 0.23))

	# Draw note events
	for event in track_data.events:
		if event is NoteEvent:
			var note_rect = _get_note_rect(event)
			var note_color = Color.from_hsv(float(event.key % 12) / 12.0, 0.6, 0.9)
			if _dragged_note_event == event:
				note_color.a = 0.6
			draw_rect(note_rect, note_color)
			draw_rect(note_rect, note_color.lightened(0.3), false, 1.0)

# --- Input Handling for Note Manipulation ---

func _gui_input(event: InputEvent):
	if not project: return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Check if clicking on an existing note
			for note_event in track_data.events:
				if _get_note_rect(note_event).has_point(event.position):
					_is_dragging_note = true
					_dragged_note_event = note_event
					_drag_offset = event.position - _get_note_rect(note_event).position
					get_viewport().set_input_as_handled()
					queue_redraw()
					return
			
			# If not, create a new note
			var new_note = NoteEvent.new()
			new_note.key = _pos_to_key(event.position.y)
			new_note.start_time_sec = _pos_to_time(event.position.x)
			new_note.duration_sec = 60.0 / project.bpm # Default to one beat
			event_created.emit(new_note, track_index)
			get_viewport().set_input_as_handled()

		else: # Mouse button released
			if _is_dragging_note:
				_is_dragging_note = false
				_dragged_note_event = null
				queue_redraw()
				get_viewport().set_input_as_handled()
	
	if event is InputEventMouseMotion and _is_dragging_note:
		var new_time = _pos_to_time(event.position.x - _drag_offset.x)
		var new_key = _pos_to_key(event.position.y - _drag_offset.y)
		
		# "Snap" to grid
		var beat_duration = 60.0 / project.bpm
		new_time = snapped(new_time, beat_duration / 4.0) # Snap to 16th notes
		
		# Update the data directly for visual feedback
		_dragged_note_event.start_time_sec = new_time
		_dragged_note_event.key = new_key
		
		# Since we are modifying the data directly, we must emit the final
		# move signal to ensure it's saved correctly. A better system would
		# use a temporary visual-only move and only commit on mouse release.
		event_moved.emit(_dragged_note_event, new_time, track_index)
		
		get_viewport().set_input_as_handled()
		queue_redraw()

# --- Helper Functions ---

func _get_note_rect(note: NoteEvent) -> Rect2:
	var x = note.start_time_sec * project.view_zoom
	var w = note.duration_sec * project.view_zoom
	var y = (127 - note.key) * _key_height
	return Rect2(x, y, w, _key_height)

func _pos_to_key(y_pos: float) -> int:
	return 127 - int(y_pos / _key_height)

func _pos_to_time(x_pos: float) -> float:
	return x_pos / project.view_zoom
	
# ... (Other UI scenes like audio_track_lane_ui, track_header_ui, panels, dialogs)
# ... (All instruments including the new SynthesizerInstrument)
# ... The rest of the files are omitted for brevity but would follow this refactored structure.
# This response provides the most critical architectural and functional pieces of the refactor.
