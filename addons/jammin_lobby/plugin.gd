@tool
extends EditorPlugin

func _enter_tree() -> void:
	pass
	add_autoload_singleton("Lobby", "res://addons/jammin_lobby/Lobby/Lobby.gd")
	add_autoload_singleton("Options", "res://addons/jammin_lobby/Lobby/Options.gd")
	add_autoload_singleton("UIScale", "res://addons/jammin_lobby/Lobby/UIScale.gd")

func _exit_tree() -> void:
	pass
	remove_autoload_singleton("Lobby")
	remove_autoload_singleton("Options")
	remove_autoload_singleton("UIScale")
