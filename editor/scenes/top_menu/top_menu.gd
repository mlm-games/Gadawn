extends HBoxContainer

signal new_pressed()
signal open_pressed()
signal save_pressed()
signal save_as_pressed()
signal export_pressed()
signal quit_pressed()

@onready var menus: Dictionary[StringName, Dictionary] = {
	"Song": {
		"node": $SongMenu,
		"elements": {
			"New": new_pressed,
			"Open": open_pressed,
			"Save": save_pressed,
			"Save as...": save_as_pressed,
			"Export": export_pressed,
			"Separator": "",
			"Quit": quit_pressed,
		}
	},
	"Edit": { "node": $EditMenu, "elements": {} },
	"View": { "node": $ViewMenu, "elements": {} },
	"Help": { "node": $HelpMenu, "elements": {} }
}

func _ready():
	for menu_name in menus:
		var menu_data = menus[menu_name]
		var menu_node = menu_data.node
		init_menu(menu_node, menu_data.elements)
		menu_node.get_popup().id_pressed.connect(_on_item_pressed.bind(menu_name))
	
	CurrentProject.project_changed.connect(on_project_changed)

func on_project_changed(project: Project):
	$ProjectName.text = project.project_name

func _on_item_pressed(id: int, menu: String):
	var menu_dict = menus[menu]
	var node = menu_dict.node
	var item_name = node.get_popup().get_item_text(id)
	var signal_to_emit: Signal = menu_dict["elements"][item_name]
	
	if signal_to_emit.get_name() != "":
		signal_to_emit.emit()

func init_menu(menu, items):
	for e in items:
		if e == "Separator":
			menu.get_popup().add_separator()
		else:
			menu.get_popup().add_item(e)

func _quit():
	get_tree().quit()
