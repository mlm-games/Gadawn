extends PianoInstrument

func _init():
	super("square")

func waveform(t, freq):
	return Waveforms.square(t, freq, 0) * 0.3  # Reduced amplitude to prevent clipping
