class_name DialogManager extends Control

@onready var file_dialog: FileDialog = %FileDialog

func progress(text: String) -> ProgressBar:
	%ProgressLabel.text = text
	%ProgressDialog.popup_centered()
	return %ProgressBar

func hide_progress():
	%ProgressDialog.hide()

func get_save_path(title: String, filters: Array) -> String:
	file_dialog.title = title
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.filters = PackedStringArray(filters)
	file_dialog.popup_centered()
	var file_path = await file_dialog.file_selected
	return file_path

func get_open_path(title: String, filters: Array) -> String:
	file_dialog.title = title
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = PackedStringArray(filters)
	file_dialog.popup_centered()
	var file_path = await file_dialog.file_selected
	return file_path

func error(text: String):
	%ErrorMessageLabel.text = text
	%ErrorDialog.popup_centered()

func start_loading():
	%LoadingDialog.popup_centered()
	
func stop_loading():
	%LoadingDialog.hide()
