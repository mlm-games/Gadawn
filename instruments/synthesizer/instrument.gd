# A powerful polyphonic synthesizer instrument, integrating the core logic from gDAW.
# It manages multiple "Voice" nodes to play several notes at once.
class_name SynthesizerInstrument
extends Instrument

## --- SYNTH SETTINGS (from gDAW) ---
enum Waveform {SINE, TRIANGLE, SQUARE, SAW, WHITE_NOISE}
@export_category("Oscillator")
@export var waveform := Waveform.SINE

@export_category("ADSR Envelope")
@export var attack_sec: = 0.01
@export var decay_sec := 0.1
@export var sustain_level := 0.7
@export var release_sec := 0.2

var _voices: Dictionary = {} # Maps note key -> Voice instance

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
