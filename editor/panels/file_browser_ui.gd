class_name FileBrowserUI
extends VBoxContainer

static var I: FileBrowserUI

func _init() -> void:
	I = self

signal audio_file_selected(file_path: String)

var selected_sample_id: StringName = ""
var selected_button: Button = null

func _ready():
	_populate_from_collection()

func scan_folder(_path: String):
	_populate_from_collection()

func _populate_from_collection():
	for child in get_children():
		child.queue_free()
	
	var samples = AudioSampleManager.I.get_all_samples()
	
	var sorted_ids = samples.keys()
	sorted_ids.sort()
	
	for id in sorted_ids:
		var stream = samples[id]
		var btn = AudioFileButton.new()
		btn.setup(str(id), stream)
		btn.pressed.connect(_on_button_pressed.bind(btn, id))
		add_child(btn)

func _on_button_pressed(button: Button, sample_id: StringName):
	# Deselect previous button
	if selected_button and selected_button != button:
		selected_button.button_pressed = false
	
	if button.button_pressed:
		selected_button = button
		selected_sample_id = sample_id
		var stream = AudioSampleManager.I.get_sample(sample_id)
		if stream:
			audio_file_selected.emit(stream.resource_path)
	else:
		selected_button = null
		selected_sample_id = ""

func get_selected_file() -> String:
	var stream = AudioSampleManager.I.get_sample(selected_sample_id)
	return stream.resource_path if stream else ""

# Custom button class for drag and drop
class AudioFileButton extends Button:
	var sample_id: StringName
	var audio_stream: AudioStream
	
	func setup(id: String, stream: AudioStream):
		self.text = id
		self.sample_id = id
		self.audio_stream = stream
		self.toggle_mode = true
		self.icon = C.Icons.AudioFile
	
	func _can_drop_data(_position: Vector2, _data) -> bool:
		return false
	
	func _get_drag_data(_position: Vector2):
		if button_pressed and audio_stream:
			var preview = Label.new()
			preview.text = text
			set_drag_preview(preview)
			return {"type": "audio_file", "path": audio_stream.resource_path, "stream": audio_stream}
		return null
