class_name InstrumentBrowserUI
extends VBoxContainer

func _ready():
	_populate_instruments()

func scan_folder(_path: String):
	#HACK: This method is kept for compatibility but uses the registry instead (rm in future)
	_populate_instruments()

func _populate_instruments():
	for child in get_children():
		child.queue_free()
	
	var instruments = InstrumentRegistry.get_all_instruments()
	
	# Sort by name
	var sorted_ids = instruments.keys()
	sorted_ids.sort_custom(func(a, b): return instruments[a]["name"] < instruments[b]["name"])
	
	for id in sorted_ids:
		var instrument_data = instruments[id]
		var btn = Button.new()
		btn.text = instrument_data["name"]
		btn.icon = get_theme_icon(instrument_data["icon"], "EditorIcons")
		btn.set_meta("scene_path", instrument_data["scene"].resource_path)
		btn.set_meta("instrument_id", id)
		add_child(btn)

func _can_drop_data(_pos, _data) -> bool:
	return false

func _drop_data(_pos, _data):
	pass

func _get_drag_data(pos):
	for child in get_children():
		if child is Button and child.get_rect().has_point(pos):
			var preview = Label.new()
			preview.text = child.text
			set_drag_preview(preview)
			return {"type": "instrument", "path": child.get_meta("scene_path")}
	return null
