extends PanelContainer
class_name StatusBar


func set_status(text: String, type: String = "info"):
	%StatusLabel.text = text
	match type:
		"error":
			%StatusLabel.modulate = Color.RED
		"warning":
			%StatusLabel.modulate = Color.YELLOW
		"success":
			%StatusLabel.modulate = Color.GREEN
		_:
			%StatusLabel.modulate = Color.WHITE

func set_project_name(name: String):
	%ProjectLabel.text = "Project: " + name
