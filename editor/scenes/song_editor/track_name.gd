extends Button

signal delete_requested

func _ready() -> void:
	# Add right-click context menu
	gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var popup = PopupMenu.new()
			popup.add_item("Edit", 0)
			popup.add_separator()
			popup.add_item("Delete", 1)
			popup.id_pressed.connect(_on_popup_id_pressed)
			add_child(popup)
			popup.position = global_position + event.position
			popup.popup()

func _on_popup_id_pressed(id: int):
	match id:
		0: # Edit
			pressed.emit()
		1: # Delete
			var confirm = ConfirmationDialog.new()
			confirm.dialog_text = "Delete this track?"
			confirm.confirmed.connect(func(): delete_requested.emit())
			get_tree().root.add_child(confirm)
			confirm.popup_centered()
			confirm.visibility_changed.connect(func(): if not confirm.visible: confirm.queue_free())

func set_instrument(icon_texture: Texture, instrument_name: String) -> void:
	self.icon = icon_texture
	text = instrument_name
	if instrument_name.length() > 20:
		text = instrument_name.substr(0, 17) + "..."
