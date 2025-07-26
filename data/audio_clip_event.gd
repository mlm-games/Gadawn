# An event representing an audio sample.
class_name AudioClipEvent
extends TrackEvent

func _init():
	add_component("time", TimeComponent.new())
	add_component("properties", AudioClipPropertiesComponent.new())
	add_component("fade", FadeComponent.new())
