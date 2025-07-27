class_name AudioExporter #BRoken
extends RefCounted

static func export_project(project: Project, output_path: String, sample_rate: int = 44100) -> bool:
	var total_seconds = _get_project_length(project)
	var total_samples = int(total_seconds * sample_rate)
	
	var buffer = PackedFloat32Array()
	buffer.resize(total_samples * 2) # Stereo
	
	# Render each track
	for track in project.tracks:
		if track.is_muted:
			continue
			
		_render_track(track, buffer, sample_rate, project.bpm)
	
	# Normalize to prevent clipping
	var peak = 0.0
	for sample in buffer:
		peak = max(peak, abs(sample))
	
	if peak > 0.0:
		var scale = 0.95 / peak # Leave some headroom
		for i in buffer.size():
			buffer[i] *= scale
	
	return _save_wav(buffer, output_path, sample_rate)

static func _render_track(track: TrackData, buffer: PackedFloat32Array, sample_rate: int, bpm: float):
	if not track.instrument_scene:
		return
		
	for event in track.events:
		if event is NoteEvent:
			var start_sample = int(event.get_time_component().start_time_sec * sample_rate)
			var duration_samples = int(event.get_time_component().duration_sec * sample_rate)
			
			# Simple synthesis
			var freq = 440.0 * pow(2.0, (event.get_component("pitch").key - 69) / 12.0)
			var phase = 0.0
			var phase_increment = freq / sample_rate
			
			for i in duration_samples:
				if start_sample + i >= buffer.size() / 2:
					break
					
				# Generate sample based on instrument settings
				var envelope = _calculate_envelope(i, duration_samples, track.instrument_scene.instantiate())
				var sample = sin(phase * TAU) * envelope * event.get_component("velocity").velocity / 127.0 * 0.3
				
				buffer[(start_sample + i) * 2] += sample
				buffer[(start_sample + i) * 2 + 1] += sample
				
				phase = fmod(phase + phase_increment, 1.0)

static func _calculate_envelope(sample: int, total_samples: int, instrument: SynthesizerInstrument) -> float:
	var time = float(sample) / 44100.0
	var total_time = float(total_samples) / 44100.0
	
	# Simple ADSR
	if time < instrument.attack_sec:
		return time / instrument.attack_sec
	elif time < instrument.attack_sec + instrument.decay_sec:
		var decay_progress = (time - instrument.attack_sec) / instrument.decay_sec
		return lerp(1.0, instrument.sustain_level, decay_progress)
	elif time < total_time - instrument.release_sec:
		return instrument.sustain_level
	else:
		var release_progress = (time - (total_time - instrument.release_sec)) / instrument.release_sec
		return lerp(instrument.sustain_level, 0.0, release_progress)

static func _save_wav(buffer: PackedFloat32Array, path: String, sample_rate: int) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return false
	
	# WAV header
	file.store_string("RIFF")
	file.store_32(36 + buffer.size() * 2)
	file.store_string("WAVE")
	file.store_string("fmt ")
	file.store_32(16)
	file.store_16(1) # PCM
	file.store_16(2) # Stereo
	file.store_32(sample_rate)
	file.store_32(sample_rate * 2 * 2)
	file.store_16(4)
	file.store_16(16)
	file.store_string("data")
	file.store_32(buffer.size() * 2)
	
	# Convert float to 16-bit PCM
	for sample in buffer:
		var pcm = clampi(int(sample * 32767), -32768, 32767)
		file.store_16(pcm)
	
	file.close()
	return true

static func _get_project_length(project: Project) -> float:
	var length = 0.0
	for track in project.tracks:
		for event in track.events:
			var end_time = event.get_time_component().start_time_sec + event.get_time_component().duration_sec
			length = max(length, end_time)
	return length + 1.0 # Add 1 second padding
