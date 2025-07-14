extends Window

signal track_updated(track_data)

@onready var instrument_label: Label = %InstrumentLabel
@onready var notes_container: VBoxContainer = %NotesContainer
@onready var add_note_button: Button = %AddNoteButton

var current_track: Track
var current_instrument: String
var note_editors: Array = []

func _ready():
	add_note_button.pressed.connect(_on_add_note_pressed)
	close_requested.connect(hide)

func edit_track(instrument_name: String, track: Track = null):
	current_instrument = instrument_name
	instrument_label.text = "Instrument: " + instrument_name
	
	# Clear existing note editors
	for editor in note_editors:
		editor.queue_free()
	note_editors.clear()
	
	if track:
		current_track = track
		# Load existing notes
		for note in track.notes:
			_add_note_editor(note)
	else:
		current_track = Track.new()
		current_track.instrument = instrument_name
		# Add one empty note editor
		_add_note_editor()
	
	popup_centered(Vector2(600, 400))

func _add_note_editor(note: Note = null):
	var note_editor = preload("res://editor/scenes/dialogues/track_editor/note_editor.tscn").instantiate()
	notes_container.add_child(note_editor)
	note_editors.append(note_editor)
	
	if note:
		note_editor.set_note_data(note)
	
	note_editor.delete_requested.connect(_on_note_delete_requested.bind(note_editor))

func _on_add_note_pressed():
	_add_note_editor()

func _on_note_delete_requested(note_editor):
	if note_editors.size() > 1:  # Keep at least one note editor
		note_editors.erase(note_editor)
		note_editor.queue_free()

func _on_confirm_pressed():
	# Collect all notes from editors
	current_track.notes.clear()
	
	for editor in note_editors:
		var note_data = editor.get_note_data()
		if note_data:  # Only add valid notes
			current_track.notes.append(note_data)
	
	track_updated.emit(current_track)
	hide()
