#TODO: Connect all signals through code.
#TODO: Add an interactive tutorial
#NOTE: Always ensure its touch friendly (original reason for fork: To easily make sfx in commute)
#TODO: Allow playing midi audio to USB-A to C connected (touch) devices

##NOTE: Initializes the app and handles top-level file operations.

class_name Main
extends Control

@onready var song_editor: SongEditor = %SongEditor
@onready var audio_engine: AudioEngine = %AudioEngine
@onready var dialog_manager: DialogManager = %DialogManager

func _ready() -> void:
	_on_new_project.call_deferred() #NOTE: Doesnt init properly without defer call

	_connect_signals()

	song_editor.library_panel.file_browser.scan_folder(C.PATHS.AUDIO_SAMPLES_FOLDER)
	song_editor.library_panel.instrument_browser.scan_folder(C.PATHS.INSTRUMENTS_FOLDER)

func _connect_signals() -> void:
	CurrentProject.project_changed.connect(song_editor.on_project_changed)
	CurrentProject.project_changed.connect(audio_engine.load_project)

	song_editor.transport_bar.play_pressed.connect(audio_engine.play)
	song_editor.transport_bar.stop_pressed.connect(audio_engine.stop)
	song_editor.transport_bar.playback_scrubbed.connect(audio_engine.set_playback_position)
	
	audio_engine.playback_position_changed.connect(song_editor.timeline_ui.set_playhead_position)
	audio_engine.playback_position_changed.connect(song_editor.transport_bar.update_time_display)

	song_editor.top_bar.new_project_requested.connect(_on_new_project)
	song_editor.top_bar.save_project_requested.connect(_on_save_project)
	song_editor.top_bar.load_project_requested.connect(dialog_manager.show_load_dialog)
	song_editor.top_bar.export_wav_requested.connect(dialog_manager.show_export_dialog)
	
	song_editor.timeline_ui.add_track_requested.connect(dialog_manager.show_new_track_dialog)
	song_editor.timeline_ui.event_moved.connect(CurrentProject.move_event)
	song_editor.timeline_ui.event_created.connect(CurrentProject.add_event_to_track)
	
	dialog_manager.file_selected.connect(_on_file_selected_for_load)
	dialog_manager.file_save_selected.connect(_on_file_selected_for_save)
	dialog_manager.export_path_selected.connect(audio_engine.export_to_wav)
	dialog_manager.new_track_confirmed.connect(CurrentProject.add_track)

func _on_new_project() -> void:
	CurrentProject.set_project(Project.new())

func _on_save_project() -> void:
	var project = CurrentProject.project
	if project.resource_path.is_empty():
		dialog_manager.show_save_dialog()
	else:
		ResourceSaver.save(project, project.resource_path)
		print("Saved!") # Add a status bar message here later.

func _on_file_selected_for_save(path: String) -> void:
	ResourceSaver.save(CurrentProject.project, path)

func _on_file_selected_for_load(path: String) -> void:
	var loaded_res = ResourceLoader.load(path)
	if loaded_res is Project:
		CurrentProject.set_project(loaded_res)
	else:
		dialog_manager.show_error("Failed to load file. Not a valid Godawn project.")
		
