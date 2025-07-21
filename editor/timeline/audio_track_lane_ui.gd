class_name AudioTrackLaneUI
extends Control

signal event_moved(event: TrackEvent, new_time: float, new_track_index: int)
signal event_created(event: TrackEvent, track_index: int)

var track_data: TrackData
var project: Project
var track_index: int

var _selected_clips: Array[AudioClipEvent] = []
var _pending_selection_ids: Array[String] = []

func _ready():
	# Enable keyboard input processing
	set_process_unhandled_key_input(true)

func set_track_data(p_project: Project, p_track_index: int):
	project = p_project
	track_index = p_track_index
	track_data = project.tracks[track_index]
	
	# Connect to project changes to refresh when clips are added
	if not CurrentProject.project_changed.is_connected(_on_project_changed):
		CurrentProject.project_changed.connect(_on_project_changed)
	
	_redraw_clips()

func _on_project_changed(new_project: Project):
	if new_project == project:
		# Update our track data reference
		if track_index < project.tracks.size():
			track_data = project.tracks[track_index]
			_redraw_clips()


func _get_clip_id(clip: AudioClipEvent) -> String:
	var stream_name = ""
	if clip.audio_stream:
		stream_name = clip.audio_stream.resource_path
	return "%f_%s_%f" % [clip.start_time_sec, stream_name, clip.volume_db]

func _unhandled_key_input(event: InputEvent):
	if not project or not is_visible_in_tree():
		return
	
	# Only process if this track lane is visible and has focus
	if event is InputEventKey and event.pressed:
		var handled = false
		
		match event.keycode:
			KEY_DELETE, KEY_BACKSPACE:
				if not _selected_clips.is_empty():
					_delete_selected_clips()
					handled = true
			KEY_D:
				if event.ctrl_pressed and not _selected_clips.is_empty():
					_duplicate_selected_clips()
					handled = true
			KEY_A:
				if event.ctrl_pressed:
					_select_all_clips()
					handled = true
			KEY_ESCAPE:
				if not _selected_clips.is_empty():
					_clear_selection()
					handled = true
		
		if handled:
			get_viewport().set_input_as_handled()

func _delete_selected_clips():
	if _selected_clips.is_empty():
		return
	
	for clip in _selected_clips:
		track_data.events.erase(clip)
	
	_selected_clips.clear()
	_redraw_clips()
	
	# Notify project of changes
	CurrentProject.project_changed.emit(CurrentProject.project)

func _duplicate_selected_clips():
	if _selected_clips.is_empty():
		return
	
	var time_offset = 60.0 / project.bpm # Offset by one beat
	_pending_selection_ids.clear()
	
	# Create duplicates
	for clip in _selected_clips:
		var new_clip = clip.duplicate()
		new_clip.start_time_sec += time_offset
		track_data.events.append(new_clip)
		# Store the ID of what the new clip will be
		_pending_selection_ids.append(_get_clip_id(new_clip))
	
	# Notify project of changes
	CurrentProject.project_changed.emit(CurrentProject.project)

func _select_all_clips():
	_selected_clips.clear()
	for event in track_data.events:
		if event is AudioClipEvent:
			_selected_clips.append(event)
	_update_clip_selections()

func _clear_selection():
	_selected_clips.clear()
	_update_clip_selections()

func _update_clip_selections():
	for child in get_children():
		if child is AudioClipUI:
			child.set_selected(child.clip_event in _selected_clips)


func _redraw_clips():
	# Clear existing clips
	for child in get_children():
		child.queue_free()
	
	# Create new clip UIs
	for event in track_data.events:
		if event is AudioClipEvent:
			_create_clip_ui(event)

func _create_clip_ui(event: AudioClipEvent):
	var clip_ui = C.Scenes.AudioClipUI.instantiate()
	clip_ui.clip_event = event
	clip_ui.project = project
	
	# Set position and size
	clip_ui.position.x = event.start_time_sec * project.view_zoom
	clip_ui.position.y = 10 # Add some padding from top
	
	# Calculate width based on duration or use minimum
	var clip_width = event.duration_sec * project.view_zoom
	clip_ui.custom_minimum_size.x = max(80, clip_width)
	clip_ui.size.x = max(80, clip_width)
	clip_ui.size.y = 60 # Fixed height
	
	# Set selection state
	clip_ui.set_selected(event in _selected_clips)
	
	# Connect signals
	clip_ui.clip_moved.connect(_on_clip_moved)
	clip_ui.gui_input.connect(_on_clip_gui_input.bind(clip_ui))
	
	add_child(clip_ui)

func _on_clip_gui_input(event: InputEvent, clip_ui: AudioClipUI):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.ctrl_pressed:
				# Toggle selection
				_toggle_clip_selection(clip_ui.clip_event)
			elif event.shift_pressed and not _selected_clips.is_empty():
				# Range select
				_range_select_to_clip(clip_ui.clip_event)
			elif clip_ui.clip_event not in _selected_clips:
				# Select only this clip
				_selected_clips.clear()
				_selected_clips.append(clip_ui.clip_event)
				_update_clip_selections()

func _toggle_clip_selection(clip: AudioClipEvent):
	if clip in _selected_clips:
		_selected_clips.erase(clip)
	else:
		_selected_clips.append(clip)
	_update_clip_selections()

func _range_select_to_clip(target_clip: AudioClipEvent):
	if _selected_clips.is_empty():
		return
	
	var first_selected = _selected_clips[0]
	var start_time = min(first_selected.start_time_sec, target_clip.start_time_sec)
	var end_time = max(first_selected.start_time_sec, target_clip.start_time_sec)
	
	for event in track_data.events:
		if event is AudioClipEvent:
			if event.start_time_sec >= start_time and event.start_time_sec <= end_time:
				if event not in _selected_clips:
					_selected_clips.append(event)
	_update_clip_selections()

func _draw():
	# Draw track background
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.15, 0.15, 0.18, 0.5))
	
	# Draw grid lines
	if project:
		var beat_width_px = (60.0 / project.bpm) * project.view_zoom
		for i in range(int(size.x / beat_width_px) + 1):
			var x = i * beat_width_px
			var color = Color(0.3, 0.3, 0.3, 0.3) if i % 4 == 0 else Color(0.2, 0.2, 0.2, 0.2)
			draw_line(Vector2(x, 0), Vector2(x, size.y), color)

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Check if clicking on empty space (not on a clip)
		var clicked_on_clip = false
		for child in get_children():
			if child is AudioClipUI and child.get_rect().has_point(event.position):
				clicked_on_clip = true
				break
		
		if not clicked_on_clip:
			# Clear selection when clicking empty space
			if not event.shift_pressed and not event.ctrl_pressed:
				_clear_selection()
			
			# Check if there's a selected audio file to place
			var file_browser = get_node_or_null("/root/Main/SongEditor/MainHSplit/LibraryPanel/TabContainer/Files/FileBrowser")
			if file_browser and file_browser.has_method("get_selected_file"):
				var selected_file = file_browser.get_selected_file()
				if not selected_file.is_empty():
					_create_audio_clip_at(selected_file, event.position)
					accept_event()

func _create_audio_clip_at(file_path: String, position: Vector2):
	var audio_stream = load(file_path)
	if not audio_stream:
		push_error("Failed to load audio file: " + file_path)
		return
		
	var new_clip_event = AudioClipEvent.new()
	new_clip_event.audio_stream = audio_stream
	new_clip_event.start_time_sec = position.x / project.view_zoom
	
	# Snap to grid
	var beat_duration = 60.0 / project.bpm
	new_clip_event.start_time_sec = snapped(new_clip_event.start_time_sec, beat_duration / 4.0)
	
	# Add to selection
	_selected_clips.clear()
	_selected_clips.append(new_clip_event)
	
	event_created.emit(new_clip_event, track_index)

func _on_clip_moved(clip: AudioClipEvent, new_pos: Vector2):
	var new_time_sec = new_pos.x / project.view_zoom
	
	# Snap to grid
	var beat_duration = 60.0 / project.bpm
	new_time_sec = snapped(new_time_sec, beat_duration / 4.0)
	new_time_sec = max(0.0, new_time_sec) # Don't allow negative time
	
	# If multiple clips are selected, move them all
	if clip in _selected_clips and _selected_clips.size() > 1:
		var time_delta = new_time_sec - clip.start_time_sec
		for selected_clip in _selected_clips:
			if selected_clip != clip:
				var new_selected_time = selected_clip.start_time_sec + time_delta
				new_selected_time = max(0.0, new_selected_time)
				event_moved.emit(selected_clip, new_selected_time, track_index)
	
	event_moved.emit(clip, new_time_sec, track_index)

# Support drag and drop from file browser
func _can_drop_data(position: Vector2, data) -> bool:
	if data is Dictionary and data.has("type") and data["type"] == "audio_file":
		return true
	return false

func _drop_data(position: Vector2, data):
	if data is Dictionary and data.has("type") and data["type"] == "audio_file":
		if data.has("path"):
			_create_audio_clip_at(data["path"], position)
