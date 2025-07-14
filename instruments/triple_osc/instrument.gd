extends LiveSynthesisInstrument

const OCTAVE_FACTOR = pow(2, 1.0/12)

var currently_playing := {}

func _init():
	super("TripleOsc", 22050)

func waveform(_t: float):
	# Add amplitudes
	var amp = 0.0
	for key in currently_playing:
		var freq = to_hertz(currently_playing[key].key)
		# Triple oscillator with harmonics
		amp += Waveforms.sine(t, freq, 0) * 0.5
		amp += Waveforms.sine(t, 2 * freq, 0) * 0.25
		amp += Waveforms.sine(t, 3 * freq, 0) * 0.125

	# Return normalized wave
	if currently_playing.size() == 0:
		return 0.0
	return amp / currently_playing.size()

# TODO: Move this to MIDI later
func to_hertz(key_no):
	return pow(OCTAVE_FACTOR, (key_no - 69)) * 440

func play_note(note: Note):
	currently_playing[note.instrument_data.key] = note.instrument_data
	super.play_note(note)

func stop_note(note: Note):
	currently_playing.erase(note.instrument_data.key)
	if currently_playing.size() == 0:
		super.stop_note(note)
