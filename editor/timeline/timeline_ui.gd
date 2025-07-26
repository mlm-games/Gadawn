# This is the main UI controller for the timeline view. It's responsible for:
# 1. Drawing the tracks and events based on the Project data.
# 2. Handling timeline navigation (pan, zoom).
# 3. Forwarding user interactions (like moving a clip) up to the Main controller.
class_name TimelineUI
extends Control

signal add_track_requested
signal event_moved(event: TrackEvent, new_time: float, new_track_index: int)
signal event_created(event: TrackEvent, track_index: int)

@export var track_header_scene: PackedScene
@onready var track_headers_container: VBoxContainer = %TrackHeadersContainer
@onready var track_lanes_container: VBoxContainer = %TrackLanesContainer
@onready var timeline_panel: Control = %TimelinePanel
@onready var ruler_ui: RulerUI = %RulerUI
@onready var playhead: ColorRect = %Playhead
@onready var timeline_scroll: ScrollContainer = %TimelineScroll

var _last_project_state_hash: int = 0

var project: Project

# --- Public API ---

func set_project(new_project: Project):
	project = new_project
	ruler_ui.project = new_project
	
	var state_hash = hash(project.tracks.size())
	for track in project.tracks:
		state_hash ^= hash(track.track_type)
		state_hash ^= hash(track.track_name)
	
	# Only redraw if structure changed
	if state_hash != _last_project_state_hash:
		_last_project_state_hash = state_hash
		_redraw_timeline()
	else:
		# Just update the existing lanes
		for i in range(min(track_lanes_container.get_child_count(), project.tracks.size())):
			var lane = track_lanes_container.get_child(i)
			if lane.has_method("refresh_events"):
				lane.refresh_events()
	
	timeline_scroll.scroll_horizontal = int(project.view_scroll_sec * project.view_zoom)

func set_playhead_position(time_sec: float):
	playhead.position.x = time_sec * project.view_zoom

# --- Redrawing Logic ---

func _redraw_timeline():
	# Clear existing UI
	for child in track_headers_container.get_children(): child.queue_free()
	for child in track_lanes_container.get_children(): child.queue_free()

	if not project: return
	
	# Determine total length for timeline panel width
	var total_length_sec = 10.0 # Minimum 10 seconds wide
	for track in project.tracks:
		for event in track.events:
			var end_time = event.get_time_component().start_time_sec + event.get_time_component().duration_sec
			total_length_sec = max(total_length_sec, end_time)
	
	timeline_panel.custom_minimum_size.x = total_length_sec * project.view_zoom + 200 # Add buffer

	# Re-create UI from data
	for i in range(project.tracks.size()):
		var track_data = project.tracks[i]
		
		# Create Header
		var header = track_header_scene.instantiate()
		track_headers_container.add_child(header)
		header.set_track_data(track_data)
		
		# Create Track Lane based on type
		var lane_scene_path = ""
		match track_data.track_type:
			TrackData.TrackType.AUDIO:
				lane_scene_path = "res://editor/timeline/audio_track_lane_ui.tscn"
			TrackData.TrackType.INSTRUMENT:
				lane_scene_path = "res://editor/timeline/piano_roll_ui.tscn"
		
		if not lane_scene_path.is_empty(): # For some reason, removing the check causes audio to not play only while playing the track
			var lane = load(lane_scene_path).instantiate()
			track_lanes_container.add_child(lane)
			lane.set_track_data(project, i)
			
			# Connect signals to forward events up to Main
			lane.event_moved.connect(event_moved.emit)
			lane.event_created.connect(event_created.emit)

# --- Input Handling for Pan and Zoom ---

func _on_timeline_panel_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		# Middle mouse button to pan
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				get_viewport().set_input_as_handled()
			else:
				get_viewport().set_input_as_handled()
		# Scroll wheel to zoom
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(1.25)
			get_viewport().set_input_as_handled()
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(0.8)
			get_viewport().set_input_as_handled()
	
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		timeline_scroll.scroll_horizontal -= event.relative.x
		project.view_scroll_sec = timeline_scroll.scroll_horizontal / project.view_zoom
		get_viewport().set_input_as_handled()

	# Touch Gestures
	if event is InputEventPanGesture:
		timeline_scroll.scroll_horizontal -= event.delta.x * 2
		timeline_scroll.scroll_vertical -= event.delta.y * 2
		project.view_scroll_sec = timeline_scroll.scroll_horizontal / project.view_zoom
		get_viewport().set_input_as_handled()

	if event is InputEventMagnifyGesture:
		_zoom(event.factor)
		get_viewport().set_input_as_handled()
	
	if event is InputEventScreenDrag:
		# Two-finger drag for pan
		if event.index == 1:
			timeline_scroll.scroll_horizontal -= event.relative.x
			timeline_scroll.scroll_vertical -= event.relative.y
			get_viewport().set_input_as_handled()

func _zoom(factor: float):
	var mouse_pos_sec = (timeline_scroll.scroll_horizontal + get_local_mouse_position().x) / project.view_zoom
	project.view_zoom *= factor
	project.view_zoom = clamp(project.view_zoom, 5.0, 500.0) # Min/Max zoom
	_redraw_timeline()
	timeline_scroll.scroll_horizontal = mouse_pos_sec * project.view_zoom - get_local_mouse_position().x


func _on_add_track_button_pressed():
	add_track_requested.emit()
