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
			btn.gui_input.connect(_on_button_gui_input.bind(file_path))
			add_child(btn)
		file_name = dir.get_next()

func _on_button_gui_input(event: InputEvent, file_path: String):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var preview = Label.new()
		preview.text = file_path.get_file()
		set_drag_preview(preview)
		# The data we are dragging is a dictionary identifying the type and path.
		#FIXME: set_drag_data({"type": "audio_clip", "path": file_path})
