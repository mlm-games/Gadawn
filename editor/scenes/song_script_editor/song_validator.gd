#NOTE: validates a song script.

class_name SongValidator
extends Node

const SONG_PATH = "user://song_to_validate.gd"

signal validation_succeeded(sequence: SongSequence)
signal validation_failed(error_message: String)

# Validates the given script text.
func validate_script(script_text: String):
	# Step 1: Write the script to a temporary file.
	var file = FileAccess.open(SONG_PATH, FileAccess.WRITE)
	if not file:
		validation_failed.emit("Internal Error: Could not write temp script file.")
		return
	
	file.store_string(script_text)
	file.close()

	# Step 2: Attempt to load the script resource.
	var script_resource = ResourceLoader.load(SONG_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not script_resource:
		# This is a critical syntax error that prevents loading.
		# Unfortunately, Godot doesn't give us the specific error line here.
		validation_failed.emit("Syntax Error: Script could not be parsed. Check for typos or structural errors.")
		return
	
	# Step 3: Instantiate the script and check for the `song()` method.
	var instance = script_resource.new()
	if not instance.has_method("song"):
		validation_failed.emit("Validation Error: Script must have a 'song()' method.")
		return

	# Step 4: Execute the song() method to build the sequence.
	# The SongScript base class handles the track() and note() calls.
	instance.song()
	
	# Step 5: Validation successful. Emit the resulting sequence.
	validation_succeeded.emit(instance.sequence)
