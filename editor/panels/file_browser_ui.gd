class_name FileBrowserUI
extends VBoxContainer

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
			btn.set_meta("drag_data", {"type": "audio_clip", "path": file_path})
			btn.gui_input.connect(_on_button_gui_input.bind(btn))
			add_child(btn)
		file_name = dir.get_next()

func _on_button_gui_input(event: InputEvent, button: Button):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var preview = Label.new()
		preview.text = button.text
		set_drag_preview(preview)

func _can_drop_data(_pos, data) -> bool:
	return false

func _drop_data(_pos, data):
	pass  # This control doesn't accept drops

func _get_drag_data(_pos):
	# Find which button is under the mouse
	for child in get_children():
		if child is Button and child.get_global_rect().has_point(get_global_mouse_position()):
			return child.get_meta("drag_data")
	return null
