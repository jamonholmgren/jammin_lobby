class_name JamminLobbyUI extends JamminLobby

func _ready() -> void:
  super()
  %CreateLobbyButton.pressed.connect(_on_create_lobby_pressed)
  Lobby.hosting_started.connect(_on_hosting_started)
  %LeaveLobbyButton.pressed.connect(_on_leave_lobby_pressed)
  Lobby.hosting_stopped.connect(_on_hosting_stopped)
  Lobby.me_connecting_to_lobby.connect(_on_me_connecting_to_lobby)
  Lobby.me_joined_lobby.connect(_on_me_joined_lobby)
  Lobby.me_left_lobby.connect(_on_me_left_lobby)
  Lobby.player_connecting_to_lobby.connect(_on_player_connecting_to_lobby)
  Lobby.player_joined_lobby.connect(_on_player_joined_lobby)
  Lobby.player_left_lobby.connect(_on_player_left_lobby)
  Lobby.discovery_server_started.connect(_on_discovery_server_started)
  Lobby.discovery_server_failed.connect(_on_discovery_server_failed)
  Lobby.discovery_server_stopped.connect(_on_discovery_server_stopped)

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

func _on_me_connecting_to_lobby() -> void:
  print("me_connecting_to_lobby")

func _on_me_joined_lobby(player: Dictionary) -> void:
  print("me_joined_lobby: ", player)

func _on_me_left_lobby(player: Dictionary) -> void:
  print("me_left_lobby: ", player)

func _on_player_connecting_to_lobby(pid: int) -> void:
  print("player_connecting_to_lobby: ", pid)

func _on_player_joined_lobby(player: Dictionary) -> void:
  print("player_joined_lobby: ", player)

func _on_player_left_lobby(player: Dictionary) -> void:
  print("player_left_lobby: ", player)

func _on_discovery_server_started() -> void:
  print("discovery_server_started")

func _on_discovery_server_failed() -> void:
  print("discovery_server_failed")

func _on_discovery_server_stopped() -> void:
  print("discovery_server_stopped")
