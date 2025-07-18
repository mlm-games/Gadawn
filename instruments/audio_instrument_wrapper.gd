class_name AudioInstrumentWrapper extends Instrument

var player: AudioStreamPlayer

func play_event(event: TrackEvent):
	if event is AudioClipEvent: 
		player.stream = event.audio_stream
		player.play()

func set_volume(volume_db: float): 
	player.volume_db = volume_db

func all_notes_off(): 
	player.stop()
