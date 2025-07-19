# A wrapper to make a simple AudioStreamPlayer conform to the Instrument interface.
class_name AudioInstrumentWrapper
extends Instrument

var player: AudioStreamPlayer

func _ready():
	player = AudioStreamPlayer.new()
	add_child(player)

func play_event(event: TrackEvent):
	if event is AudioClipEvent:
		player.stream = event.audio_stream
		player.volume_db = event.volume_db
		player.play()

func stop_event(event: TrackEvent):
	if event is AudioClipEvent:
		player.stop()

func set_volume(volume_db: float):
	player.volume_db = volume_db
	
func all_notes_off():
	player.stop()
