extends Node

@onready var script_editor : TextEdit = get_parent()

func _ready():
	var highlighter = CodeHighlighter.new()
	
	highlighter.number_color = Color("f9c74f")
	highlighter.symbol_color = Color("f8961e")
	highlighter.function_color = Color("90be6d")
	highlighter.member_variable_color = Color("43aa8b")
	
	var keywords = {
		"extends": Color("e8a2af"),
		"func": Color("e8a2af"),
		"@onready": Color("e8a2af"),
		"var": Color("e8a2af"),
		"const": Color("e8a2af"),
		"pass": Color("e8a2af"),
		"SongScript": Color("fae3b0")
	}
	
	for keyword in keywords:
		highlighter.add_keyword_color(keyword, keywords[keyword])
	
	highlighter.add_color_region('"', '"', Color("abe9b3"))
	highlighter.add_color_region("'", "'", Color("abe9b3"))
	highlighter.add_color_region("#", "", Color("6e6c7e"), true)
	
	script_editor.syntax_highlighter = highlighter
