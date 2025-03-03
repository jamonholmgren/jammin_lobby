class_name JamminLobbyUI extends JamminLobby

func _ready() -> void:
  super()
  %CreateLobbyButton.pressed.connect(_on_create_lobby_pressed)

func _on_create_lobby_pressed() -> void:
  push_error("Create lobby pressed")
  pass
