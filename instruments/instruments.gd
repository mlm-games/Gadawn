# This is the base class for all playable instruments in Godawn.
# The AudioEngine will instantiate a scene that uses a script inheriting from this.
# It expects these methods to be implemented.
@abstract class_name Instrument
extends Node

# Called by the AudioEngine when a timeline event for this track should start.
func play_event(_event: TrackEvent):
	pass

# Called by the AudioEngine when a timeline event should stop.
func stop_event(_event: TrackEvent):
	pass
	
# Called by the AudioEngine to set the track's volume.
func set_volume(_volume_db: float):
	pass

# Called by the AudioEngine's stop() method to silence all playing notes.
func all_notes_off():
	pass
