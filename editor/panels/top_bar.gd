class_name TopBar
extends PanelContainer

signal new_project_requested
signal load_project_requested
signal save_project_requested
signal export_wav_requested

@onready var file_menu: MenuButton = %FileMenu
@onready var project_name_label: Label = %ProjectNameLabel

func _on_file_menu_about_to_popup():
	# Connect the signal just before showing, so it only triggers once.
	if not file_menu.get_popup().id_pressed.is_connected(_on_file_menu_id_pressed):
		file_menu.get_popup().id_pressed.connect(_on_file_menu_id_pressed)

func _on_file_menu_id_pressed(id: int):
	match id:
		0: new_project_requested.emit()
		1: load_project_requested.emit()
		2: save_project_requested.emit()
		4: export_wav_requested.emit()

func set_project_name(name: String):
	project_name_label.text = name
