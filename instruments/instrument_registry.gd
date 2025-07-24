class_name InstrumentRegistry
extends RefCounted

static func get_all_instruments() -> Dictionary:
	var instruments = {}
	var class_list = ProjectSettings.get_global_class_list()
	
	for class_info in class_list:
		var named_class = class_info["class"]
		var script_path = class_info["path"]
		var base_class = class_info["base"]
		
		if _inherits_from_instrument(named_class, base_class, class_list):
			if named_class == "Instrument":
				continue
			
			# Try to find the associated scene file
			var scene_path = _find_instrument_scene(script_path)
			if scene_path:
				var id = named_class.to_snake_case()
				instruments[id] = {
					"name": named_class.capitalize().replace("_", " "),
					"scene": load(scene_path),
					"named_class": named_class,
					"script_path": script_path,
					"icon": "PluginScript"
				}
	
	return instruments

static func _inherits_from_instrument(_named_class: String, base_class: String, class_list: Array) -> bool:
	if base_class == "Instrument":
		return true
	
	# Check indirect inheritance
	for class_info in class_list:
		if class_info["class"] == base_class:
			return _inherits_from_instrument(base_class, class_info["base"], class_list)
	
	# Optional Check if it's a built-in class that Instrument extends from (maybe might need)
	#if base_class == "Node" and named_class == "Instrument":
		#return true
		
	return false

## Look for a scene file in the same directory as the script
static func _find_instrument_scene(script_path: String) -> String:
	var dir_path = script_path.get_base_dir()
	var possible_scene_paths = [
		dir_path.path_join("instrument.tscn"),
		script_path.replace(".gd", ".tscn"),
		dir_path.path_join(dir_path.get_file() + ".tscn")
	]
	
	for scene_path in possible_scene_paths:
		if ResourceLoader.exists(scene_path):
			return scene_path
	
	return ""

static func get_instrument_by_named_class(named_class: String) -> Dictionary:
	var instruments = get_all_instruments()
	for id in instruments:
		if instruments[id]["named_class"] == named_class:
			return instruments[id]
	return {}

static func get_instrument_scene(id: String) -> PackedScene:
	var instruments = get_all_instruments()
	if instruments.has(id):
		return instruments[id]["scene"]
	return null
