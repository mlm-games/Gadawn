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
			btn.set_meta("scene_path", scene_path)
			add_child(btn)

func _can_drop_data(_pos, _data) -> bool:
	return false

func _drop_data(_pos, _data):
	pass

func _get_drag_data(pos):
	# Find which button is under the mouse
	for child in get_children():
		if child is Button and child.get_rect().has_point(pos):
			var preview = Label.new()
			preview.text = child.text
			set_drag_preview(preview)
			return {"type": "instrument", "path": child.get_meta("scene_path")}
	return null
