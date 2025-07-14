#NOTE: validates a song script.

class_name SongValidator
extends Node

const SONG_PATH = "user://song_to_validate.gd"

signal validation_succeeded(sequence: SongSequence)
signal validation_failed(error_message: String)

# Validates the given script text.
func validate_script(script_text: String):
	# Step 1: Basic syntax validation
	var syntax_error = _check_syntax(script_text)
	if syntax_error:
		validation_failed.emit(syntax_error)
		return
	
	# Step 2: Write the script to a temporary file
	var file = FileAccess.open(SONG_PATH, FileAccess.WRITE)
	if not file:
		validation_failed.emit("Internal Error: Could not write temp script file.")
		return
	
	file.store_string(script_text)
	file.close()
	
	# Step 3: Try to load and validate the script
	_validate_script_file()

func _check_syntax(script_text: String) -> String:
	# Basic syntax checks
	if not script_text.strip_edges():
		return "Script is empty"
	
	if not "extends SongScript" in script_text:
		return "Script must extend SongScript"
	
	if not "func song():" in script_text:
		return "Script must have a 'song()' method"
	
	# Check for basic syntax errors
	var lines = script_text.split("\n")
	var _indent_stack = []
	var line_num = 0
	
	for line in lines:
		line_num += 1
		var stripped = line.strip_edges()
		
		# Skip empty lines and comments
		if stripped.is_empty() or stripped.begins_with("#"):
			continue
		
		# Check indentation
		var indent_level = 0
		for chr in line:
			if chr == "\t":
				indent_level += 1
			elif chr == " ":
				indent_level += 0.25  # 4 spaces = 1 tab
			else:
				break
		
		# Check for unclosed parentheses/brackets
		var open_parens = line.count("(") - line.count(")")
		var open_brackets = line.count("[") - line.count("]")
		var open_braces = line.count("{") - line.count("}")
		
		if open_parens != 0 or open_brackets != 0 or open_braces != 0:
			# Allow for multi-line expressions
			var next_line_idx = line_num
			var total_open = open_parens + open_brackets + open_braces
			
			while next_line_idx < lines.size() and total_open > 0:
				var next_line = lines[next_line_idx]
				total_open += next_line.count("(") - next_line.count(")")
				total_open += next_line.count("[") - next_line.count("]")
				total_open += next_line.count("{") - next_line.count("}")
				next_line_idx += 1
			
			if total_open != 0:
				return "Unclosed parentheses, brackets, or braces near line %d" % line_num
	
	return ""

func _validate_script_file():
	# Use a thread to avoid blocking the main thread
	var thread = Thread.new()
	thread.start(_load_and_validate_script)

func _load_and_validate_script():
	# Small delay to ensure file is written
	OS.delay_msec(10)
	
	# Try to load the script
	var script = load(SONG_PATH)
	if not script:
		validation_failed.emit("Failed to load script. Check for syntax errors.")
		return
	
	# Try to instantiate it
	var instance = script.new()
	if not instance:
		validation_failed.emit("Failed to create script instance.")
		return
	
	# Check if it's a SongScript
	if not instance is SongScript:
		validation_failed.emit("Script must extend SongScript.")
		return
	
	# Check for song() method
	if not instance.has_method("song"):
		validation_failed.emit("Script must have a 'song()' method.")
		return
	
	# Try to execute the song() method
	var error_msg = ""
	
	# Set up error handling
	instance.set_meta("_validation_error", "")
	
	# Override the track() method to catch errors
	var original_track = instance.track
	instance.track = func(instrument: String, notes: Array):
		if not GoDawn.instruments.has(instrument):
			instance.set_meta("_validation_error", "Unknown instrument: " + instrument)
			return
		original_track.call(instrument, notes)
	
	# Execute the song
	instance.song()
	
	# Check for errors
	error_msg = instance.get_meta("_validation_error", "")
	if error_msg:
		validation_failed.emit(error_msg)
		return
	
	# Check if any tracks were added
	if instance.sequence.tracks.is_empty():
		validation_failed.emit("No tracks were added. Use track() to add tracks.")
		return
	
	# Validation successful
	validation_succeeded.emit(instance.sequence)
