@tool
extends EditorPlugin

func _enter_tree() -> void:
	pass
	add_autoload_singleton("Lobby", "res://addons/jammin_lobby/Lobby/Lobby.gd")

func _exit_tree() -> void:
	pass
	remove_autoload_singleton("Lobby")
