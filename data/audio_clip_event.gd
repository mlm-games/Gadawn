# An event representing an audio sample.
class_name AudioClipEvent
extends TrackEvent

@export var audio_stream: AudioStream

@export var duration_sec: float = 0.0:
	get:
		return audio_stream.get_length() if audio_stream else 0.0

@export var volume_db: float = 0.0