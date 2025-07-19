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
			btn.set_meta("drag_data", {"type": "instrument", "path": scene_path})
			btn.gui_input.connect(_on_button_gui_input.bind(btn))
			add_child(btn)

func _on_button_gui_input(event: InputEvent, button: Button):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var preview = Label.new()
		preview.text = button.text
		set_drag_preview(preview)

func _can_drop_data(_pos, data) -> bool:
	return false

func _drop_data(_pos, data):
	pass

func _get_drag_data(_pos):
	for child in get_children():
		if child is Button and child.get_global_rect().has_point(get_global_mouse_position()):
			return child.get_meta("drag_data")
	return null
