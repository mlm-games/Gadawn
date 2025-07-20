class_name AudioEngine
extends Node

signal playback_position_changed(time_sec: float)

var _playback_pos_sec: float = 0.0
var _is_playing: bool = false
var _project: Project
var _active_audio_clips: Dictionary = {} # Track which clips are playing

@onready var _voice_container: Node = %VoiceContainer
var _export_recorder: AudioEffectRecord

func _process(delta: float) -> void:
	if not _is_playing:
		return

	var last_pos = _playback_pos_sec
	_playback_pos_sec += delta
	
	if not _project: return

	for i in range(_project.tracks.size()):
		var track_data = _project.tracks[i]
		if track_data.is_muted: continue
		
		var instrument = _voice_container.get_node_or_null(str(track_data.get_instance_id()))
		if not instrument: continue
		
		instrument.set_volume(track_data.volume_db)
		
		for event in track_data.events:
			var start_time = event.start_time_sec
			var event_id = str(i) + "_" + str(event.get_instance_id())
			
			# Handle starting events
			if start_time >= last_pos and start_time < _playback_pos_sec:
				instrument.play_event(event)
				if event is AudioClipEvent:
					_active_audio_clips[event_id] = event
			
			# Handle stopping events
			if event is NoteEvent:
				var end_time = start_time + event.duration_sec
				if end_time >= last_pos and end_time < _playback_pos_sec:
					instrument.stop_event(event)
			elif event is AudioClipEvent and _active_audio_clips.has(event_id):
				var end_time = start_time + event.duration_sec
				if _playback_pos_sec >= end_time:
					instrument.stop_event(event)
					_active_audio_clips.erase(event_id)

	playback_position_changed.emit(_playback_pos_sec)

func load_project(project: Project) -> void:
	_project = project
	stop()
	
	# Clear existing instruments
	for child in _voice_container.get_children():
		child.queue_free()
	
	# Wait for children to be freed
	await get_tree().process_frame

	if not _project: return
		
	for track_data in _project.tracks:
		var track_id_str = str(track_data.get_instance_id())
		match track_data.track_type:
			TrackData.TrackType.AUDIO:
				# Create the wrapper instrument for audio tracks
				var wrapper_script = preload("res://instruments/audio_instrument_wrapper.gd")
				var audio_instrument = wrapper_script.new()
				audio_instrument.name = track_id_str
				_voice_container.add_child(audio_instrument)

			TrackData.TrackType.INSTRUMENT:
				if track_data.instrument_scene:
					var inst = track_data.instrument_scene.instantiate()
					inst.name = track_id_str
					_voice_container.add_child(inst)

func play() -> void:
	_is_playing = true

func stop() -> void:
	if not _is_playing:
		set_playback_position(0.0)
		
	_is_playing = false
	_playback_pos_sec = 0.0
	_active_audio_clips.clear()
	
	for child in _voice_container.get_children():
		if child.has_method("all_notes_off"):
			child.all_notes_off()
		
	playback_position_changed.emit(0.0)

func set_playback_position(time_sec: float) -> void:
	_playback_pos_sec = max(0.0, time_sec)
	_active_audio_clips.clear()
	
	# Stop all currently playing sounds
	for child in _voice_container.get_children():
		if child.has_method("all_notes_off"):
			child.all_notes_off()
	
	playback_position_changed.emit(_playback_pos_sec)
	
func export_to_wav(file_path: String) -> void:
	# This is a simplified non-real-time export.
	# For a real implementation, a more robust offline processing loop is needed.
	_export_recorder = AudioEffectRecord.new()
	var bus_idx = AudioServer.get_bus_index("Master")
	var effect_idx = AudioServer.get_bus_effect_count(bus_idx)
	AudioServer.add_bus_effect(bus_idx, _export_recorder, effect_idx)

	_export_recorder.set_recording_active(true)
	play()
	
	# This is a naive way to wait for the song to finish.
	# A proper implementation would use a non-real-time process loop.
	var total_length = 0.0
	for track in _project.tracks:
		for event in track.events:
			var end_time = event.start_time_sec
			if event is NoteEvent: end_time += event.duration_sec
			elif event is AudioClipEvent: end_time += event.duration_sec
			total_length = max(total_length, end_time)
	
	await get_tree().create_timer(total_length + 1.0).timeout # Wait for song length + 1s buffer
	
	_export_recorder.set_recording_active(false)
	var recording = _export_recorder.get_recording()
	stop()
	
	if recording:
		recording.save_to_wav(file_path)
	
	AudioServer.remove_bus_effect(bus_idx, effect_idx)
	_export_recorder = null
