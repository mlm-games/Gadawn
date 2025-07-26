# This is the base class for anything that can be placed on the timeline.
# It only contains the data that is common to all event types. Also known as cue above
class_name TrackEvent
extends Resource

@export var components: Dictionary = {} # String (name) -> EventComponent

func get_time_component() -> TimeComponent:
	return components.get("time")

func add_component(name: String, component: EventComponent):
	components[name] = component

func get_component(name: String) -> EventComponent:
	return components.get(name)

func has_component(name: String) -> bool:
	return components.has(name)

func _duplicate(for_local: bool = false) -> Resource:
	var new_event = super.duplicate(for_local)
	new_event.components = {}
	for key in components:
		new_event.components[key] = (components[key] as EventComponent).duplicate_component()
	return new_event
