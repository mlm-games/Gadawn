class_name Sequencer extends Node

signal playback_started
signal playback_stopped
signal playback_finished
signal playback_progressed(percent: float)

var INSTRUMENTS: Dictionary = {}
var current_sequence: SongSequence
var playing: bool = false
var paused: bool = false

@onready var anim_player: AnimationPlayer = $AnimationPlayer

func _ready():
	anim_player.animation_finished.connect(_on_animation_finished)

# Called by the validator when a script is successfully parsed
func sequence(new_sequence: SongSequence):
	current_sequence = new_sequence
	var song = Animation.new()
	song.step = 0.001
	var total_length = 0.0

	for track in current_sequence.tracks:
		var track_index = song.add_track(Animation.TYPE_METHOD)
		song.track_set_path(track_index, ".")

		var track_max_time = 0.0
		for note in track.notes:
			var start_time = note.note_start_delta
			var end_time = start_time + note.duration
			
			song.track_insert_key(track_index, start_time, {
				"method": "play_note", "args": [track.instrument, note]
			})
			song.track_insert_key(track_index, end_time, {
				"method": "stop_note", "args": [track.instrument, note]
			})
			track_max_time = max(track_max_time, end_time)
		
		total_length = max(total_length, track_max_time)
	
	song.length = total_length
	
	if anim_player.has_animation("song"):
		anim_player.remove_animation("song")
	anim_player.add_animation("song", song)

func _process(_delta):
	if playing and not paused:
		if anim_player.current_animation_length > 0:
			var progress = (anim_player.current_animation_position / anim_player.current_animation_length) * 100
			playback_progressed.emit(progress)

func play_note(instrument_name: String, note: Note):
	if INSTRUMENTS.has(instrument_name):
		(INSTRUMENTS[instrument_name] as Instrument).play_note(note)

func stop_note(instrument_name: String, note: Note):
	if INSTRUMENTS.has(instrument_name):
		(INSTRUMENTS[instrument_name] as Instrument).stop_note(note)

func play():
	if not anim_player.has_animation("song"):
		return

	if paused:
		paused = false
		anim_player.play()
	else:
		anim_player.play("song")

	playing = true
	playback_started.emit()

func stop():
	playing = false
	paused = false
	anim_player.stop()
	anim_player.seek(0, true)
	playback_stopped.emit()

func pause():
	if playing and not paused:
		paused = true
		playing = false
		anim_player.stop(false)
		playback_stopped.emit()

func _on_animation_finished(_anim_name):
	stop()
	playback_finished.emit()
