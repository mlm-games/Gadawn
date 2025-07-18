## A resource that holds data parsed from a Standard MIDI File (.mid).
## It can read the file format and convert it into a Godawn Project resource.
class_name MidiFile
extends Resource

#region MIDI Data Structures
# Internal classes to store the raw parsed MIDI data before conversion.

class MidiEvent:
	## Represents a single event in a MIDI track's event stream.
	enum Type { NOTE_OFF, NOTE_ON, OTHER }
	var type: Type
	var key: int
	var velocity: int
	var delta_tick: int # Time since the previous event in this track.

	func _init(p_type: Type, p_key: int = 0, p_velocity: int = 0, p_delta: int = 0):
		type = p_type
		key = p_key
		velocity = p_velocity
		delta_tick = p_delta

class MidiNote:
	## Represents a complete musical note with a start time and duration.
	var key: int
	var velocity: int
	var start_tick: int # Absolute start time in ticks from the beginning.
	var duration_tick: int

	func _init(p_key: int = 0, p_velocity: int = 0, p_start: int = 0, p_duration: int = 0):
		key = p_key
		velocity = p_velocity
		start_tick = p_start
		duration_tick = p_duration

class MidiTrack:
	## Represents a single track from the MIDI file.
	var name: String = "MIDI Track"
	var instrument: String = ""
	var events: Array[MidiEvent] = []
	var notes: Array[MidiNote] = []
	var max_note: int = -1
	var min_note: int = 128

#endregion

#region MIDI Constants
# Enums for MIDI status bytes and meta-event types.

enum EventName {
	VoiceNoteOff = 0x80,
	VoiceNoteOn = 0x90,
	VoiceAftertouch = 0xA0,
	VoiceControlChange = 0xB0,
	VoiceProgramChange = 0xC0,
	VoiceChannelPressure = 0xD0,
	VoicePitchBend = 0xE0,
	SystemExclusive = 0xF0,
}

enum MetaEventName {
	MetaSequence = 0x00,
	MetaText = 0x01,
	MetaCopyright = 0x02,
	MetaTrackName = 0x03,
	MetaInstrumentName = 0x04,
	MetaLyrics = 0x05,
	MetaMarker = 0x06,
	MetaCuePoint = 0x07,
	MetaChannelPrefix = 0x20,
	MetaEndOfTrack = 0x2F,
	MetaSetTempo = 0x51,
	MetaSMPTEOffset = 0x54,
	MetaTimesSignature = 0x58,
	MetaKeySignature = 0x59,
	MetaSequencerSpecific = 0x7F,
}
#endregion

## Parsed MIDI properties.
var tracks: Array[MidiTrack] = []
@export var tempo: int = 500000 # Microseconds per quarter note, default 120bpm
@export var bpm: float = 120.0
@export var ppq: int = 480 # Pulses (ticks) per quarter note

## Parses a MIDI file from the given path and populates this resource.
## Returns true on success, false on failure.
func parse_file(path: String) -> bool:
	var file = FileAccess.open(path, FileAccess.READ)
	if not FileAccess.file_exists(path) or file == null:
		push_error("MidiFile: Error opening file at path: %s" % path)
		return false

	file.big_endian = true
	
	# --- Parse Header Chunk ---
	var header_id = file.get_32()
	var header_length = file.get_32()
	var format = file.get_16()
	var track_count = file.get_16()
	var division = file.get_16()
	
	if header_id != 0x4D546864: # "MThd"
		push_error("MidiFile: Invalid file format. Missing 'MThd' header.")
		file.close()
		return false

	# If MSB is 0, division is ticks per quarter note (PPQ).
	if not (division & 0x8000):
		ppq = division
	else:
		# If MSB is 1, it's SMTPE format, which is not fully supported here.
		push_warning("MidiFile: SMTPE time division format not fully supported.")
		var frames_per_sec = (division >> 8) & 0x7F
		var ticks_per_frame = division & 0xFF
		ppq = ticks_per_frame * frames_per_sec # Approximate PPQ for tempo calculation

	# --- Parse Track Chunks ---
	for i in range(track_count):
		if not _parse_track(file):
			push_error("MidiFile: Failed to parse track %d." % (i + 1))
			file.close()
			return false
	
	file.close()
	_process_events_to_notes()
	
	return true

## Converts the parsed MIDI data into a Godawn Project resource.
func to_project() -> Project:
	var project = Project.new()
	project.bpm = int(self.bpm)
	
	var seconds_per_tick = 60.0 / (bpm * float(ppq))

	for midi_track in tracks:
		if midi_track.notes.is_empty():
			continue

		var track_data = TrackData.new()
		track_data.track_type = TrackData.TrackType.INSTRUMENT
		track_data.track_name = midi_track.name
		# In a real app, you might map midi_track.instrument to a specific scene.
		# For now, we leave it for the user to assign.

		for midi_note in midi_track.notes:
			var note_event = NoteEvent.new()
			note_event.key = midi_note.key
			note_event.velocity = midi_note.velocity
			note_event.start_time_sec = midi_note.start_tick * seconds_per_tick
			note_event.duration_sec = midi_note.duration_tick * seconds_per_tick
			
			track_data.events.append(note_event)
			
		project.tracks.append(track_data)
		
	return project

#region Private Parsing Methods

## Parses a single track chunk from the file stream.
func _parse_track(file: FileAccess) -> bool:
	var track_id = file.get_32()
	var track_length = file.get_32()

	if track_id != 0x4D54726B: # "MTrk"
		push_error("MidiFile: Invalid track format. Missing 'MTrk' header.")
		return false
	
	var end_of_track_pos = file.get_position() + track_length
	var end_of_track_found = false
	var previous_status = 0
	
	var current_track = MidiTrack.new()
	tracks.append(current_track)

	while file.get_position() < end_of_track_pos and not end_of_track_found:
		var delta_tick = _read_variable_length_quantity(file)
		var status = file.get_8()
		
		# Handle "Running Status": if the MSB is not set, it's not a status byte.
		# Reuse the previous status byte and rewind the file by one byte.
		if status < 0x80:
			status = previous_status
			file.seek(file.get_position() - 1)
		
		match (status & 0xF0):
			EventName.VoiceNoteOff:
				previous_status = status
				var key = file.get_8()
				var velocity = file.get_8()
				current_track.events.append(MidiEvent.new(MidiEvent.Type.NOTE_OFF, key, velocity, delta_tick))

			EventName.VoiceNoteOn:
				previous_status = status
				var key = file.get_8()
				var velocity = file.get_8()
				# A NoteOn with velocity 0 is equivalent to a NoteOff.
				var type = MidiEvent.Type.NOTE_ON if velocity > 0 else MidiEvent.Type.NOTE_OFF
				current_track.events.append(MidiEvent.new(type, key, velocity, delta_tick))
			
			# These events are parsed but currently unused.
			EventName.VoiceAftertouch, EventName.VoiceControlChange, EventName.VoicePitchBend:
				previous_status = status
				file.seek(file.get_position() + 2) # Skip 2 data bytes
				current_track.events.append(MidiEvent.new(MidiEvent.Type.OTHER))
			EventName.VoiceProgramChange, EventName.VoiceChannelPressure:
				previous_status = status
				file.seek(file.get_position() + 1) # Skip 1 data byte
				current_track.events.append(MidiEvent.new(MidiEvent.Type.OTHER))

			EventName.SystemExclusive:
				previous_status = 0 # System events do not affect running status.
				if status == 0xFF: # Meta Event
					end_of_track_found = _parse_meta_event(file, current_track)
				elif status == 0xF0 or status == 0xF7: # Sysex
					var length = _read_variable_length_quantity(file)
					file.seek(file.get_position() + length) # Skip sysex data
				else:
					push_warning("MidiFile: Unrecognized System Exclusive status: 0x%X" % status)
			_:
				push_warning("MidiFile: Unrecognized event status: 0x%X" % status)
				return false # Bail out on unknown event
				
	return true

## Parses a meta event. Returns true if it's the "End of Track" event.
func _parse_meta_event(file: FileAccess, track: MidiTrack) -> bool:
	var type = file.get_8()
	var length = _read_variable_length_quantity(file)
	var end_pos = file.get_position() + length

	match type:
		MetaEventName.MetaEndOfTrack:
			return true
		MetaEventName.MetaTrackName:
			track.name = _read_string(file, length)
		MetaEventName.MetaInstrumentName:
			track.instrument = _read_string(file, length)
		MetaEventName.MetaSetTempo:
			if length == 3:
				tempo = (file.get_8() << 16) | (file.get_8() << 8) | file.get_8()
				bpm = 60000000.0 / tempo
		# Skipping other meta events for brevity.
		_:
			pass
	
	# Seek past the event data to continue parsing.
	file.seek(end_pos)
	return false

## Converts the raw event stream for each track into a list of concrete notes.
func _process_events_to_notes():
	for track in tracks:
		var absolute_tick = 0
		var notes_in_progress := {} # Dictionary of key -> MidiNote

		for event in track.events:
			absolute_tick += event.delta_tick
			
			if event.type == MidiEvent.Type.NOTE_ON:
				# Store a new note when a NoteOn event occurs.
				notes_in_progress[event.key] = MidiNote.new(event.key, event.velocity, absolute_tick)
			
			elif event.type == MidiEvent.Type.NOTE_OFF:
				if notes_in_progress.has(event.key):
					# Finalize the note when its corresponding NoteOff event is found.
					var started_note: MidiNote = notes_in_progress[event.key]
					started_note.duration_tick = absolute_tick - started_note.start_tick
					
					if started_note.duration_tick > 0:
						track.notes.append(started_note)
						
						# Update track's min/max note range.
						track.min_note = min(track.min_note, started_note.key)
						track.max_note = max(track.max_note, started_note.key)

					notes_in_progress.erase(event.key)

## Reads a variable-length quantity (VLQ) from the file stream.
func _read_variable_length_quantity(file: FileAccess) -> int:
	var value = 0
	var byte = file.get_8()
	value = byte & 0x7F # Mask out the MSB

	while byte & 0x80: # Continue while MSB is 1
		byte = file.get_8()
		value = (value << 7) | (byte & 0x7F)
		
	return value

## Reads n bytes from the file and constructs an ASCII string.
func _read_string(file: FileAccess, length: int) -> String:
	var bytes := PackedByteArray()
	bytes.resize(length)
	for i in range(length):
		bytes[i] = file.get_8()
	return bytes.get_string_from_ascii()
	
#endregion
