class_name PianoRollUI
extends BaseTrackUI

var _key_height: float = 20.0
var _preview_instrument: SynthesizerInstrument

# --- Lifecycle ---

func _ready():
	super._ready()
	
	# Create preview instrument
	_preview_instrument = SynthesizerInstrument.new()
	_preview_instrument.waveform = SynthesizerInstrument.Waveform.SINE
	_preview_instrument.attack_sec = 0.01
	_preview_instrument.decay_sec = 0.1
	_preview_instrument.sustain_level = 0.5
	_preview_instrument.release_sec = 0.1
	add_child(_preview_instrument)

# --- Override virtual methods ---

func _get_event_rect(event: TrackEvent) -> Rect2:
	if event is NoteEvent:
		var note = event as NoteEvent
		var x = note.start_time_sec * project.view_zoom
		var w = max(_min_event_width, note.duration_sec * project.view_zoom)
		var y = (127 - note.key) * _key_height
		return Rect2(x, y, w, _key_height)
	return Rect2()

func _get_event_at_position(position: Vector2) -> TrackEvent:
	# Check in reverse order to get topmost note
	for i in range(track_data.events.size() - 1, -1, -1):
		var event = track_data.events[i]
		if event is NoteEvent:
			if _get_event_rect(event).has_point(position):
				return event
	return null

func _create_event_at(position: Vector2) -> void:
	var new_note = NoteEvent.new()
	new_note.key = _pos_to_key(position.y)
	new_note.start_time_sec = _pos_to_time(position.x)
	
	# Snap to grid
	var beat_duration = 60.0 / project.bpm
	new_note.start_time_sec = snapped(new_note.start_time_sec, beat_duration / 4.0)
	new_note.duration_sec = beat_duration / 4.0 # Default to 16th note
	new_note.velocity = 100
	
	# Preview the note
	_preview_event(new_note)
	
	# Add to selection
	_selected_events.clear()
	_selected_events.append(new_note)
	
	event_created.emit(new_note, track_index)
	queue_redraw()

func _get_event_id(event: TrackEvent) -> String:
	if event is NoteEvent:
		var note = event as NoteEvent
		return "%f_%d_%f_%d" % [note.start_time_sec, note.key, note.duration_sec, note.velocity]
	return ""

func _draw_background() -> void:
	# Draw piano roll grid
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
		if i % 4 == 0: # Measure lines
			line_color = Color(0.3, 0.3, 0.33)
		draw_line(Vector2(x, 0), Vector2(x, get_rect().size.y), line_color)

func _draw_event(event: TrackEvent, rect: Rect2, is_selected: bool, is_dragging: bool) -> void:
	if event is NoteEvent:
		var note = event as NoteEvent
		var note_color = Color.from_hsv(float(note.key % 12) / 12.0, 0.6, 0.9)
		
		# Modify appearance based on state
		if is_selected:
			note_color = note_color.lightened(0.3)
			draw_rect(rect, note_color)
			draw_rect(rect, Color.WHITE, false, 2.0)
		elif is_dragging:
			note_color.a = 0.7
			draw_rect(rect, note_color)
			draw_rect(rect, note_color.lightened(0.3), false, 1.0)
		else:
			draw_rect(rect, note_color)
			draw_rect(rect, note_color.lightened(0.3), false, 1.0)
		
		# Draw velocity indicator
		var velocity_height = rect.size.y * (note.velocity / 127.0)
		var velocity_rect = Rect2(
			rect.position.x,
			rect.position.y + rect.size.y - velocity_height,
			4,
			velocity_height
		)
		draw_rect(velocity_rect, note_color.darkened(0.3))

func _preview_event(event: TrackEvent) -> void:
	if not _preview_instrument or not event is NoteEvent:
		return
		
	var note = event as NoteEvent
	# Create a temporary note for preview
	var preview_note = note.duplicate()
	preview_note.duration_sec = 0.2 # Short preview
	
	_preview_instrument.play_event(preview_note)
	
	# Stop preview after duration
	get_tree().create_timer(preview_note.duration_sec).timeout.connect(func():
		_preview_instrument.stop_event(preview_note))

func _range_select_to_event(target_event: TrackEvent) -> void:
	if not target_event is NoteEvent or _selected_events.is_empty():
		return
		
	var target_note = target_event as NoteEvent
	var first_selected = _selected_events[0] as NoteEvent
	
	var start_time = min(first_selected.start_time_sec, target_note.start_time_sec)
	var end_time = max(first_selected.start_time_sec, target_note.start_time_sec)
	var start_key = min(first_selected.key, target_note.key)
	var end_key = max(first_selected.key, target_note.key)
	
	for event in track_data.events:
		if event is NoteEvent:
			var note = event as NoteEvent
			if note.start_time_sec >= start_time and note.start_time_sec <= end_time:
				if note.key >= start_key and note.key <= end_key:
					if event not in _selected_events:
						_selected_events.append(event)
	queue_redraw()
	_update_selection_display()

func _update_dragged_event_position(position: Vector2) -> void:
	if not _is_dragging or not _dragged_event is NoteEvent:
		return
	
	var new_time = _pos_to_time(position.x - _drag_offset.x)
	var new_key = _pos_to_key(position.y - _drag_offset.y)
	
	# Snap to grid
	var beat_duration = 60.0 / project.bpm
	new_time = snapped(new_time, beat_duration / 4.0)
	new_key = clampi(new_key, 0, 127)
	
	# Calculate delta from the dragged note
	var time_delta = new_time - _drag_original_positions[_dragged_event]["time"]
	var key_delta = new_key - (_drag_original_positions[_dragged_event]["key"] if _drag_original_positions[_dragged_event].has("key") else (_dragged_event as NoteEvent).key)
	
	# Apply delta to all selected notes
	for event in _selected_events:
		if event is NoteEvent and _drag_original_positions.has(event):
			var note = event as NoteEvent
			var original = _drag_original_positions[event]
			note.start_time_sec = max(0.0, original["time"] + time_delta)
			if not original.has("key"):
				_drag_original_positions[event]["key"] = note.key
			note.key = clampi(_drag_original_positions[event]["key"] + key_delta, 0, 127)
	
	queue_redraw()

func _start_dragging_events(clicked_event: TrackEvent, position: Vector2) -> void:
	super._start_dragging_events(clicked_event, position)
	
	# Store key positions for notes
	for event in _selected_events:
		if event is NoteEvent:
			var note = event as NoteEvent
			_drag_original_positions[event]["key"] = note.key

# --- Helper Functions ---

func _pos_to_key(y_pos: float) -> int:
	return clampi(127 - int(y_pos / _key_height), 0, 127)

# --- Compatibility methods for existing code ---

func get_selected_notes() -> Array[NoteEvent]:
	var notes: Array[NoteEvent] = []
	for event in _selected_events:
		if event is NoteEvent:
			notes.append(event)
	return notes

func set_selected_notes(notes: Array):
	_selected_events.clear()
	for note in notes:
		if note in track_data.events:
			_selected_events.append(note)
	queue_redraw()
