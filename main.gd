class_name Main extends Node3D

static var menu: JamminLobbyUI

const USER_NAMES = [ "Chainsaw", "Hammer", "Axe", "Crusher", "Dumptruck", "Volcano", "Thunder" ]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	menu = get_node("JamminLobbyUI")
	Lobby.me.username = USER_NAMES[randi() % USER_NAMES.size()]

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if menu.visible:
			hide_menu()
		else:
			show_menu()

func show_menu() -> void:
	menu.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func hide_menu() -> void:
	menu.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
