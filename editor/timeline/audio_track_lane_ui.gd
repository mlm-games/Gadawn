class_name AudioTrackLaneUI
extends Control

signal event_moved(event: TrackEvent, new_time: float, new_track_index: int)
signal event_created(event: TrackEvent, track_index: int)

var track_data: TrackData
var project: Project
var track_index: int

var clip_ui_scene = preload("res://editor/timeline/audio_clip_ui.tscn")

func set_track_data(p_project: Project, p_track_index: int):
	project = p_project
	track_index = p_track_index
	track_data = project.tracks[track_index]
	_redraw_clips()

func _redraw_clips():
	for child in get_children():
		child.queue_free()
	
	for event in track_data.events:
		if event is AudioClipEvent:
			var clip_ui = clip_ui_scene.instantiate()
			clip_ui.clip_event = event
			clip_ui.project = project
			clip_ui.position.x = event.start_time_sec * project.view_zoom
			clip_ui.size.x = event.duration_sec * project.view_zoom
			clip_ui.clip_moved.connect(_on_clip_moved)
			add_child(clip_ui)

func _can_drop_data(_pos, data) -> bool:
	return data is Dictionary and data.has("type") and data["type"] == "audio_clip"

func _drop_data(pos, data):
	var new_clip_event = AudioClipEvent.new()
	new_clip_event.audio_stream = load(data["path"])
	new_clip_event.start_time_sec = pos.x / project.view_zoom
	event_created.emit(new_clip_event, track_index)

func _on_clip_moved(clip: AudioClipEvent, new_pos: Vector2):
	var new_time_sec = new_pos.x / project.view_zoom
	event_moved.emit(clip, new_time_sec, track_index)
