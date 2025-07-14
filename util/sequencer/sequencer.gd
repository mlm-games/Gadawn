class_name Sequencer extends Node

signal playback_finished()
signal on_note(progress)

@export var INSTRUMENTS = {}

# Data
var data: SongSequence
var playing: bool = false
var paused: bool = false

# Functions
func sequence(s_seq: SongSequence):
	data = s_seq
	var song = Animation.new()
	song.set_step(0.001)

	for track in data.tracks:
		track = track as Track
		var track_index = song.add_track(Animation.TYPE_METHOD)

		song.track_set_path(track_index, ".")
		var current_time = 0.0
		for note in track.notes:
			note = note as Note

			if song.track_find_key(track_index, current_time, 0 as Animation.FindMode, true) != -1:
				current_time += 0.001

			current_time += note.note_start_delta
			song.track_insert_key(track_index, current_time, {
				"method": "play_note",
				"args": [track.instrument, note]
			})

			song.track_insert_key(track_index, current_time + note.duration, {
				"method": "stop_note",
				"args": [track.instrument, note]
			})

		song.length = 0 if track.notes.is_empty() else current_time + track.notes[-1].duration

	%AnimationPlayer.add_animation("song", song)

func play_note(instrument_name: String, note):
	on_note.emit((%AnimationPlayer.current_animation_position / %AnimationPlayer.current_animation_length) * 100)
	(INSTRUMENTS[instrument_name] as Instrument).play_note(note)

func stop_note(instrument_name: String, note):
	on_note.emit((%AnimationPlayer.current_animation_position / %AnimationPlayer.current_animation_length) * 100)
	(INSTRUMENTS[instrument_name] as Instrument).stop_note(note)

func play():
	playing = true
	if paused:
		paused = false
		%AnimationPlayer.play()
		return
	%AnimationPlayer.stop()
	%AnimationPlayer.play("song")

func stop():
	playing = false
	%AnimationPlayer.stop()

func pause():
	paused = true
	%AnimationPlayer.stop(false)

func seek(sec: float):
	%AnimationPlayer.seek(sec, true)
	pass

func finished(_anim):
	playback_finished.emit()
