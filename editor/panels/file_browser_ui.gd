class_name FileBrowserUI
extends VBoxContainer

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
		if not dir.current_is_dir() and (file_name.ends_with(".wav") or file_name.ends_with(".ogg")):
			var file_path = path.path_join(file_name)
			var btn = Button.new()
			btn.text = file_name
			btn.icon = get_theme_icon("AudioStreamWAV", "EditorIcons")
			btn.toggle_mode = true
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
