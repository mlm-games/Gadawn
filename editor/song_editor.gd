class_name SongEditor
extends VBoxContainer

@onready var top_bar: TopBar = %TopBar
@onready var library_panel: LibraryPanel = %LibraryPanel
@onready var timeline_ui: TimelineUI = %TimelineUI
@onready var transport_bar: TransportBar = %TransportBar

# Called by Main when the project data changes.
func on_project_changed(project: Project) -> void:
	top_bar.set_project_name(project.project_name)
	timeline_ui.set_project(project)
