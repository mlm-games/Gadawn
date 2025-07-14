class_name SongEditor extends VBoxContainer

signal validation_requested_for_export

@onready var song_script_editor: CodeEdit = %SongScriptEditor
@onready var tracks_scroll_container: ScrollContainer = %TracksScroll
@onready var track_names_container: VBoxContainer = %Names
@onready var tracks_container: VBoxContainer = %TracksContainer
@onready var instrument_container: Node = %InstrumentContainer
@onready var sequencer: Sequencer = %Sequencer
@onready var track_name_scene = preload("./track_name.tscn")
@onready var track_editor_dialog = preload("res://editor/scenes/dialogues/track_editor/track_editor.tscn").instantiate()

const BASE_SONG_SCRIPT = """extends SongScript

func song():
	track("square", [
		# Place your notes here (start_delay, duration, {data})
		note(0.0, 0.5, {"key": 60}),  # Middle C
		note(0.5, 0.5, {"key": 62}),  # D
		note(1.0, 0.5, {"key": 64}),  # E
	])
"""

var gui_tracks: Dictionary = {}  # instrument_name -> Track

func _ready():
	add_child(track_editor_dialog)
	track_editor_dialog.track_updated.connect(_on_track_updated)

func _on_play_pressed():
	if CurrentProject.project.project_type == Project.PROJECT_TYPE.GUI:
		_validate_gui_mode()
	else:
		Main.instance.status_bar.set_status("Validating...")
		Main.instance.song_validator.validate_script(song_script_editor.text)

func _validate_gui_mode():
	# Create a SongSequence from GUI tracks
	var sequence = SongSequence.new()
	
	for instrument_name in gui_tracks:
		var track = gui_tracks[instrument_name]
		if track.notes.size() > 0:
			sequence.add_track(track)
	
	if sequence.tracks.is_empty():
		Main.instance.status_bar.set_error_status("No tracks with notes")
		return
	
	Main.instance.status_bar.set_status("Ready", "success")
	_on_validation_succeeded(sequence)

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
	
	# Clear existing tracks
	for n in track_names_container.get_children():
		n.queue_free()
	for n in tracks_container.get_children():
		n.queue_free()
	gui_tracks.clear()
	
	if is_gui_mode:
		# Load GUI tracks if any
		if project.song_sequence and project.song_sequence.tracks.size() > 0:
			for track in project.song_sequence.tracks:
				_add_gui_track(track.instrument, track)
	else:
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
	else:
		_add_gui_track(instrument.text)

func _add_gui_track(instrument_name: String, track: Track = null):
	# Create track name button
	var track_name = track_name_scene.instantiate()
	track_names_container.add_child(track_name)
	
	# Set up the track name
	var icon = null
	var dir = DirAccess.open("res://instruments")
	if dir and dir.file_exists("./%s/icon.png" % instrument_name):
		icon = load("res://instruments/%s/icon.png" % instrument_name)
	else:
		icon = load("res://themes/default/images/default_icon.png")
	
	track_name.set_instrument(icon, instrument_name)
	track_name.pressed.connect(_on_track_name_pressed.bind(instrument_name))
	track_name.delete_requested.connect(_on_track_delete_requested.bind(instrument_name, track_name))
	
	# Create visual track representation
	var track_visual = PanelContainer.new()
	track_visual.custom_minimum_size = Vector2(0, 48)
	track_visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tracks_container.add_child(track_visual)
	
	# Store or create track data
	if track:
		gui_tracks[instrument_name] = track
	else:
		var new_track = Track.new()
		new_track.instrument = instrument_name
		gui_tracks[instrument_name] = new_track
	
	# Update visual representation
	_update_track_visual(instrument_name, track_visual)

func _on_track_name_pressed(instrument_name: String):
	var track = gui_tracks.get(instrument_name)
	track_editor_dialog.edit_track(instrument_name, track)

func _on_track_delete_requested(instrument_name: String, track_name_node):
	# Remove from GUI
	track_name_node.queue_free()
	
	# Remove visual track
	var track_index = gui_tracks.keys().find(instrument_name)
	if track_index >= 0 and track_index < tracks_container.get_child_count():
		tracks_container.get_child(track_index).queue_free()
	
	# Remove from data
	gui_tracks.erase(instrument_name)

func _on_track_updated(track: Track):
	gui_tracks[track.instrument] = track
	
	# Update visual representation
	var track_index = gui_tracks.keys().find(track.instrument)
	if track_index >= 0 and track_index < tracks_container.get_child_count():
		_update_track_visual(track.instrument, tracks_container.get_child(track_index))

func _update_track_visual(instrument_name: String, track_visual: PanelContainer):
	# Clear existing children
	for child in track_visual.get_children():
		child.queue_free()
	
	var track = gui_tracks.get(instrument_name)
	if not track or track.notes.is_empty():
		# Show empty track message
		var label = Label.new()
		label.text = "Click track name to add notes"
		label.modulate.a = 0.5
		track_visual.add_child(label)
		return
	
	# Create a simple visual representation of notes
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 2)
	track_visual.add_child(hbox)
	
	# Calculate total duration for scaling
	var total_duration = 0.0
	for note in track.notes:
		total_duration = max(total_duration, note.note_start_delta + note.duration)
	
	if total_duration == 0:
		total_duration = 1.0
	
	# Add visual notes
	for note in track.notes:
		# Add spacing for start delta
		if note.note_start_delta > 0:
			var spacer = Control.new()
			spacer.custom_minimum_size.x = (note.note_start_delta / total_duration) * 500
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hbox.add_child(spacer)
		
		# Add note visual
		var note_rect = ColorRect.new()
		note_rect.custom_minimum_size = Vector2((note.duration / total_duration) * 500, 40)
		note_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		note_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		# Color based on pitch
		if note.instrument_data is Dictionary and note.instrument_data.has("key"):
			var hue = float(note.instrument_data.key % 12) / 12.0
			note_rect.color = Color.from_hsv(hue, 0.7, 0.8)
		else:
			note_rect.color = Color(0.5, 0.7, 0.9)
		
		# Add note info as tooltip
		if note.instrument_data is Dictionary and note.instrument_data.has("key"):
			var note_names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
			var key = note.instrument_data.key
			var octave = int(key) / 12 - 1
			var note_index = int(key) % 12
			note_rect.tooltip_text = "%s%d (%.1fs)" % [note_names[note_index], octave, note.duration]
		
		hbox.add_child(note_rect)

func get_script_text() -> String:
	return song_script_editor.text

func request_validation_for_export():
	if CurrentProject.project.project_type == Project.PROJECT_TYPE.GUI:
		# For GUI mode, build sequence and emit signal
		var sequence = SongSequence.new()
		for instrument_name in gui_tracks:
			var track = gui_tracks[instrument_name]
			if track.notes.size() > 0:
				sequence.add_track(track)
		
		if sequence.tracks.is_empty():
			Main.instance._on_validation_failed_for_export("No tracks with notes")
		else:
			Main.instance._on_validation_succeeded_for_export(sequence)
	else:
		validation_requested_for_export.emit()
