extends Instrument

class_name PianoInstrument

const OCTAVE_FACTOR = pow(2, 1.0/12)

var player: AudioStreamPlayer

func _init(instrument_name: String):
	super(instrument_name)

func _ready():
	# Use the existing player from the scene if available
	if has_node("AudioStreamPlayer"):
		player = $AudioStreamPlayer
	else:
		player = get_new_player()
	
	player.bus = AudioServer.get_bus_name(bus_idx)
	player.stream = create_sample(440.00)

func play_note(note):
	player.pitch_scale = (to_hertz(note.instrument_data.key) / 440.00)
	player.play()

func stop_note(note):
	player.stop()

func to_hertz(key_no):
	return pow(OCTAVE_FACTOR, (key_no - 69)) * 440

func create_sample(freq: float) -> AudioStreamWAV:
	# Create sample and set its sample rate
	var sample = SampleTools.new(1.0)
	var sample_end = sample.total_sample_count()
	var mix_rate = sample.mix_rate()

	# Start sampling
	for t in sample_end:
		# Call waveform function at each sample interval
		var amplitude = waveform(float(t) / mix_rate, freq)
		# Store into sample buffer
		sample.append_data(amplitude)

	return sample.as_sample()

func waveform(t: float, freq: float) -> float:
	return 0.0
