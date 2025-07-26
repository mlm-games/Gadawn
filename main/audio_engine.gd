class_name AudioEngine
extends Node

signal playback_position_changed(time_sec: float)

var _playback_pos_sec: float = 0.0
var _is_playing: bool = false
var _project: Project
var _active_events: Dictionary = {}
var _instruments: Dictionary = {}

@onready var _voice_container: Node = %VoiceContainer
var _export_recorder: AudioEffectRecord

func _ready():
	# Ensure the voice container exists
	if not _voice_container:
		_voice_container = Node.new()
		_voice_container.name = "VoiceContainer"
		add_child(_voice_container)

func _process(delta: float) -> void:
	if not _is_playing or not _project:
		return

	var last_pos = _playback_pos_sec
	_playback_pos_sec += delta

	for i in range(_project.tracks.size()):
		var track_data = _project.tracks[i]
		if track_data.is_muted:
			continue
		
		# Get or create instrument for this track
		var instrument = _get_instrument_for_track(track_data)
		if not instrument:
			continue
		
		instrument.set_volume(track_data.volume_db)
		
		# Track active events for this track
		if not _active_events.has(i):
			_active_events[i] = {}
		
		for event in track_data.events:
			var event_id = event.get_instance_id()
			var start_time = event.get_time_component().start_time_sec
			
			# Check if event should start
			if start_time >= last_pos and start_time < _playback_pos_sec:
				if not _active_events[i].has(event_id):
					instrument.play_event(event)
					_active_events[i][event_id] = event
			
			# Check if event should stop
			if _active_events[i].has(event_id):
				var should_stop = false
				
				if event is NoteEvent:
					var end_time = start_time + event.get_time_component().duration_sec
					if _playback_pos_sec >= end_time:
						should_stop = true
				elif event is AudioClipEvent:
					var end_time = start_time + event.get_time_component().duration_sec
					if _playback_pos_sec >= end_time:
						should_stop = true
				
				if should_stop:
					instrument.stop_event(event)
					_active_events[i].erase(event_id)

	playback_position_changed.emit(_playback_pos_sec)

func _get_instrument_for_track(track_data: TrackData) -> Node:
	var track_id = track_data.get_instance_id()
	
	# Check cache first
	if _instruments.has(track_id):
		return _instruments[track_id]
	
	# Create new instrument
	var instrument = null
	match track_data.track_type:
		TrackData.TrackType.AUDIO:
			instrument = AudioInstrumentWrapper.new()
			instrument.name = "AudioTrack_" + str(track_id)
			
		TrackData.TrackType.INSTRUMENT:
			if track_data.instrument_scene:
				instrument = track_data.instrument_scene.instantiate()
				instrument.name = "InstrumentTrack_" + str(track_id)
	
	if instrument:
		_voice_container.add_child(instrument)
		_instruments[track_id] = instrument
		
	return instrument

func load_project(project: Project) -> void:
	stop()
	_project = project
	
	# Clear existing instruments
	for child in _voice_container.get_children():
		child.queue_free()
	_instruments.clear()
	_active_events.clear()
	
	# Wait for children to be freed
	await get_tree().process_frame
	
	# Pre-create instruments for all tracks
	if _project:
		for track_data in _project.tracks:
			_get_instrument_for_track(track_data)

func play() -> void:
	# Ensure all instruments are created before playing
	if _project:
		for track_data in _project.tracks:
			_get_instrument_for_track(track_data)
	
	_is_playing = true

func stop() -> void:
	_is_playing = false
	_playback_pos_sec = 0.0
	
	# Clear all active events
	_active_events.clear()
	
	# Stop all instruments
	for instrument in _instruments.values():
		if instrument and is_instance_valid(instrument) and instrument.has_method("all_notes_off"):
			instrument.all_notes_off()
		
	playback_position_changed.emit(0.0)

func set_playback_position(time_sec: float) -> void:
	_playback_pos_sec = max(0.0, time_sec)
	
	_active_events.clear()
	
	# Stop all currently playing sounds
	for instrument in _instruments.values():
		if instrument and is_instance_valid(instrument) and instrument.has_method("all_notes_off"):
			instrument.all_notes_off()
	
	playback_position_changed.emit(_playback_pos_sec)

func export_to_wav(file_path: String) -> void:
	if _project:
		for track_data in _project.tracks:
			_get_instrument_for_track(track_data)
	
	#TODO?: This is a simplified non-real-time export. (Sounds good enough for now)
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
			var end_time = event.get_time_component().start_time_sec
			if event is NoteEvent: end_time += event.get_time_component().duration_sec
			elif event is AudioClipEvent: end_time += event.get_time_component().duration_sec
			total_length = max(total_length, end_time)
	
	await get_tree().create_timer(total_length + 1.0).timeout # Wait for song length + 1s buffer
	
	_export_recorder.set_recording_active(false)
	var recording = _export_recorder.get_recording()
	stop()
	
	if recording:
		recording.save_to_wav(file_path)
	
	AudioServer.remove_bus_effect(bus_idx, effect_idx)
	_export_recorder = null
