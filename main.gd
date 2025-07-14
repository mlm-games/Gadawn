#TODO: Connect all signals through code.
#TODO: Add an interactive tutorial
#NOTE: Always ensure its touch friendly (original reason for fork: To easily make sfx in commute)
#TODO: Allow playing midi audio to USB-A to C connected (touch) devices

##NOTE: Initializes the app and handles top-level file operations.

class_name Main extends MarginContainer

static var instance: Main

func _init() -> void:
	instance = self

var export_recorder: AudioEffectRecord

@onready var control_panel: PanelContainer = %ControlPanel
@onready var song_editor: SongEditor = %SongEditor
@onready var instruments_panel: PanelContainer = %InstrumentsPanel
@onready var status_bar: PanelContainer = %StatusBar
@onready var dialog_manager: DialogManager = %DialogManager
@onready var song_validator: SongValidator = %SongValidator
@onready var sequencer: Sequencer = %Sequencer
@onready var top_menu: HBoxContainer = %TopMenu

func _ready():
	get_window().min_size = Vector2i(1024, 600)
	
	var progress = %DialogManager.progress("Loading...")
	
	# Connect all signals to establish SOT
	_connect_all_signals()
	
	GoDawn.loading_progress_max_value_changed.connect(progress.set_max)
	GoDawn.loading_progress_value_changed.connect(func(): progress.value += 1)
	GoDawn.loading_instrument_changed.connect(%DialogManager.progress)
	await GoDawn.load_instruments()
	%DialogManager.hide_progress()
	%InstrumentsPanel.reload_instruments()

	var dir = DirAccess.open("user://")
	if dir and dir.file_exists("song_to_validate.gd"):
		dir.remove("song_to_validate.gd")

	var default_project = Project.new("Untitled Song", Project.PROJECT_TYPE.SONGSCRIPT)
	CurrentProject.project = default_project

func _connect_all_signals():
	# Project change signals
	CurrentProject.project_changed.connect(song_editor.on_project_changed)
	
	# Control panel signals
	control_panel.play_pressed.connect(song_editor._on_play_pressed)
	control_panel.pause_pressed.connect(sequencer.pause)
	control_panel.stop_pressed.connect(sequencer.stop)
	control_panel.bpm_changed.connect(_on_bpm_changed)
	
	# Sequencer signals
	sequencer.playback_started.connect(control_panel.on_playback_started)
	sequencer.playback_stopped.connect(control_panel.on_playback_stopped)
	sequencer.playback_finished.connect(control_panel.on_playback_stopped)
	
	# Song validator signals
	song_validator.validation_succeeded.connect(song_editor._on_validation_succeeded)
	song_validator.validation_failed.connect(status_bar.set_error_status)
	
	# Export validation signals
	song_validator.validation_succeeded.connect(_on_validation_succeeded_for_export)
	song_validator.validation_failed.connect(_on_validation_failed_for_export)
	
	# Song editor signals
	song_editor.validation_requested_for_export.connect(_on_validation_requested_for_export)
	
	# Instruments panel signals
	instruments_panel.instrument_chosen.connect(song_editor.add_track)
	
	# Top menu signals
	top_menu.new_pressed.connect(_on_top_menu_new_pressed)
	top_menu.open_pressed.connect(_on_top_menu_open_pressed)
	top_menu.save_pressed.connect(_on_top_menu_save_pressed)
	top_menu.save_as_pressed.connect(_on_top_menu_save_as_pressed)
	top_menu.export_pressed.connect(_on_top_menu_export_pressed)
	top_menu.quit_pressed.connect(_on_top_menu_quit_pressed)

func _on_bpm_changed(bpm: float):
	if CurrentProject.project and CurrentProject.project.song_sequence:
		CurrentProject.project.song_sequence.tempo = int(bpm)

func _on_validation_requested_for_export():
	song_validator.validate_script(song_editor.get_script_text())

func _on_top_menu_new_pressed():
	var new_song_dialog = dialog_manager.get_node("NewSong")
	new_song_dialog.popup_centered()
	var project = await new_song_dialog.new_project
	if project:
		CurrentProject.project = project

func _on_top_menu_export_pressed():
	song_editor.request_validation_for_export()

func _on_validation_succeeded_for_export(sequence: SongSequence):
	var file_path = await dialog_manager.get_save_path("Export", ["*.wav ; Wav Files"])
	if file_path.is_empty():
		return
	
	sequencer.sequence(sequence)
	await _perform_export(file_path)

func _on_validation_failed_for_export(error_message: String):
	dialog_manager.error("Cannot export. " + error_message)

func _perform_export(file_path: String) -> void:
	export_recorder = AudioEffectRecord.new()
	var recorder_index = AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, export_recorder, recorder_index)
	
	var progress = dialog_manager.progress("Exporting...")
	
	var _conn = sequencer.playback_progressed.connect(progress.set_value)
	
	export_recorder.set_recording_active(true)
	sequencer.play()
	await sequencer.playback_finished
	export_recorder.set_recording_active(false)
	
	sequencer.playback_progressed.disconnect(progress.set_value)

	var recording = export_recorder.get_recording()
	if recording:
		recording.save_to_wav(file_path)
	else:
		dialog_manager.error("Failed to record audio")
	
	AudioServer.remove_bus_effect(0, recorder_index)
	export_recorder = null
	dialog_manager.hide_progress()

func _on_top_menu_save_pressed():
	var project = CurrentProject.project
	if project.saved and not project.resource_path.is_empty():
		_save(project.resource_path)
	else:
		_on_top_menu_save_as_pressed()

func _on_top_menu_save_as_pressed():
	var file_path = await dialog_manager.get_save_path("Save As", ["*.tres; Godot Text Resource File", "*.res; Godot Resource File"])
	if file_path.is_empty():
		return
	
	CurrentProject.project.saved = true
	_save(file_path)

func _save(file_path: String):
	CurrentProject.project.song_script = song_editor.get_script_text()
	var error = ResourceSaver.save(CurrentProject.project, file_path)
	if error != OK:
		dialog_manager.error("Failed to save project: " + error_string(error))

func _on_top_menu_open_pressed():
	var file_path = await dialog_manager.get_open_path("Open", ["*.tres; Godot Text Resource File", "*.res; Godot Resource File"])
	if file_path.is_empty():
		return
	
	var loaded_project = ResourceLoader.load(file_path)
	if loaded_project and loaded_project is Project:
		CurrentProject.project = loaded_project
	else:
		dialog_manager.error("Failed to load project")

func _on_top_menu_quit_pressed():
	get_tree().quit()
