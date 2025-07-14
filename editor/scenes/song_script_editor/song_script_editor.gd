extends CodeEdit

func _ready():
	syntax_highlighter = CodeHighlighter.new()
	
	syntax_highlighter.number_color = Color("f9c74f")
	syntax_highlighter.symbol_color = Color("f8961e")
	syntax_highlighter.function_color = Color("90be6d")
	syntax_highlighter.member_variable_color = Color("43aa8b")
	
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
		syntax_highlighter.add_keyword_color(keyword, keywords[keyword])
	
	syntax_highlighter.add_color_region('"', '"', Color("abe9b3"))
	syntax_highlighter.add_color_region("'", "'", Color("abe9b3"))
	syntax_highlighter.add_color_region("#", "", Color("6e6c7e"), true)
	
