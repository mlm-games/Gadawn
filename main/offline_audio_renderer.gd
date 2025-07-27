class_name OfflineAudioRenderer # Can use later
extends RefCounted

var project: Project
var total_length: float
var sample_rate: int = 44100
var buffer_size: int = 512

func render() -> PackedFloat32Array:
	var total_samples = int(total_length * sample_rate)
	var audio_buffer = PackedFloat32Array()
	audio_buffer.resize(total_samples * 2) # Stereo
	
	var temp_instruments = {}
	
	for track_data in project.tracks:
		match track_data.track_type:
			TrackData.TrackType.AUDIO:
				var wrapper = AudioInstrumentWrapper.new()
				temp_instruments[track_data] = wrapper
			TrackData.TrackType.INSTRUMENT:
				if track_data.instrument_scene:
					var inst = track_data.instrument_scene.instantiate()
					temp_instruments[track_data] = inst
	
	# Process audio in chunks
	var current_time = 0.0
	var samples_processed = 0
	var active_events = {}
	
	while samples_processed < total_samples:
		var chunk_samples = min(buffer_size, total_samples - samples_processed)
		var chunk_time = float(chunk_samples) / sample_rate
		var next_time = current_time + chunk_time
		
		# Process events for this time range
		for track_data in project.tracks:
			if track_data.is_muted:
				continue
				
			var instrument = temp_instruments.get(track_data)
			if not instrument:
				continue
			
			# Check for new events to start
			for event in track_data.events:
				var event_id = event.get_instance_id()
				
				if event.start_time_sec >= current_time and event.start_time_sec < next_time:
					if event is AudioClipEvent:
						var samples = _render_audio_clip(event, current_time, chunk_samples, sample_rate)
						_mix_samples(audio_buffer, samples, samples_processed, track_data.volume_db)
						active_events[event_id] = {"event": event, "start_sample": samples_processed}
					elif event is NoteEvent:
						var samples = _render_note(event, instrument, current_time, chunk_samples, sample_rate)
						_mix_samples(audio_buffer, samples, samples_processed, track_data.volume_db)
				
				# Check for events to stop
				if active_events.has(event_id):
					var end_time = event.start_time_sec
					if event is NoteEvent:
						end_time += event.duration_sec
					elif event is AudioClipEvent:
						end_time += event.duration_sec
					
					if end_time >= current_time and end_time < next_time:
						active_events.erase(event_id)
		
		current_time = next_time
		samples_processed += chunk_samples
		
		# Update progress (could emit a signal here)
		var progress = float(samples_processed) / total_samples
		if int(progress * 100) % 10 == 0:
			print("Export progress: ", int(progress * 100), "%")
	
	# Clean up temporary instruments
	for inst in temp_instruments.values():
		if inst is Node:
			inst.queue_free()
	
	return audio_buffer

func _render_audio_clip(event: AudioClipEvent, current_time: float, chunk_samples: int, sample_rate: int) -> PackedFloat32Array:
	var samples = PackedFloat32Array()
	samples.resize(chunk_samples * 2) # Stereo
	
	if not event.audio_stream:
		return samples
	
	# This is simplified - in reality, you'd need to properly decode the audio stream
	# For now, return silence
	return samples

func _render_note(event: NoteEvent, instrument: Node, current_time: float, chunk_samples: int, sample_rate: int) -> PackedFloat32Array:
	var samples = PackedFloat32Array()
	samples.resize(chunk_samples * 2) # Stereo
	
	# Generate synthesized audio based on the instrument type
	if instrument is SynthesizerInstrument:
		var frequency = 27.50 * pow(1.05946309436, event.key - 33)
		var phase_increment = frequency / sample_rate
		var start_phase = 0.0
		
		for i in range(chunk_samples):
			var sample_time = current_time + float(i) / sample_rate - event.start_time_sec
			if sample_time < 0 or sample_time > event.duration_sec:
				continue
			
			# Calculate envelope
			var envelope = _calculate_adsr(sample_time, event.duration_sec, instrument)
			
			# Generate waveform
			var phase = fmod(start_phase + phase_increment * i, 1.0)
			var sample = _generate_waveform(phase, instrument.waveform) * envelope * (event.get_component("velocity").velocity / 127.0)
			
			# Write stereo sample
			samples[i * 2] = sample
			samples[i * 2 + 1] = sample
	
	return samples

func _calculate_adsr(time: float, duration: float, synth: SynthesizerInstrument) -> float:
	if time < synth.attack_sec:
		return time / synth.attack_sec
	elif time < synth.attack_sec + synth.decay_sec:
		var decay_progress = (time - synth.attack_sec) / synth.decay_sec
		return lerp(1.0, synth.sustain_level, decay_progress)
	elif time < duration - synth.release_sec:
		return synth.sustain_level
	else:
		var release_progress = (time - (duration - synth.release_sec)) / synth.release_sec
		return lerp(synth.sustain_level, 0.0, release_progress)
	return 0.0

func _generate_waveform(phase: float, waveform: SynthesizerInstrument.Waveform) -> float:
	var t = phase * TAU
	match waveform:
		SynthesizerInstrument.Waveform.SINE: return sin(t)
		SynthesizerInstrument.Waveform.SQUARE: return sign(sin(t))
		SynthesizerInstrument.Waveform.SAW: return 2.0 * (phase - floor(phase + 0.5))
		SynthesizerInstrument.Waveform.TRIANGLE: return 2.0 * abs(2.0 * (phase - floor(phase + 0.5))) - 1.0
		SynthesizerInstrument.Waveform.WHITE_NOISE: return randf_range(-1.0, 1.0)
	return 0.0

func _mix_samples(target: PackedFloat32Array, source: PackedFloat32Array, offset: int, volume_db: float):
	var volume_linear = db_to_linear(volume_db)
	for i in range(source.size()):
		if offset * 2 + i < target.size():
			target[offset * 2 + i] += source[i] * volume_linear
