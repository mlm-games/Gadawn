#TODO: Connect all signals through code.
#TODO: Add an interactive tutorial
#NOTE: Always ensure its touch friendly (original reason for fork: To easily make sfx in commute)
#TODO: Allow playing midi audio to USB-A to C connected (touch) devices

extends MarginContainer

var project: Project

signal project_changed(project)

func _ready():
	# Set minimum window size
	get_window().min_size = Vector2i(1024, 600)
	
	# Load instruments
	var progress = %DialogManager.progress("Loading...")
	GoDAW.loading_progress_max_value_changed.connect(progress.set_max)
	GoDAW.loading_progress_value_changed.connect(func(_v): progress.value += 1)
	GoDAW.loading_instrument_changed.connect(%DialogManager.progress)
	await GoDAW.load_instruments()
	%DialogManager.hide_progress()
	%InstrumentsPanel.reload_instruments()

	# Clear song history
	var dir = DirAccess.open("user://")
	if dir and dir.file_exists("song.gd"):
		dir.remove("song.gd")

	# Project setup
	set_project(Project.new())

func _on_top_menu_export_pressed():
	%DialogManager.file("Export", FileDialog.FILE_MODE_SAVE_FILE, ["*.wav ; Wav Files"])
	var file_path = await %DialogManager.file_dialog.file_selected
	
	await %SongEditor.sequence()
	
	var recorder = AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, recorder, AudioServer.get_bus_effect_count(0))
	
	var progress = %DialogManager.progress("Exporting...")
	progress.max_value = 100
	var _conn = %SongEditor.sequencer.on_note.connect(progress.set_value)
	
	recorder.set_recording_active(true)
	%SongEditor.sequencer.play()
	await %SongEditor.sequencer.playback_finished
	recorder.set_recording_active(false)
	
	%SongEditor.sequencer.on_note.disconnect(progress.set_value)

	# Save recording
	var recording = recorder.get_recording()
	if recording:
		recording.save_to_wav(file_path)
	else:
		%DialogManager.error("Failed to record audio")
	
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	%DialogManager.hide_progress()

func _save(file_path):
	project.song_script = %SongEditor.song_script_editor.text
	var error = ResourceSaver.save(project, file_path)
	if error != OK:
		%DialogManager.error("Failed to save project: " + error_string(error))

func _load(file_path):
	var loaded_project = ResourceLoader.load(file_path)
	if loaded_project and loaded_project is Project:
		set_project(loaded_project)
	else:
		%DialogManager.error("Failed to load project")

func _on_top_menu_save_pressed():
	if project.saved and not project.resource_path.is_empty():
		_save(project.resource_path)
	else:
		_on_top_menu_save_as_pressed()

func _on_top_menu_save_as_pressed():
	%DialogManager.file("Save", FileDialog.FILE_MODE_SAVE_FILE, ["*.tres; Godot Text Resource File", "*.res; Godot Resource File"])
	var file_path = await %DialogManager.file_dialog.file_selected
	project.saved = true
	_save(file_path)

func _on_top_menu_open_pressed():
	%DialogManager.file("Open", FileDialog.FILE_MODE_OPEN_FILE, ["*.tres; Godot Text Resource File", "*.res; Godot Resource File"])
	var file_path = await %DialogManager.file_dialog.file_selected
	_load(file_path)

func set_project(new_project):
	project = new_project
	project_changed.emit(project)
