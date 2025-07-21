class_name FileBrowserUI
extends VBoxContainer

static var I: FileBrowserUI

func _init() -> void:
	I = self

signal audio_file_selected(file_path: String)

var selected_file_path: String = ""
var selected_button: Button = null

func scan_folder(path: String):
	for child in get_children():
		child.queue_free()

	var dir = DirAccess.open(path)
	if not dir: return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and (file_name.ends_with(".wav") or file_name.ends_with(".ogg") or file_name.ends_with(".mp3")):
			var file_path = path.path_join(file_name)
			var btn = AudioFileButton.new()
			btn.setup(file_name, file_path)
			btn.pressed.connect(_on_button_pressed.bind(btn, file_path))
			add_child(btn)
		file_name = dir.get_next()

func _on_button_pressed(button: Button, file_path: String):
	# Deselect previous button
	if selected_button and selected_button != button:
		selected_button.button_pressed = false
	
	if button.button_pressed:
		selected_button = button
		selected_file_path = file_path
		audio_file_selected.emit(file_path)
	else:
		selected_button = null
		selected_file_path = ""

func get_selected_file() -> String:
	return selected_file_path

# Custom button class for drag and drop
class AudioFileButton extends Button:
	var file_path: String
	# var _is_touch_dragging: bool = false
	
	func setup(text: String, path: String):
		self.text = text
		self.file_path = path
		self.toggle_mode = true
		self.icon = C.Icons.AudioFile
		
	#func _gui_input(event: InputEvent): #NOTE: duplis, transition here?
		## Handle touch drag
		#if event is InputEventScreenTouch:
			#if event.pressed and button_pressed:
				#_is_touch_dragging = true
				## Start drag operation
				#var preview = Label.new()
				#preview.text = text
				#set_drag_preview(preview)
		#
		#if event is InputEventScreenDrag and _is_touch_dragging:
			## Continue drag operation
			#pass
		#
		#if event is InputEventMouseButton:
			#if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and button_pressed:
				## Start drag operation
				#var preview = Label.new()
				#preview.text = text
				#set_drag_preview(preview)
	
	func _can_drop_data(_position: Vector2, _data) -> bool:
		return false
	
	func _get_drag_data(_position: Vector2):
		if button_pressed:
			var preview = Label.new()
			preview.text = text
			set_drag_preview(preview)
			return {"type": "audio_file", "path": file_path}
		return null
