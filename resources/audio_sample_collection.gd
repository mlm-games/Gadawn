class_name AudioSampleCollection
extends Resource

@export var samples: Dictionary[StringName, AudioStream] = {}

func get_sample(id: StringName) -> AudioStream:
	return samples.get(id, null)

func get_all_samples() -> Dictionary[StringName, AudioStream]:
	return samples

func add_sample(id: StringName, stream: AudioStream):
	samples[id] = stream
	emit_changed()
