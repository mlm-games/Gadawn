class_name SongEditor extends VBoxContainer

signal validation_requested_for_export

@onready var song_script_editor: CodeEdit = %SongScriptEditor
@onready var tracks_scroll_container: ScrollContainer = %TracksScroll
@onready var track_names_container: VBoxContainer = %Names
@onready var instrument_container: Node = %InstrumentContainer
@onready var sequencer: Sequencer = %Sequencer
@onready var track_name_scene = preload("./track_name.tscn")

const BASE_SONG_SCRIPT = """extends SongScript

func song():
	track("square", [
		# Place your notes here (start_delay, duration, {data})
		note(0.0, 0.5, {"key": 60}),  # Middle C
		note(0.5, 0.5, {"key": 62}),  # D
		note(1.0, 0.5, {"key": 64}),  # E
	])
"""

func _on_play_pressed():
	Main.instance.status_bar.set_status("Validating...")
	Main.instance.song_validator.validate_script(song_script_editor.text)

func _on_validation_succeeded(song_sequence: SongSequence):
	Main.instance.status_bar.set_status("Ready", "success")
	
	_reconcile_instruments(song_sequence)
	sequencer.sequence(song_sequence)
	sequencer.play()

func _reconcile_instruments(song_sequence: SongSequence):
	for child in instrument_container.get_children():
		child.queue_free()
	sequencer.INSTRUMENTS.clear()
	
	for track in song_sequence.tracks:
		var inst = GoDawn.get_instrument(track.instrument)
		if inst:
			sequencer.INSTRUMENTS[track.instrument] = inst
			instrument_container.add_child(inst)

func on_project_changed(project: Project):
	var is_gui_mode = project.project_type == Project.PROJECT_TYPE.GUI
	song_script_editor.visible = not is_gui_mode
	tracks_scroll_container.visible = is_gui_mode
	
	for n in track_names_container.get_children():
		n.queue_free()
	
	if project.song_script and not project.song_script.is_empty():
		song_script_editor.text = project.song_script
	else:
		song_script_editor.text = BASE_SONG_SCRIPT

func add_track(instrument: Button):
	if CurrentProject.project.project_type == Project.PROJECT_TYPE.SONGSCRIPT:
		var indent = "\t"
		var new_track = '\n%strack("%s", [\n' % [indent, instrument.text]
		new_track += indent + "\t# Add notes here\n"
		new_track += indent + '])'
		song_script_editor.insert_text_at_caret(new_track)

func get_script_text() -> String:
	return song_script_editor.text

func request_validation_for_export():
	validation_requested_for_export.emit()
