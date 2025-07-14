extends ConfirmationDialog

signal new_project(project)


func _ready():
	%ProjectType.add_item("GUI", Project.PROJECT_TYPE.GUI)
	%ProjectType.add_item("SongScript", Project.PROJECT_TYPE.SONGSCRIPT)

func _confirmed():
	new_project.emit(Project.new(%ProjectName.text, %ProjectType.selected))
