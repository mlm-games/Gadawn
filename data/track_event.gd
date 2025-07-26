# This is the base class for anything that can be placed on the timeline.
# It only contains the data that is common to all event types. Also known as cue above
class_name TrackEvent
extends Resource

# The position of the event on the timeline, in seconds.
@export var start_time_sec: float = 0.0
