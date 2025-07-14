extends PanelContainer

func _ready():
	CurrentProject.project_changed.connect(on_project_changed)

func on_project_changed(project: Project):
	set_project_name(project.project_name)
	set_status("Ready")

func set_status(text: String, type: String = "info"):
	%StatusLabel.text = text
	match type:
		"error":
			%StatusLabel.modulate = Color.RED
		"warning":
			%StatusLabel.modulate = Color.YELLOW
		"success":
			%StatusLabel.modulate = Color.LIGHT_GREEN
		_:
			%StatusLabel.modulate = Color.WHITE

func set_error_status(text: String):
	set_status(text, "error")

func set_project_name(p_name: String):
	%ProjectLabel.text = "Project: " + p_name
