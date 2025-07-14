class_name DialogManager extends Control

@onready var documents_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)

# Progress
func progress(text: String) -> ProgressBar:
	%ProgressLabel.text = text
	%ProgressDialog.popup_centered()
	return %ProgressBar

func hide_progress():
	%ProgressDialog.hide()

# FileDialog
func file(title: String, mode: FileDialog.FileMode, filters: Array) -> void:
	%FileDialog.title = title
	%FileDialog.file_mode = mode
	%FileDialog.filters = PackedStringArray(filters)
	%FileDialog.current_dir = documents_dir
	%FileDialog.popup_centered()

# Error
func error(text: String):
	%ErrorMessageLabel.text = text
	%ErrorDialog.popup_centered()

func start_loading():
	%LoadingDialog.popup_centered()
	
func stop_loading():
	%LoadingDialog.hide()
