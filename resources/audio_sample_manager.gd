class_name AudioSampleManager
extends Node

static var I: AudioSampleManager

const COLLECTION_PATH = "res://resources/audio_samples_collection.tres"
const USER_COLLECTION_PATH = "user://custom_audio_samples.tres"
const SAMPLES_DIR = "res://assets/audio_samples/"

var collection: AudioSampleCollection
var user_collection: AudioSampleCollection

func _init() -> void:
	I = self

func _ready() -> void:
	if ResourceLoader.exists(COLLECTION_PATH):
		collection = load(COLLECTION_PATH) as AudioSampleCollection
	else:
		collection = AudioSampleCollection.new()
	
	# Load user collection
	if ResourceLoader.exists(USER_COLLECTION_PATH):
		user_collection = load(USER_COLLECTION_PATH) as AudioSampleCollection
	else:
		user_collection = AudioSampleCollection.new()
	
	if OS.has_feature("editor"):
		_update_collection_in_editor()

func _update_collection_in_editor() -> void:
	var audio_files = _scan_directory_recursive(SAMPLES_DIR, ["wav", "ogg", "mp3"])
	var updated = false
	
	for file_path in audio_files:
		var id = file_path.get_file().get_basename()
		if not id in collection.samples:
			var stream = load(file_path) as AudioStream
			if stream:
				collection.samples[id] = stream
				updated = true
				print("Added audio sample: ", id)
	
	if updated:
		var error = ResourceSaver.save(collection, COLLECTION_PATH)
		if error == OK:
			print("Updated audio collection with %d samples" % collection.samples.size())
		else:
			push_error("Failed to save audio collection: " + str(error))

func _scan_directory_recursive(path: String, extensions: Array[String]) -> Array[String]:
	var files : Array[String] = []
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			var full_path = path.path_join(file_name)
			if dir.current_is_dir() and not file_name.begins_with("."):
				files.append_array(_scan_directory_recursive(full_path, extensions))
			else:
				for ext in extensions:
					if file_name.ends_with("." + ext):
						files.append(full_path)
						break
			file_name = dir.get_next()
	return files

func get_all_samples() -> Dictionary[StringName, AudioStream]:
	var all_samples : Dictionary[StringName, AudioStream] = {}
	all_samples.merge(collection.samples)
	all_samples.merge(user_collection.samples)
	return all_samples

func get_sample(id: StringName) -> AudioStream:
	if id in collection.samples:
		return collection.samples[id]
	elif id in user_collection.samples:
		return user_collection.samples[id]
	return null

func add_user_sample(file_path: String, custom_name: String = "") -> AudioStream:
	var stream = load(file_path) as AudioStream
	if not stream:
		push_error("Failed to load audio file: " + file_path)
		return null
	
	var id = custom_name if custom_name else file_path.get_file().get_basename()
	user_collection.samples[id] = stream
	
	# Save user collection
	ResourceSaver.save(user_collection, USER_COLLECTION_PATH)
	
	return stream

func import_external_audio(file_path: String, custom_name: String = "") -> AudioStream:
	# For importing audio files from outside the project
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Cannot open file: " + file_path)
		return null
	
	var file_data = file.get_buffer(file.get_length())
	file.close()
	
	# Save to user directory
	var id = custom_name if custom_name else file_path.get_file().get_basename()
	var user_path = "user://imported_audio/" + id + "." + file_path.get_extension()
	
	DirAccess.make_dir_recursive_absolute("user://imported_audio/")
	
	var save_file = FileAccess.open(user_path, FileAccess.WRITE)
	save_file.store_buffer(file_data)
	save_file.close()
	
	# Load and add to collection
	var stream = load(user_path) as AudioStream
	if stream:
		user_collection.samples[id] = stream
		ResourceSaver.save(user_collection, USER_COLLECTION_PATH)
	
	return stream
