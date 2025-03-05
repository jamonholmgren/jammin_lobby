class_name JamminLobbyUI extends JamminLobby

func _ready() -> void:
	super()
	%CreateLobbyButton.pressed.connect(_on_create_lobby_pressed)
	%LeaveLobbyButton.pressed.connect(_on_leave_lobby_pressed)
	%Username.text_changed.connect(_on_username_changed)
	%RefreshButton.pressed.connect(_on_refresh_pressed)

	Lobby.hosting_started.connect(_on_hosting_started)
	Lobby.hosting_stopped.connect(_on_hosting_stopped)
	Lobby.me_connecting_to_lobby.connect(_on_me_connecting_to_lobby)
	Lobby.me_joined_lobby.connect(_on_me_joined_lobby)
	Lobby.me_left_lobby.connect(_on_me_left_lobby)
	Lobby.me_updated.connect(_on_me_updated)
	Lobby.player_connecting_to_lobby.connect(_on_player_connecting_to_lobby)
	Lobby.player_joined_lobby.connect(_on_player_joined_lobby)
	Lobby.player_left_lobby.connect(_on_player_left_lobby)
	Lobby.player_updated.connect(_on_player_updated)
	Lobby.discovery_server_started.connect(_on_discovery_server_started)
	Lobby.discovery_server_failed.connect(_on_discovery_server_failed)
	Lobby.discovery_server_stopped.connect(_on_discovery_server_stopped)
	Lobby.lobbies_refreshed.connect(_on_lobbies_refreshed)
	%JoiningOverlay.hide()
	update_lobby_ui()

func _physics_process(_delta: float) -> void:
	# Every 5 seconds, update the ping if we're online
	if Engine.get_physics_frames() % (1 * 60) == 0 and Lobby.online() : Lobby.update_ping()

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

func _on_refresh_pressed() -> void:
	Lobby.find_lobbies()
	%RefreshButton.text = "Refreshing..."
	%RefreshButton.disabled = true

func _on_lobbies_refreshed(lobbies: Dictionary, error: String = "") -> void:
	%RefreshButton.disabled = false
	if error:
		%RefreshButton.text = "Error: " + error
	else:
		%RefreshButton.text = "Refresh"
	
	update_lobby_ui()

func _on_hosting_stopped(_msg: String = "") -> void:
	update_lobby_ui()

func _on_me_connecting_to_lobby() -> void:
	Lobby.lm("me_connecting_to_lobby")
	update_lobby_ui()

func _on_me_joined_lobby(player: Dictionary) -> void:
	Lobby.lm("me_joined_lobby: ", player)
	%JoiningOverlay.hide()
	update_lobby_ui()

func _on_me_left_lobby(reason: String) -> void:
	Lobby.lm("me_left_lobby: ", reason)
	%JoiningOverlay.hide()
	update_lobby_ui()

func _on_me_updated(player: Dictionary) -> void:
	Lobby.lm("me_updated: ", player)
	update_lobby_ui()

func _on_player_connecting_to_lobby(pid: int) -> void:
	Lobby.lm("player_connecting_to_lobby: ", pid)
	update_lobby_ui()

func _on_player_joined_lobby(player: Dictionary) -> void:
	Lobby.lm("player_joined_lobby: ", player)
	update_lobby_ui()

func _on_player_left_lobby(player: Dictionary) -> void:
	Lobby.lm("player_left_lobby: ", player)
	update_lobby_ui()

func _on_player_updated(player: Dictionary) -> void:
	Lobby.lm("player_updated: ", player)
	update_lobby_ui()

func _on_discovery_server_started() -> void:
	Lobby.lm("discovery_server_started")
	update_lobby_ui()

func _on_discovery_server_failed() -> void:
	Lobby.lm("discovery_server_failed")
	update_lobby_ui()

func _on_discovery_server_stopped() -> void:
	Lobby.lm("discovery_server_stopped")
	update_lobby_ui()

func update_lobby_ui() -> void:
	var lobbies = Lobby.found_lobbies.values()
	JamminList.update_grid(%LobbiesGrid, lobbies, true, update_lobby_row)
	
	if not Lobby.online(): return show_create_lobby()
	%CreateLobby.hide()
	%LobbyInfo.show()

	var players = Lobby.players.values()
	Lobby.lm("  --  Players: ", players)
	JamminList.update_list(%PlayerRows, players, false, update_player_row)

func update_player_row(node: Node, player: Dictionary, i: int) -> void:
	var btn = node.get_node("ReadyButton")
	btn.text = "Ready" if player.get("ready", false) else "Not Ready"
	btn.disabled = true
	node.get_node("Name").text = player.username
	node.get_node("Ping").text = str(player.ping) + "us"
	if player.id == Lobby.me.id:
		Lobby.cs(btn, "pressed", _on_ready_pressed)
		btn.disabled = false

func update_lobby_row(nodes: Array[Node], lobby: Dictionary, i: int) -> void:
	nodes[0].text = lobby.lobby_name
	nodes[1].text = lobby.game_version
	nodes[2].text = str(lobby.players) + " / " + str(lobby.max_players)
	nodes[3].text = str(randi() % 150) + "ms" # fake ping

	Lobby.cs(nodes[0], "gui_input", _on_lobby_clicked.bind(lobby))

func show_create_lobby():
	%CreateLobby.show()
	%LobbyInfo.hide()

func _on_ready_pressed() -> void:
	Lobby.update_me({ ready = !Lobby.me.get("ready", false) })

func _on_lobby_clicked(event: InputEvent, lobby: Dictionary) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		%JoiningOverlay.show()
		Lobby.join(lobby)
