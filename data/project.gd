# This is the root data resource for a project. It's what gets saved to a .tres file.
# It holds an array of tracks and global project settings.
class_name Project
extends Resource

@export var tracks: Array[TrackData] = []
@export var project_name: String = "Untitled Project"
@export var bpm: int = 120
@export var saved: bool = false

# UI-related data that's useful to save with the project
@export var view_zoom: float = 50.0 # pixels per second
@export var view_scroll_sec: float = 0.0

func _init(p_name: String = "Untitled Project"):
	project_name = p_name
