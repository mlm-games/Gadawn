# A single polyphonic voice for the SynthesizerInstrument.
# This contains the actual audio generation and ADSR logic from gDAW.
# It is self-contained and destroys itself after its note has finished.
class_name SynthesizerVoice
extends AudioStreamPlayer

enum State {ATTACK, DECAY, SUSTAIN, RELEASE, STOPPED}

var _synth: SynthesizerInstrument
var _note: NoteEvent
var _playback: AudioStreamGeneratorPlayback
var _phase: float = 0.0
var _frequency: float = 440.0
var _current_level: float = 0.0
var _release_start_level: float = 0.0

var _state: State = State.STOPPED
var _time_in_state: float = 0.0

const NOTE_FREQUENCIES_BASE_A = 27.50
const OCTAVE_FACTOR = 1.05946309436 # 2^(1/12)

func init_voice(synth_instrument: SynthesizerInstrument, note_event: NoteEvent):
	_synth = synth_instrument
	_note = note_event
	_frequency = NOTE_FREQUENCIES_BASE_A * pow(OCTAVE_FACTOR, _note.get_component("pitch").key - 33)
	
	var stream_gen = AudioStreamGenerator.new()
	stream_gen.mix_rate = AudioServer.get_mix_rate()
	stream_gen.buffer_length = 0.05
	self.stream = stream_gen
	
	self.volume_db = linear_to_db(_note.get_component("velocity").velocity / 127.0)
	
	_set_state(State.ATTACK)
	play()
	
	# Get playback after starting to play
	_playback = get_stream_playback()

func _set_state(new_state: State):
	_state = new_state
	_time_in_state = 0.0
	if new_state == State.RELEASE:
		_release_start_level = _current_level

func release_note():
	if _state != State.RELEASE and _state != State.STOPPED:
		_set_state(State.RELEASE)

func _process(delta: float):
	if _state == State.STOPPED:
		return
		
	_time_in_state += delta
	_update_state_machine()
	_fill_buffer()

func _update_state_machine():
	match _state:
		State.ATTACK:
			if _time_in_state >= _synth.attack_sec:
				_set_state(State.DECAY)
		State.DECAY:
			if _time_in_state >= _synth.decay_sec:
				_set_state(State.SUSTAIN)
		State.RELEASE:
			if _time_in_state >= _synth.release_sec:
				_set_state(State.STOPPED)
				_synth.call_deferred("_on_voice_finished", self, _note.get_component("pitch").key)
				queue_free()

func _fill_buffer():
	if not _playback:
		return
		
	var frames_to_fill = _playback.get_frames_available()
	for i in range(frames_to_fill):
		_current_level = _get_envelope_level()
		var sample = _get_waveform_sample() * _current_level
		_playback.push_frame(Vector2.ONE * sample)
		_phase = fmod(_phase + _frequency / stream.mix_rate, 1.0)
		
func _get_envelope_level() -> float:
	match _state:
		State.ATTACK:
			return ease(_time_in_state / _synth.attack_sec, 1.0)
		State.DECAY:
			var t = _time_in_state / _synth.decay_sec
			return lerp(1.0, _synth.sustain_level, t)
		State.SUSTAIN:
			return _synth.sustain_level
		State.RELEASE:
			var t = _time_in_state / _synth.release_sec
			return lerp(_release_start_level, 0.0, t)
	return 0.0

func _get_waveform_sample() -> float:
	var t = _phase * TAU
	match _synth.waveform:
		SynthesizerInstrument.Waveform.SINE: return sin(t)
		SynthesizerInstrument.Waveform.SQUARE: return sign(sin(t))
		SynthesizerInstrument.Waveform.SAW: return 2.0 * (t / TAU - floor(t / TAU + 0.5))
		SynthesizerInstrument.Waveform.TRIANGLE: return 2.0 * abs(2.0 * (t / TAU - floor(t / TAU + 0.5))) - 1.0
		SynthesizerInstrument.Waveform.WHITE_NOISE: return randf_range(-1.0, 1.0)
	return 0.0
