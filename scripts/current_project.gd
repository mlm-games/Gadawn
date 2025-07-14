extends Node #SOT

var project: Project:
	set(new_project):
		if project == new_project:
			return
		project = new_project
		project_changed.emit(project)

signal project_changed(project)
