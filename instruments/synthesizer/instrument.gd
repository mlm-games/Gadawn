class_name SynthesizerInstrument
extends Instrument

## --- SYNTH SETTINGS (from gDAW) ---
enum Waveform {SINE, TRIANGLE, SQUARE, SAW, WHITE_NOISE}
@export_category("Oscillator")
@export var waveform := Waveform.SINE

var wavetable: Array[PackedFloat32Array] = []
var wavetable_position: float = 0.0

@export_category("ADSR Envelope")
@export var attack_sec: = 0.01
@export var decay_sec := 0.1
@export var sustain_level := 0.7
@export var release_sec := 0.2

var _voices: Dictionary[int, SynthesizerVoice]

func _init() -> void:
	_create_wavetables()

func play_event(event: TrackEvent):
	if not event is NoteEvent: return
	
	# Stop the existing voice for this key if it's still playing
	if _voices.has(event.get_component("pitch").key):
		_voices[event.get_component("pitch").key].release_note()
	
	var new_voice = SynthesizerVoice.new()
	add_child(new_voice)
	new_voice.init_voice(self, event)
	
	_voices[event.get_component("pitch").key] = new_voice

func stop_event(event: TrackEvent):
	if event is NoteEvent and _voices.has(event.get_component("pitch").key):
		_voices[event.get_component("pitch").key].release_note()

func all_notes_off():
	for key in _voices:
		_voices[key].release_note()
		
func _on_voice_finished(voice, key):
	if _voices.has(key) and _voices[key] == voice:
		_voices.erase(key)


func _create_wavetables():
	var table_size = 2048
	
	# Sine wave
	var sine_table = PackedFloat32Array()
	for i in table_size:
		sine_table.append(sin(i * TAU / table_size))
	wavetable.append(sine_table)
	
	# Square with band limiting
	var square_table = PackedFloat32Array()
	for i in table_size:
		var sample = 0.0
		for harmonic in range(1, 20, 2): # Odd harmonics only
			sample += sin(i * TAU * harmonic / table_size) / harmonic
		square_table.append(sample * 0.8)
	wavetable.append(square_table)
	
	# Saw with band limiting...
	var saw_table = PackedFloat32Array()
	for i in table_size:
		var sample = 0.0
		for harmonic in range(1, 30):
			sample += sin(i * TAU * harmonic / table_size) / harmonic * (1 if harmonic % 2 else -1)
		saw_table.append(sample * 0.6)
	wavetable.append(saw_table)

func get_sample_at_phase(phase: float, waveform_index: int) -> float:
	var table = wavetable[waveform_index]
	var index = phase * table.size()
	var i = int(index)
	var frac = index - i
	
	var s1 = table[i % table.size()]
	var s2 = table[(i + 1) % table.size()]
	
	return lerp(s1, s2, frac)
