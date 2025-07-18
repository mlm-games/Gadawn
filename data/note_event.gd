# An event representing a single musical note, to be used in a Piano Roll.
class_name NoteEvent
extends TrackEvent

@export var duration_sec: float = 0.5
@export var key: int = 60 # MIDI Note Number (60 = Middle C)
@export var velocity: int = 100 # MIDI Velocity (0-127)
