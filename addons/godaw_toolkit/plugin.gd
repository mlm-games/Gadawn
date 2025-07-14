@tool
extends EditorPlugin

const ADDON_PATH = "res://addons/godaw_toolkit"

func _enter_tree():
	add_autoload_singleton("GoDawn", "%s/api/go_dawn.gd" % ADDON_PATH)

func _exit_tree():
	remove_autoload_singleton("GoDawn")
