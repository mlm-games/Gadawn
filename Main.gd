extends Control

@onready var dialog_manager: Control = $DialogManager
@onready var song_editor: Node = $Application/Main/SongEditor
@onready var sequencer: Node = $Application/Main/SongEditor/Sequencer
@onready var instrument_panel: VBoxContainer = $Application/InstrumentsPanel

var project: Project

signal project_changed(project)

func _on_top_menu_export_pressed():
	dialog_manager.file("Export", FileDialog.FILE_MODE_SAVE_FILE, ["*.wav ; Wav Files"])
	var file_path = await dialog_manager.file_dialog.file_selected
	song_editor.sequence()
	var recorder = AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, recorder, AudioServer.get_bus_effect_count(0))
	
	var progress = dialog_manager.progress("Exporting...")
	progress.max_value = 100
	sequencer.on_note.connect(progress.set_value)
	
	recorder.set_recording_active(true)
	sequencer.play()
	await sequencer.playback_finished
	recorder.set_recording_active(false)

	# Save recording
	var recording = recorder.get_recording()
	recording.save_to_wav(file_path)
	dialog_manager.hide_progress()

func _save(file_path):
	project.song_script = song_editor.song_script_editor.text
	ResourceSaver.save(project, file_path)

func _load(file_path):
	set_project(ResourceLoader.load(file_path))

func _on_top_menu_save_pressed():
	if project.saved:
		_save(project.resource_path)
	else: 
		_on_top_menu_save_as_pressed()

func _on_top_menu_save_as_pressed():
	dialog_manager.file("Save", FileDialog.FILE_MODE_SAVE_FILE, ["*.tres; Godot Text Resource File", "*.res; Godot Resource File"])
	project.saved = true
	var file_path = await dialog_manager.file_dialog.file_selected
	_save(file_path)

func _on_top_menu_open_pressed():
	dialog_manager.file("Open", FileDialog.FILE_MODE_OPEN_FILE, ["*.tres; Godot Text Resource File", "*.res; Godot Resource File"])
	var file_path = await dialog_manager.file_dialog.file_selected
	_load(file_path)

func _ready():
	# Editor Setup
	
	# Set Font
	#var font : FontFile = get_theme().default_font
	#instrument_panel.title.get_theme_font("font", "Label").font_data = font.font_data
	
	# Load instruments
	var progress = dialog_manager.progress("Loading...")
	GoDAW.loading_progress_max_value_changed.connect(progress.set_max)
	GoDAW.loading_progress_value_changed.connect(progress.set_value.bind(progress.value+1))
	GoDAW.loading_instrument_changed.connect(dialog_manager.progress_label.set_text)
	await GoDAW.load_instruments()
	dialog_manager.hide_progress()
	instrument_panel.reload_instruments()

	# Clear song history
	var dir = DirAccess.open("user://")
	if dir.file_exists("song.gd"):
		dir.remove("song.gd")

	# Project setup
	set_project(Project.new())

func set_project(new_project):
	project = new_project
	project_changed.emit(project)
