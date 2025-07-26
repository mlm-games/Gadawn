class_name AudioTrackLaneUI
extends BaseTrackUI

# --- Lifecycle ---

func _ready():
	super._ready()
	
	# Connect to project changes to refresh when clips are added
	if not CurrentProject.project_changed.is_connected(_on_project_changed):
		CurrentProject.project_changed.connect(_on_project_changed)

func _on_project_changed(new_project: Project):
	if new_project == project:
		# Update our track data reference
		if track_index < project.tracks.size():
			track_data = project.tracks[track_index]
			_redraw_clips()

# --- Override virtual methods ---

func _get_event_rect(event: TrackEvent) -> Rect2:
	if event is AudioClipEvent:
		var clip = event as AudioClipEvent
		var x = clip.get_time_component().start_time_sec * project.view_zoom
		var w = max(80, clip.get_time_component().duration_sec * project.view_zoom)
		return Rect2(x, 10, w, 60)
	return Rect2()

func _get_event_at_position(position: Vector2) -> TrackEvent:
	# Check clip UIs instead of calculating rects
	for child in get_children():
		if child is AudioClipUI and child.get_rect().has_point(position):
			return child.clip_event
	return null

func _create_event_at(position: Vector2) -> void:
	# Check if there's a selected audio file to place
	var file_browser = FileBrowserUI.I
	if file_browser and file_browser.has_method("get_selected_file"):
		var selected_file = file_browser.get_selected_file()
		if not selected_file.is_empty():
			_create_audio_clip_from_file(selected_file, position)

func _get_event_id(event: TrackEvent) -> String:
	if event is AudioClipEvent:
		var clip = event as AudioClipEvent
		var stream_name = ""
		if clip.audio_stream:
			stream_name = clip.audio_stream.resource_path
		return "%f_%s_%f" % [clip.get_time_component().start_time_sec, stream_name, clip.volume_db]
	return ""

func _draw_background() -> void:
	# Draw track background
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.15, 0.15, 0.18, 0.5))
	
	# Draw grid lines
	if project:
		var beat_width_px = (60.0 / project.bpm) * project.view_zoom
		for i in range(int(size.x / beat_width_px) + 1):
			var x = i * beat_width_px
			var color = Color(0.3, 0.3, 0.3, 0.3) if i % 4 == 0 else Color(0.2, 0.2, 0.2, 0.2)
			draw_line(Vector2(x, 0), Vector2(x, size.y), color)

func _draw_event(event: TrackEvent, rect: Rect2, is_selected: bool, is_dragging: bool) -> void:
	# AudioTrackLaneUI uses AudioClipUI instances, so we don't draw events directly
	pass

# --- Override base class methods for custom behavior ---

func _draw():
	if not project: return
	
	_draw_background()
	
	# Don't draw selection rect for audio tracks
	# The AudioClipUI handles its own selection display

func refresh_events():
	super.refresh_events()
	_redraw_clips()

func _update_selection_display():
	super._update_selection_display()
	_update_clip_selections()

func _handle_left_click_pressed(position: Vector2, shift_pressed: bool, ctrl_pressed: bool):
	var clicked_event = _get_event_at_position(position)
	
	if clicked_event:
		# Let the AudioClipUI handle the input through _on_clip_gui_input
		return
	else:
		# Click on empty space
		if not shift_pressed and not ctrl_pressed:
			_selected_events.clear()
		_pending_event_position = position
	
	_update_selection_display()

#func _update_dragged_event_position(position: Vector2):
	## AudioClipUI handles its own dragging
	#pass
#
#func _finish_dragging_events():
	## AudioClipUI handles its own dragging
	#pass

# --- Audio-specific methods ---

func _redraw_clips():
	# Clear existing clips
	for child in get_children():
		if child is AudioClipUI:
			child.queue_free()
	
	# Create new clip UIs
	for event in track_data.events:
		if event is AudioClipEvent:
			_create_clip_ui(event)
	
	# Restore selections after redraw
	if not _pending_selection_ids.is_empty():
		_selected_events.clear()
		for event in track_data.events:
			if event is AudioClipEvent:
				var clip_id = _get_event_id(event)
				if clip_id in _pending_selection_ids:
					_selected_events.append(event)
		_pending_selection_ids.clear()
		_update_clip_selections()

func _create_clip_ui(event: AudioClipEvent):
	var clip_ui = C.Scenes.AudioClipUI.instantiate()
	clip_ui.clip_event = event
	clip_ui.project = project
	
	# Set position and size
	clip_ui.position.x = event.get_time_component().start_time_sec * project.view_zoom
	clip_ui.position.y = 10 # Add some padding from top
	
	# Calculate width based on duration or use minimum
	var clip_width = event.get_time_component().duration_sec * project.view_zoom
	clip_ui.custom_minimum_size.x = max(80, clip_width)
	clip_ui.size.x = max(80, clip_width)
	clip_ui.size.y = 60 # Fixed height
	
	# Set selection state
	clip_ui.set_selected(event in _selected_events)
	
	# Connect signals
	clip_ui.clip_moved.connect(_on_clip_moved)
	clip_ui.gui_input.connect(_on_clip_gui_input.bind(clip_ui))
	
	add_child(clip_ui)

func _on_clip_gui_input(event: InputEvent, clip_ui: AudioClipUI):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.ctrl_pressed:
				# Toggle selection
				_toggle_event_selection(clip_ui.clip_event)
			elif event.shift_pressed and not _selected_events.is_empty():
				# Range select
				_range_select_to_event(clip_ui.clip_event)
			elif clip_ui.clip_event not in _selected_events:
				# Select only this clip
				_selected_events.clear()
				_selected_events.append(clip_ui.clip_event)
				_update_selection_display()

func _update_clip_selections():
	for child in get_children():
		if child is AudioClipUI:
			child.set_selected(child.clip_event in _selected_events)

func _range_select_to_event(target_event: TrackEvent) -> void:
	if not target_event is AudioClipEvent or _selected_events.is_empty():
		return
		
	var target_clip = target_event as AudioClipEvent
	var first_selected = _selected_events[0] as AudioClipEvent
	
	var start_time = min(first_selected.get_time_component().start_time_sec, target_clip.get_time_component().start_time_sec)
	var end_time = max(first_selected.get_time_component().start_time_sec, target_clip.get_time_component().start_time_sec)
	
	for event in track_data.events:
		if event is AudioClipEvent:
			var clip = event as AudioClipEvent
			if clip.get_time_component().start_time_sec >= start_time and clip.get_time_component().start_time_sec <= end_time:
				if event not in _selected_events:
					_selected_events.append(event)
	
	_update_selection_display()

func _create_audio_clip_from_file(file_path: String, position: Vector2):
	var audio_stream = load(file_path)
	if not audio_stream:
		push_error("Failed to load audio file: " + file_path)
		return
		
	var new_clip_event := AudioClipEvent.new()
	new_clip_event.get_component("properties").audio_stream = audio_stream
	new_clip_event.get_time_component().start_time_sec = position.x / project.view_zoom
	
	# Snap to grid
	var beat_duration = 60.0 / project.bpm
	new_clip_event.get_time_component().start_time_sec = snapped(new_clip_event.get_time_component().start_time_sec, beat_duration / 4.0)
	
	# Set duration based on audio stream if possible
	if audio_stream.has_method("get_length"):
		new_clip_event.get_time_component().duration_sec = audio_stream.get_length()
	else:
		new_clip_event.get_time_component().duration_sec = beat_duration # Default to one beat
	
	# Add to selection
	_selected_events.clear()
	_selected_events.append(new_clip_event)
	
	event_created.emit(new_clip_event, track_index)

func _on_clip_moved(clip: AudioClipEvent, new_pos: Vector2):
	var new_time_sec = new_pos.x / project.view_zoom
	
	# Snap to grid
	var beat_duration = 60.0 / project.bpm
	new_time_sec = snapped(new_time_sec, beat_duration / 4.0)
	new_time_sec = max(0.0, new_time_sec) # Don't allow negative time
	
	# If multiple clips are selected, move them all
	if clip in _selected_events and _selected_events.size() > 1:
		var time_delta = new_time_sec - clip.get_time_component().start_time_sec
		for selected_event in _selected_events:
			if selected_event != clip and selected_event is AudioClipEvent:
				var selected_clip = selected_event as AudioClipEvent
				var new_selected_time = selected_clip.get_time_component().start_time_sec + time_delta
				new_selected_time = max(0.0, new_selected_time)
				event_moved.emit(selected_clip, new_selected_time, track_index)
	
	event_moved.emit(clip, new_time_sec, track_index)

# --- Drag and drop support ---

func _can_drop_data(_position: Vector2, data) -> bool:
	if data is Dictionary and data.has("type") and data["type"] == "audio_file":
		return true
	return super._can_drop_data(_position, data)

func _drop_data(position: Vector2, data):
	if data is Dictionary and data.has("type") and data["type"] == "audio_file":
		if data.has("path"):
			_create_audio_clip_from_file(data["path"], position)
	else:
		super._drop_data(position, data)

# --- Compatibility methods ---

func get_selected_clips() -> Array[AudioClipEvent]:
	var clips: Array[AudioClipEvent] = []
	for event in _selected_events:
		if event is AudioClipEvent:
			clips.append(event)
	return clips

func set_selected_clips(clips: Array):
	_selected_events.clear()
	for clip in clips:
		if clip in track_data.events:
			_selected_events.append(clip)
	_update_selection_display()
