extends PanelContainer

signal delete_requested

@onready var key_spinbox: SpinBox = %KeySpinBox
@onready var duration_spinbox: SpinBox = %DurationSpinBox
@onready var start_delta_spinbox: SpinBox = %StartDeltaSpinBox
@onready var delete_button: Button = %DeleteButton
@onready var note_label: Label = %NoteLabel

var note_names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

func _ready():
	delete_button.pressed.connect(func(): delete_requested.emit())
	key_spinbox.value_changed.connect(_on_key_changed)
	_on_key_changed(key_spinbox.value)

func _on_key_changed(value: float):
	var octave = int(value) / 12 - 1
	var note_index = int(value) % 12
	note_label.text = "%s%d" % [note_names[note_index], octave]

func set_note_data(note: Note):
	if note.instrument_data is Dictionary and note.instrument_data.has("key"):
		key_spinbox.value = note.instrument_data.key
	start_delta_spinbox.value = note.note_start_delta
	duration_spinbox.value = note.duration

func get_note_data() -> Note:
	var note = Note.new()
	note.instrument_data = {"key": int(key_spinbox.value)}
	note.note_start_delta = start_delta_spinbox.value
	note.duration = duration_spinbox.value
	return note
