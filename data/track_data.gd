# This resource defines a single track in the project.
# It can be either an AUDIO track (for clips) or an INSTRUMENT track (for notes).
class_name TrackData
extends Resource

enum TrackType {AUDIO, INSTRUMENT}

@export var track_name: String = "Track"
@export var track_type: TrackType = TrackType.AUDIO

# This array can hold either AudioClipEvents or NoteEvents.
@export var events: Array[TrackEvent] = []

# If it's an INSTRUMENT track, this scene is instantiated for playback.
@export var instrument_scene: PackedScene

# Standard track properties
@export var is_muted: bool = false
@export var is_solo: bool = false
@export var volume_db: float = 0.0