class_name InstrumentBrowserUI
extends VBoxContainer

func scan_folder(path: String):
	for child in get_children():
		child.queue_free()

	var dir = DirAccess.open(path)
	if not dir: return

	var subdirs = dir.get_directories()
	for subdir_name in subdirs:
		var scene_path = path.path_join(subdir_name).path_join("instrument.tscn")
		if dir.dir_exists(path.path_join(subdir_name)) and FileAccess.file_exists(scene_path):
			var btn = Button.new()
			btn.text = subdir_name.capitalize()
			btn.icon = get_theme_icon("PluginScript", "EditorIcons")
			btn.gui_input.connect(_on_button_gui_input.bind(scene_path))
			add_child(btn)

func _on_button_gui_input(event: InputEvent, scene_path: String):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var preview = Label.new()
		preview.text = scene_path.get_file()
		set_drag_preview(preview)
		#FIXME: the method doesn't exist: set_drag_data({"type": "instrument", "path": scene_path})
