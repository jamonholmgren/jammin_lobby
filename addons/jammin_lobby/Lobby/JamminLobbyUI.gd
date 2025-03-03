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
  update_lobby_ui()

func _on_create_lobby_pressed() -> void:
  Lobby.start_hosting()

func _on_hosting_started() -> void:
  update_lobby_ui()

func _on_leave_lobby_pressed() -> void:
  Lobby.leave()

func _on_hosting_stopped(_msg: String = "") -> void:
  update_lobby_ui()

func _on_me_connecting_to_lobby() -> void:
  print("me_connecting_to_lobby")
  update_lobby_ui()

func _on_me_joined_lobby(player: Dictionary) -> void:
  print("me_joined_lobby: ", player)
  update_lobby_ui()

func _on_me_left_lobby(player: Dictionary) -> void:
  print("me_left_lobby: ", player)
  update_lobby_ui()

func _on_player_connecting_to_lobby(pid: int) -> void:
  print("player_connecting_to_lobby: ", pid)
  update_lobby_ui()

func _on_player_joined_lobby(player: Dictionary) -> void:
  print("player_joined_lobby: ", player)
  update_lobby_ui()

func _on_player_left_lobby(player: Dictionary) -> void:
  print("player_left_lobby: ", player)
  update_lobby_ui()

func _on_discovery_server_started() -> void:
  print("discovery_server_started")
  update_lobby_ui()

func _on_discovery_server_failed() -> void:
  print("discovery_server_failed")
  update_lobby_ui()

func _on_discovery_server_stopped() -> void:
  print("discovery_server_stopped")
  update_lobby_ui()

func update_lobby_ui() -> void:
  if not Lobby.online(): return show_create_lobby()
  %CreateLobby.hide()
  %LobbyInfo.show()
  
  # "Player" is always the local player
  var row = %PlayerRows.get_node("PlayerRow")
  row.get_node("Name").text = Lobby.me.username
  var btn = row.get_node("ReadyButton")
  btn.disabled = false
  btn.text = "Ready" if Lobby.me.get("ready", false) else "Not Ready"
  Lobby.cs(btn, "pressed", _on_ready_pressed)

  # Delete any existing rows past the first
  for child in %PlayerRows.get_children():
    if child == row: continue
    child.queue_free()
  
  # Other players
  for player in Lobby.players:
    var new_row = row.duplicate()
    new_row.get_node("Name").text = player.name
    var b = new_row.get_node("ReadyButton")
    b.text = "Ready" if player.get("ready", false) else "Not Ready"
    b.disabled = true
    %PlayerRows.add_child(new_row)

func show_create_lobby():
  %CreateLobby.show()
  %LobbyInfo.hide()

func _on_ready_pressed() -> void:
  Lobby.update_me({ ready = !Lobby.me.ready })
  Lobby.sync_players()

