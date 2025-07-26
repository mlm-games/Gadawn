class_name PianoRollUI
extends BaseTrackUI

var _key_height: float = 20.0
var _preview_instrument: SynthesizerInstrument

enum DragMode {
	MOVE,
	RESIZE_LEFT,
	RESIZE_RIGHT
}

var _drag_mode: DragMode = DragMode.MOVE
var _resize_threshold: float = 8.0 # pixels from edge

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
	var time_comp := event.get_time_component()
	var pitch_comp := event.get_component("pitch")
	
	var x = time_comp.start_time_sec * project.view_zoom
	var w = max(_min_event_width, time_comp.duration_sec * project.view_zoom)
	var y = (127 - pitch_comp.key) * _key_height
	return Rect2(x, y, w, _key_height)

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
	var time_comp = new_note.get_time_component()
	var pitch_comp :NotePitchComponent= new_note.get_component("pitch") 
	var vel_comp :NoteVelocityComponent= new_note.get_component("velocity")

	pitch_comp.key = _pos_to_key(position.y)
	time_comp.start_time_sec = _pos_to_time(position.x)
	
	# Snap to grid
	var beat_duration = 60.0 / project.bpm
	time_comp.start_time_sec = snapped(time_comp.start_time_sec, beat_duration / 4.0)
	time_comp.duration_sec = beat_duration / 4.0
	vel_comp.velocity = 100
	
	_preview_event(new_note)
	
	create_new_event(new_note)
	
	_selected_events.clear()
	_selected_events.append(new_note)
	_update_selection_display()


func _get_event_id(event: TrackEvent) -> String:
	if event is NoteEvent:
		var note : NoteEvent = event
		return "%f_%d_%f_%d" % [note.start_time_sec, note.get_component("pitch").key, note.duration_sec, note.get_component("velocity").velocity]
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
		var note : NoteEvent = event
		var note_color = Color.from_hsv(float(note.get_component("pitch").key % 12) / 12.0, 0.6, 0.9)
		
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
		var velocity_height = rect.size.y * (note.get_component("velocity").velocity / 127.0)
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
		
	var note : NoteEvent = event
	# Create a temporary note for preview
	var preview_note := note._duplicate()
	preview_note.get_time_component().duration_sec = 0.2 # Short preview
	
	_preview_instrument.play_event(preview_note)
	
	# Stop preview after duration
	get_tree().create_timer(preview_note.get_time_component().duration_sec).timeout.connect(func():
		_preview_instrument.stop_event(preview_note))

func _range_select_to_event(target_event: TrackEvent) -> void:
	if not target_event is NoteEvent or _selected_events.is_empty():
		return
		
	var target_note : NoteEvent = target_event
	var first_selected := _selected_events[0]
	
	var start_time = min(first_selected.start_time_sec, target_note.start_time_sec)
	var end_time = max(first_selected.start_time_sec, target_note.start_time_sec)
	var start_key = min(first_selected.key, target_note.get_component("pitch").key)
	var end_key = max(first_selected.key, target_note.get_component("pitch").key)
	
	for event in track_data.events:
		if event is NoteEvent:
			var note : NoteEvent = event
			if note.start_time_sec >= start_time and note.start_time_sec <= end_time:
				if note.get_component("pitch").key >= start_key and note.get_component("pitch").key <= end_key:
					if event not in _selected_events:
						_selected_events.append(event)
	queue_redraw()
	_update_selection_display()

func _update_dragged_event_position(position: Vector2) -> void:
	if not _is_dragging or not _dragged_event is NoteEvent:
		return
	
	var note : NoteEvent = _dragged_event
	
	match _drag_mode:
		DragMode.MOVE:
			super._update_dragged_event_position(position)
		
		DragMode.RESIZE_RIGHT:
			var new_end_time = _pos_to_time(position.x)
			var beat_duration = 60.0 / project.bpm
			new_end_time = snapped(new_end_time, beat_duration / 16.0) # Snap to 16th notes
			
			# Update duration for all selected notes
			var duration_delta = new_end_time - (note.start_time_sec + note.duration_sec)
			for event in _selected_events:
				if event is NoteEvent:
					var n : NoteEvent = event
					n.duration_sec = max(beat_duration / 16.0, n.duration_sec + duration_delta)
		
		DragMode.RESIZE_LEFT:
			var new_start_time = _pos_to_time(position.x)
			var beat_duration = 60.0 / project.bpm
			new_start_time = snapped(new_start_time, beat_duration / 16.0)
			
			# Adjust start time and duration
			var time_delta = new_start_time - note.start_time_sec
			for event in _selected_events:
				if event is NoteEvent:
					var n : NoteEvent = event
					var old_end = n.start_time_sec + n.duration_sec
					n.start_time_sec = max(0.0, n.start_time_sec + time_delta)
					n.duration_sec = max(beat_duration / 16.0, old_end - n.start_time_sec)
	
	queue_redraw()

func _start_dragging_events(clicked_event: TrackEvent, position: Vector2) -> void:
	super._start_dragging_events(clicked_event, position)
	
	# Store key positions for notes
	for event in _selected_events:
		if event is NoteEvent:
			var note : NoteEvent = event
			_drag_original_positions[event]["key"] = note.get_component("pitch").key

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


func _get_drag_mode_at_position(note: NoteEvent, position: Vector2) -> DragMode:
	var rect = _get_event_rect(note)
	
	# right edge
	if position.x > rect.position.x + rect.size.x - _resize_threshold:
		return DragMode.RESIZE_RIGHT
	elif position.x < rect.position.x + _resize_threshold:
		return DragMode.RESIZE_LEFT
	else:
		return DragMode.MOVE
