class_name SampleTools

var sample: AudioStreamWAV
var data: PackedByteArray

func _init(sample_duration: float, mix_rate: int = 44100):
	data = PackedByteArray([])
	sample = AudioStreamWAV.new()

	sample.mix_rate = mix_rate
	sample.loop_mode = AudioStreamWAV.LOOP_FORWARD
	sample.loop_begin = 0
	sample.loop_end = int(sample_duration * mix_rate)
	# Set format for 8-bit audio
	sample.format = AudioStreamWAV.FORMAT_8_BITS

func mix_rate() -> int:
	return sample.mix_rate

func total_sample_count() -> int:
	return int(sample.loop_end)

func append_data(amplitude: float):
	# Convert from -1.0 to 1.0 range to 0-255 range for 8-bit audio
	var byte_value = int((amplitude + 1.0) * 127.5)
	byte_value = clamp(byte_value, 0, 255)
	data.append(byte_value)

func as_sample() -> AudioStreamWAV:
	sample.data = data
	return sample
