@tool
extends EditorPlugin

const ADDON_PATH = "res://addons/godaw_toolkit"

func _enter_tree():
	add_autoload_singleton("GoDAW", "%s/API/GoDAW.gd" % ADDON_PATH)

func _exit_tree():
	remove_autoload_singleton("GoDAW")
