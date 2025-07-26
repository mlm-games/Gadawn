# An event representing a single musical note, to be used in a Piano Roll.
class_name NoteEvent
extends TrackEvent

func _init():
	add_component("time", TimeComponent.new())
	add_component("pitch", NotePitchComponent.new())
	add_component("velocity", NoteVelocityComponent.new())
