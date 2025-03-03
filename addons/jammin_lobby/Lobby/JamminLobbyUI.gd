class_name JamminLobbyUI extends JamminLobby

func _ready() -> void:
  super()
  %CreateLobbyButton.pressed.connect(_on_create_lobby_pressed)
  Lobby.hosting_started.connect(_on_hosting_started)
  %LeaveLobbyButton.pressed.connect(_on_leave_lobby_pressed)
  Lobby.hosting_stopped.connect(_on_hosting_stopped)

func _on_create_lobby_pressed() -> void:
  Lobby.start_hosting()

func _on_hosting_started() -> void:
  %CreateLobby.hide()
  %LobbyInfo.show()

func _on_leave_lobby_pressed() -> void:
  Lobby.leave()

func _on_hosting_stopped(_msg: String = "") -> void:
  %CreateLobby.show()
  %LobbyInfo.hide()
