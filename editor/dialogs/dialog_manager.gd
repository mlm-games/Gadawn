class_name DialogManager
extends Control

signal file_selected(path: String)
signal file_save_selected(path: String)
signal export_path_selected(path: String)
signal new_track_confirmed(track_type: TrackData.TrackType, instrument_path: String)

@onready var file_dialog: FileDialog = %FileDialog
@onready var error_dialog: AcceptDialog = %ErrorDialog
@onready var new_track_dialog: ConfirmationDialog = %NewTrackDialog

enum DialogMode {LOAD, SAVE, EXPORT}
var _current_mode: DialogMode

func show_load_dialog():
	_current_mode = DialogMode.LOAD
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = ["*.tres ; Godawn Project"]
	file_dialog.popup_centered()

func show_save_dialog():
	_current_mode = DialogMode.SAVE
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.filters = ["*.tres ; Godawn Project"]
	file_dialog.popup_centered()
	
func show_export_dialog():
	_current_mode = DialogMode.EXPORT
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.filters = ["*.wav ; WAV Audio"]
	file_dialog.popup_centered()
	
func show_new_track_dialog():
	new_track_dialog.popup_centered()
	if not new_track_dialog.confirmed.is_connected(_on_new_track_confirmed):
		new_track_dialog.confirmed.connect(_on_new_track_confirmed)

func show_error(message: String):
	error_dialog.dialog_text = message
	error_dialog.popup_centered()

func _on_file_dialog_file_selected(path: String):
	match _current_mode:
		DialogMode.LOAD: file_selected.emit(path)
		DialogMode.SAVE: file_save_selected.emit(path)
		DialogMode.EXPORT: export_path_selected.emit(path)
		
func _on_new_track_confirmed():
	new_track_confirmed.emit(new_track_dialog.get_selected_type(), new_track_dialog.get_selected_instrument())
