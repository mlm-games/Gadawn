extends VBoxContainer

# Signals
signal playback_finished()
signal start_loading()
signal stop_loading()
signal done_error_handling()
signal done_error_check(error)
signal song_script_error(error)
signal track_pressed(name)
signal sequence_complete()

@onready var SCRIPT_LOCATION = OS.get_user_data_dir() + "/song.gd"
@onready var sequencer: Sequencer = %Sequencer
@onready var song_script_editor: CodeEdit = %SongScriptEditor

var ERROR_REGEX = RegEx.new()
const SONG_PATH = "user://song.gd"

const BASE_SONG_SCRIPT = """extends SongScript

func song():
	track("%s", [
		# Place your notes here
		note(0.0, 0.5, {"key": 60}),  # Middle C
		note(0.5, 0.5, {"key": 62}),  # D
		note(1.0, 0.5, {"key": 64}),  # E
	])
"""

var gui: bool = true
var track_name = preload("./TrackName.tscn")
var error_text = ""
var in_file = ""

func _ready():
	ERROR_REGEX.compile("SCRIPT ERROR: (.*?)\\n(?:.*?):([0-9]+)")
	done_error_check.connect(_after_error_check)
	done_error_handling.connect(_on_sequence_complete)

func add_track(instrument: Button):
	if !gui: return
	var name_button: Button = track_name.instantiate()
	name_button.set_instrument(instrument.icon, instrument.text)
	%Names.add_child(name_button)
	name_button.pressed.connect(func(): track_pressed.emit(instrument.text))
	
	# Add instrument to sequencer
	var inst := GoDAW.get_instrument(instrument.text)
	if inst:
		$Sequencer.INSTRUMENTS[instrument.text] = inst
		%InstrumentContainer.add_child(inst)

func check_error():
	# Save script to file
	var file = FileAccess.open(SONG_PATH, FileAccess.WRITE)
	if file:
		file.store_string(%SongScriptEditor.text)
		file.close()
	else:
		done_error_check.emit("Failed to save script file")
		return
	
	# Try to load and validate the script
	var script = load(SONG_PATH)
	if not script:
		done_error_check.emit("Failed to load script")
		return
	
	var instance = script.new()
	if not instance.has_method("song"):
		done_error_check.emit("Script has no song() method")
		return
	
	done_error_check.emit("")

func _after_error_check(error):
	stop_loading.emit()
	error_text = error
	if error:
		song_script_error.emit(error_text)
		return false

	error_text = ""
	var song: SongScript = load(SONG_PATH).new()
	song.sequence.tracks.clear()
	song.song()
	
	# Update instruments if needed
	if song.sequence.tracks.size() != %InstrumentContainer.get_child_count():
		%Sequencer.INSTRUMENTS.clear()
		for instrument in %InstrumentContainer.get_children():
			instrument.queue_free()
		for track in song.sequence.tracks:
			var inst = GoDAW.get_instrument(track.instrument)
			if inst:
				%Sequencer.INSTRUMENTS[track.instrument] = inst
				%InstrumentContainer.add_child(inst)
	
	%Sequencer.sequence(song.sequence)
	done_error_handling.emit()

func _on_sequence_complete():
	sequence_complete.emit()

func sequence():
	if !gui:
		start_loading.emit()
		if in_file != %SongScriptEditor.text:
			in_file = %SongScriptEditor.text
			check_error()
			await sequence_complete
		else:
			done_error_handling.emit()
			await sequence_complete

func _on_play():
	await sequence()
	%Sequencer.play()

func _on_pause():
	%Sequencer.pause()

func _on_stop():
	%Sequencer.stop()

func _on_Sequencer_playback_finished():
	playback_finished.emit()

func project_changed(project: Project):
	gui = true if project.project_type == Project.PROJECT_TYPE.GUI else false
	%SongScriptEditor.visible = !gui
	%TracksScroll.visible = gui
	
	# Clear existing tracks
	for n in %Names.get_children():
		n.queue_free()
	
	if project.song_script:
		%SongScriptEditor.text = project.song_script
	else:
		%SongScriptEditor.text = BASE_SONG_SCRIPT % "Square"
