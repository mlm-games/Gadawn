extends RefCounted

class_name SampleTools

var sample: AudioStream
var data: PackedByteArray

func _init(sample_duration: float, mix_rate: int = 44100):
	data = PackedByteArray([])
	sample = AudioStream.new()

	sample.mix_rate = mix_rate
	#sample.loop_mode = AudioStream.LOOP_FORWARD
	sample.loop_begin = 0
	sample.loop_end = int(sample_duration * mix_rate)

func mix_rate() -> int:
	return sample.mix_rate

func total_sample_count() -> int:
	return int(sample.loop_end)

func append_data(amplitude: float):
	data.append(127 * amplitude)

func as_sample() -> AudioStream:
	sample.data = data
	return sample
