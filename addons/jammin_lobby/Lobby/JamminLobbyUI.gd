class_name JamminLobbyUI extends JamminLobby

# This is a basic Lobby UI for your game. Drop it into your main scene
# and it'll automatically do everything except the game itself.
#
# To connect to the "start game" event, do this:
# Lobby.on_game_event.connect(_on_start_game_pressed)

func _ready() -> void:
	super()
	%CreateLobbyButton.pressed.connect(_on_create_lobby_pressed)
	%LeaveLobbyButton.pressed.connect(_on_leave_lobby_pressed)
	%Username.text_changed.connect(_on_username_changed)
	%RefreshButton.pressed.connect(_on_refresh_pressed)
	%StartGameButton.pressed.connect(_on_start_game_pressed)

	Lobby.i_restored.connect(update_lobby_ui)
	Lobby.i_connecting_to_lobby.connect(update_lobby_ui)
	Lobby.i_joined_lobby.connect(_on_i_joined_lobby)
	Lobby.i_left_lobby.connect(_on_i_left_lobby)
	Lobby.i_updated.connect(update_lobby_ui)
	Lobby.hosting_started.connect(update_lobby_ui)
	Lobby.hosting_failed.connect(update_lobby_ui)
	Lobby.hosting_stopped.connect(update_lobby_ui)
	Lobby.player_connecting_to_lobby.connect(update_lobby_ui)
	Lobby.player_joined_lobby.connect(update_lobby_ui)
	Lobby.player_left_lobby.connect(update_lobby_ui)
	Lobby.player_updated.connect(update_lobby_ui)
	Lobby.discovery_server_started.connect(update_lobby_ui)
	Lobby.discovery_server_failed.connect(update_lobby_ui)
	Lobby.discovery_server_stopped.connect(update_lobby_ui)
	Lobby.lobbies_refreshed.connect(_on_lobbies_refreshed)
	Lobby.ping_updated.connect(update_lobby_ui)

	%JoiningOverlay.hide()

	UIScale.enable(Vector2(1920, 1080), {
		UIScale.Config.UPDATE_RATE: 0.01,
		UIScale.Config.MIN_UI_SCALE: 0.5,
		UIScale.Config.MAX_UI_SCALE: 2.0
	})
	
	update_lobby_ui()

func _on_create_lobby_pressed() -> void:
	Lobby.start_hosting()

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

	Lobby.update_ping()

func _on_lobbies_refreshed(lobbies: Dictionary, error: String = "") -> void:
	%RefreshButton.disabled = false
	if error:
		%RefreshButton.text = "Error: " + error
	else:
		%RefreshButton.text = "Refresh"
	
	update_lobby_ui()

func _on_i_joined_lobby(player: Dictionary) -> void:
	Lobby.lm("i_joined_lobby: ", player)
	%JoiningOverlay.hide()
	update_lobby_ui()

func _on_i_left_lobby(reason: String) -> void:
	Lobby.lm("i_left_lobby: ", reason)
	%JoiningOverlay.hide()
	update_lobby_ui()

func update_lobby_ui(_a = null, _b = null, _c = null, _d = null) -> void:
	var lobbies = Lobby.found_lobbies.values()
	JamminList.update_grid(%LobbiesGrid, lobbies, true, update_lobby_row)
	
	if not Lobby.online(): return show_create_lobby()
	%CreateLobby.hide()
	%LobbyInfo.show()

	var players = Lobby.players.values()
	Lobby.lm("  --  Players: ", players)
	JamminList.update_list(%PlayerRows, players, false, update_player_row)

	%StartGameButton.disabled = not (Lobby.i_am_host() and all_ready())
	
func all_ready() -> bool:
	for player in Lobby.players.values():
		if not player.get("ready", false): return false
	return true

func update_player_row(node: Node, player: Dictionary, _i: int) -> void:
	var btn = node.get_node("ReadyButton")
	btn.text = "Ready" if player.get("ready", false) else "Not Ready"
	btn.disabled = true
	node.get_node("Name").text = player.username
	node.get_node("Ping").text = str(player.ping) + "us"
	if player.id == Lobby.me.id:
		Lobby.cs(btn, "pressed", _on_ready_pressed)
		btn.disabled = false

func update_lobby_row(nodes: Array[Node], lobby: Dictionary, _i: int) -> void:
	nodes[0].text = lobby.lobby_name
	nodes[1].text = lobby.game_version
	nodes[2].text = str(lobby.players) + " / " + str(lobby.max_players)
	nodes[3].text = str(randi() % 150) + "ms" # fake ping

	Lobby.cs(nodes[0], "gui_input", _on_lobby_clicked.bind(lobby))

func show_create_lobby():
	%CreateLobby.show()
	%LobbyInfo.hide()

func _on_ready_pressed() -> void:
	Lobby.update_me({ "ready": !Lobby.me.get("ready", false) })

func _on_lobby_clicked(event: InputEvent, lobby: Dictionary) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		%JoiningOverlay.show()
		Lobby.join(lobby)

func _on_start_game_pressed() -> void:
	if Lobby.i_am_host() and all_ready():
		Lobby.send_game_event("start_game")
