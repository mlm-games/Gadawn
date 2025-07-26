class_name ChiptuneInstrument
extends Instrument

enum WaveType {
	PULSE_12_5, # 12.5% duty cycle
	PULSE_25, # 25% duty cycle
	PULSE_50, # 50% duty cycle (square)
	PULSE_75, # 75% duty cycle
	TRIANGLE,
	SAWTOOTH,
	NOISE
}

@export var wave_type: WaveType = WaveType.PULSE_50
@export var vibrato_depth: float = 0.0 # 0-1
@export var vibrato_speed: float = 5.0 # Hz
@export var pitch_sweep: float = 0.0 # semitones per second
@export var arpeggio_pattern: Array[int] = [0, 4, 7] # semitone offsets
@export var arpeggio_speed: float = 0.0 # notes per second (0 = disabled)

# Envelope
@export var attack_ms: float = 1.0
@export var decay_ms: float = 10.0
@export var sustain_level: float = 0.8
@export var release_ms: float = 50.0

var _active_voices: Dictionary = {}

class ChipVoice:
	var phase: float = 0.0
	var frequency: float = 440.0
	var velocity: float = 1.0
	var time: float = 0.0
	var released: bool = false
	var release_time: float = 0.0
	var arpeggio_index: int = 0
	var arpeggio_time: float = 0.0
	var base_frequency: float = 440.0

func play_event(event: TrackEvent):
	var voice = ChipVoice.new()
	voice.base_frequency = 440.0 * pow(2.0, (event.key - 69) / 12.0)
	voice.frequency = voice.base_frequency
	voice.velocity = event.velocity / 127.0
	_active_voices[event] = voice

func stop_event(event: TrackEvent):
	if event in _active_voices:
		_active_voices[event].released = true

func process_audio(buffer: AudioFrame, sample_rate: float) -> AudioFrame:
	var output = AudioFrame()
	
	for event in _active_voices:
		var voice = _active_voices[event]
		
		# Update voice time
		voice.time += 1.0 / sample_rate
		if voice.released:
			voice.release_time += 1.0 / sample_rate
		
		# Apply arpeggio
		if arpeggio_speed > 0 and arpeggio_pattern.size() > 0:
			voice.arpeggio_time += 1.0 / sample_rate
			var arp_period = 1.0 / arpeggio_speed
			if voice.arpeggio_time >= arp_period:
				voice.arpeggio_time -= arp_period
				voice.arpeggio_index = (voice.arpeggio_index + 1) % arpeggio_pattern.size()
			
			var semitone_offset = arpeggio_pattern[voice.arpeggio_index]
			voice.frequency = voice.base_frequency * pow(2.0, semitone_offset / 12.0)
		
		# Apply pitch sweep
		if pitch_sweep != 0.0:
			var sweep_semitones = pitch_sweep * voice.time
			voice.frequency = voice.base_frequency * pow(2.0, sweep_semitones / 12.0)
		
		# Apply vibrato
		if vibrato_depth > 0.0:
			var vibrato = sin(voice.time * vibrato_speed * TAU) * vibrato_depth
			voice.frequency *= 1.0 + vibrato * 0.05
		
		# Generate waveform
		var sample = _generate_sample(voice, sample_rate)
		
		# Apply envelope
		var envelope = _calculate_envelope(voice)
		sample *= envelope * voice.velocity * 0.3 # Scale down to prevent clipping
		
		output.left += sample
		output.right += sample
	
	# Clean up finished voices
	var to_remove = []
	for event in _active_voices:
		var voice = _active_voices[event]
		if voice.released and voice.release_time > release_ms / 1000.0:
			to_remove.append(event)
	
	for event in to_remove:
		_active_voices.erase(event)
	
	return output

func _generate_sample(voice: ChipVoice, sample_rate: float) -> float:
	var phase_increment = voice.frequency / sample_rate
	voice.phase = fmod(voice.phase + phase_increment, 1.0)
	
	match wave_type:
		WaveType.PULSE_12_5:
			return 1.0 if voice.phase < 0.125 else -1.0
		WaveType.PULSE_25:
			return 1.0 if voice.phase < 0.25 else -1.0
		WaveType.PULSE_50:
			return 1.0 if voice.phase < 0.5 else -1.0
		WaveType.PULSE_75:
			return 1.0 if voice.phase < 0.75 else -1.0
		WaveType.TRIANGLE:
			if voice.phase < 0.5:
				return 4.0 * voice.phase - 1.0
			else:
				return 3.0 - 4.0 * voice.phase
		WaveType.SAWTOOTH:
			return 2.0 * voice.phase - 1.0
		WaveType.NOISE:
			return randf() * 2.0 - 1.0
	
	return 0.0

func _calculate_envelope(voice: ChipVoice) -> float:
	var attack_time = attack_ms / 1000.0
	var decay_time = decay_ms / 1000.0
	
	if voice.released:
		# Release phase
		var release_progress = voice.release_time / (release_ms / 1000.0)
		return sustain_level * (1.0 - release_progress)
	elif voice.time < attack_time:
		# Attack phase
		return voice.time / attack_time
	elif voice.time < attack_time + decay_time:
		# Decay phase
		var decay_progress = (voice.time - attack_time) / decay_time
		return 1.0 - (1.0 - sustain_level) * decay_progress
	else:
		# Sustain phase
		return sustain_level
