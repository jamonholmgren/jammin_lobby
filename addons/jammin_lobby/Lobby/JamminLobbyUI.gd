class_name JamminLobbyUI extends JamminLobby

func _ready() -> void:
	super()
	%CreateLobbyButton.pressed.connect(_on_create_lobby_pressed)
	%LeaveLobbyButton.pressed.connect(_on_leave_lobby_pressed)
	%Username.text_changed.connect(_on_username_changed)

	Lobby.hosting_started.connect(_on_hosting_started)
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

func _on_username_changed() -> void:
	var new_username = %Username.text
	if new_username.length() <= 0: return
	Lobby.update_me({ username = new_username })
	Lobby.sync_players()

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

	var players = Lobby.players.values()
	JamminList.update_list(%PlayerRows, players, false, update_player_row)
	
	var fake_lobbies = [
		{"name": "Lobby 1", "players": 2, "host": "Player 1"},
		{"name": "Lobby 2", "players": 3, "host": "Player 2"},
		{"name": "Lobby 3", "players": 4, "host": "Player 3"},
		{"name": "Lobby 4", "players": 4, "host": "Player 4"},
		{"name": "Lobby 5", "players": 4, "host": "Player 5"},
		{"name": "Lobby 6", "players": 4, "host": "Player 6"},
		{"name": "Lobby 7", "players": 4, "host": "Player 7"},
		{"name": "Lobby 8", "players": 4, "host": "Player 8"},
	]
	JamminList.update_grid(%LobbiesGrid, fake_lobbies, true, update_lobby_row)

func update_player_row(node: Node, player: Dictionary, i: int) -> void:
	var btn = node.get_node("ReadyButton")
	btn.text = "Ready" if player.get("ready", false) else "Not Ready"
	btn.disabled = true
	node.get_node("Name").text = player.username
	if player.id == Lobby.me.id:
		Lobby.cs(btn, "pressed", _on_ready_pressed)
		btn.disabled = false

func update_lobby_row(nodes: Array[Node], lobby: Dictionary, i: int) -> void:
	nodes[0].text = lobby.name
	nodes[1].text = str(lobby.players) + " / " + str(Lobby.config.max_players)
	nodes[2].text = lobby.host
	nodes[3].text = str(randi() % 150) + "ms" # fake ping

	Lobby.cs(nodes[0], "gui_input", _on_lobby_clicked.bind(lobby))

func show_create_lobby():
	%CreateLobby.show()
	%LobbyInfo.hide()

func _on_ready_pressed() -> void:
	Lobby.update_me({ ready = !Lobby.me.ready })
	Lobby.sync_players()

func _on_lobby_clicked(event: InputEvent, lobby: Dictionary) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("lobby clicked: ", lobby)
