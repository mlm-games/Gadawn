extends Resource

class_name SongScript

var sequence: SongSequence

func _init():
	sequence = SongSequence.new()

func track(instrument: String, notes: Array):
	var track = Track.new()
	track.instrument = instrument
	# Convenient for nested patterns
	track.notes = pattern(notes)

	sequence.add_track(track)

func pattern(notes: Array, repeat: int = 1, start_delta: float = 0.0) -> Array:
	if notes.is_empty(): return []
	var expanded = []
	
	for _i in repeat:
		var pattern_start_time = 0.0
		for el in notes:
			if el is Note:
				# Create a copy of the note with adjusted timing
				var new_note = Note.new()
				new_note.note_start_delta = el.note_start_delta + start_delta
				new_note.duration = el.duration
				new_note.instrument_data = el.instrument_data
				expanded.append(new_note)
				pattern_start_time += el.note_start_delta + el.duration
			elif el is Array:
				# Recursively process nested patterns with proper offset
				var nested = pattern(el, 1, start_delta + pattern_start_time)
				expanded.append_array(nested)
				# Calculate the total duration of the nested pattern
				for n in nested:
					if n is Note:
						pattern_start_time += n.note_start_delta + n.duration

	return expanded

func note(note_start_delta: float, duration: float, data) -> Note:
	var note = Note.new()
	note.note_start_delta = note_start_delta
	note.duration = duration
	note.instrument_data = data
	return note

# The function where notes go
func song():
	pass
