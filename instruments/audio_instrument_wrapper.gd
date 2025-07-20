## A wrapper to make a simple AudioStreamPlayer conform to the Instrument interface.
class_name AudioInstrumentWrapper
extends Instrument

var player: AudioStreamPlayer
var active_clips: Dictionary = {} # Track active clips by their event reference

func _ready():
	player = AudioStreamPlayer.new()
	player.name = "AudioPlayer"
	add_child(player)
	player.finished.connect(_on_player_finished)

func play_event(event: TrackEvent):
	if event is AudioClipEvent and event.audio_stream:
		active_clips[event] = true
		
		player.stream = event.audio_stream
		player.volume_db = event.volume_db
		player.play()

func stop_event(event: TrackEvent):
	if event is AudioClipEvent and active_clips.has(event):
		active_clips.erase(event)
		if active_clips.is_empty():
			player.stop()

func set_volume(volume_db: float):
	player.volume_db = volume_db
	
func all_notes_off():
	active_clips.clear()
	player.stop()

func _on_player_finished():
	# Clear finished clips
	active_clips.clear()
