extends Node3D

var menu: JamminLobby

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	menu = get_node("JamminLobbyUI")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
