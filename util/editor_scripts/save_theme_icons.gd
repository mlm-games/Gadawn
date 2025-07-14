@tool
extends EditorScript

func _run():
	var theme: Theme = load("res://themes/default/go_dawn_theme.tres")
	var node_type = "VSplitContainer"

	var icons = theme.get_icon_list(node_type)
	for icon in icons:
		var tex: Image = theme.get_icon(icon, node_type).get_image()
		tex.save_png("res://themes/default/button_icons/%s.png" % icon)
