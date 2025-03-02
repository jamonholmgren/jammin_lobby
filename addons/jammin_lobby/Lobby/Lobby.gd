class_name JamminLobby extends JamminBase

static var instance: JamminLobby = null

const ERROR_INSTANCE_ALREADY_EXISTS = "JamminLobby instance already exists; should be an autoload / singleton"

# Player Signals *****************************************************
signal joining_lobby()
signal joined_lobby()
signal left_lobby(reason: String)

signal command_received(data: Dictionary)
signal message_received_from_host(message: String)

# Same as above, but for any player, not just me

signal player_joining_lobby(pid: int) # all we have is a pid, no player yet
signal player_joined_lobby(player: JamminPlayer)
signal player_left_lobby(player: JamminPlayer)
signal player_updated(player: JamminPlayer)

# Host Signals *****************************************************

# Same as above, but only emitted on the host!

signal host_joining_lobby()
signal host_joined_lobby()
signal host_left_lobby(reason: String)
signal host_player_joining_lobby(pid: int) # all we have is a pid, no player yet
signal host_player_joined_lobby(player: JamminPlayer)
signal host_player_left_lobby(player: JamminPlayer)
signal host_player_updated(player: JamminPlayer)

signal hosting_started()
signal hosting_failed(message: String)
signal hosting_stopped(message: String)

signal discovery_server_started()
signal discovery_server_failed(error: int)
signal discovery_server_stopped()

signal chat_messages_updated()

# Constants **********************************************************

const SERVER_ID := 1

const PLAYER_SCRIPT := "res://addons/jammin_lobby/Lobby/Player.gd"
const PLAYER_SCENE := "res://addons/jammin_lobby/Lobby/Player.tscn"

var game_name: String = ProjectSettings.get_setting("application/config/name")
var game_version: String = ProjectSettings.get_setting("application/config/version")

# Settings **********************************************************

# Default name for the player's lobby
@export var lobby_name: String = "Game Server"

# Game server port: connect to lobbies & players
@export var game_port: int = 9500

# Discovery server port: broadcast presence
@export var broadcast_port: int = 9501

# Discovery client port: respond to discovery requests
@export var response_port: int = 9502

# Max number of players allowed on the server
@export var max_players: int = 8

# String to look for, identifying clients of the same game
@export var refresh_packet: String = "INTO_THE_DAWN_HELLO"

# Connection timeout in seconds
@export var connection_timeout: int = 3

# A custom script to use for new player objects that inherits from JamminPlayer
# Usually called Player.gd but could be anything: Pilot.gd, Fighter.gd, Explorer.gd, etc.
@export var player_script: Script = preload(PLAYER_SCRIPT)

# The scene to use for new player objects
@export var player_scene: PackedScene = preload(PLAYER_SCENE)

# Whether to save & restore the local player automatically
@export var autosave: bool = true

# The save location for player-specific options
@export var player_save_file: String = "user://jammin_player_save_{0}.json"

# Optional save slot to use for the local player, to allow multiple users.
@export var save_slot: int = 1

# The save location for lobby-wide options
@export var options_save_file: String = "user://jammin_options.json"

# Lobby chat messages
@export var chat_messages: Array[Dictionary] = []

# State *************************************************************************

@onready var game_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
@onready var discovery_server: PacketPeerUDP = PacketPeerUDP.new()
@onready var player_room: Node = Node.new()
@onready var request: JamminRequest = JamminRequest.new()

var me: JamminPlayer = null
var host: JamminPlayer = null

var options: JamminOptions = null:
	get: return options_get({
		"save_file": options_save_file,
		"backup_file": options_save_file + ".backup.json",
		"restore": true
	})

var found_lobbies: Dictionary = {}
var current_lobby: Dictionary = {}
var host_messages: Array[String] = []
var refreshing := false
var player_names: Dictionary = { }

# Lifecycle ***********************************************************************

func _init():
	if instance: push_error(ERROR_INSTANCE_ALREADY_EXISTS); return
	instance = self

func _ready() -> void:
	setup_multiplayer()
	player_room.name = "PlayerRoom"; add_child(player_room)
	request.name = "Request"; add_child(request)

func _process(_delta) -> void:
	if not discovery_server.is_bound(): set_process(false); return
	check_for_clients_discovery()

func _exit_tree():
	leave("Lobby is exiting the tree, leaving")

func setup_multiplayer():
	lm("Lobby: _ready")
	multiplayer.multiplayer_peer = null

	# Multiplayer signals
	multiplayer.connected_to_server.connect(_on_connection_succeeded)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_connection_ended)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# Game peer signals
	game_peer.peer_connected.connect(_on_remote_peer_connected)
	game_peer.peer_disconnected.connect(_on_remote_peer_disconnected)

# Lobby Host Actions *************************************************************

func setup(settings: Dictionary):
	lm("setup")
	configure(settings)
	create_me()

func configure(settings: Dictionary):
	lm("configure")
	if settings.has("lobby_name"): lobby_name = settings.lobby_name
	if settings.has("game_port"): game_port = settings.game_port
	if settings.has("broadcast_port"): broadcast_port = settings.broadcast_port
	if settings.has("response_port"): response_port = settings.response_port
	if settings.has("max_players"): max_players = settings.max_players
	if settings.has("refresh_packet"): refresh_packet = settings.refresh_packet
	if settings.has("connection_timeout"): connection_timeout = settings.connection_timeout
	if settings.has("player_script"): player_script = settings.player_script
	if settings.has("player_scene"): player_scene = settings.player_scene
	if settings.has("autosave"): autosave = settings.autosave
	if settings.has("save_slot"): save_slot = settings.save_slot
	if settings.has("player_save_file"): player_save_file = settings.player_save_file
	if settings.has("options_save_file"): options_save_file = settings.options_save_file
	# if settings.has("proxy_url"): proxy.proxy_url = settings.proxy_url

func start_hosting(settings: Dictionary = {}):
	lm("start_hosting ", settings)
	configure(settings)
	start_server()
	start_discovery()
	me.start_sync()

func stop_hosting(msg: String = "Game ended by host"):
	lm("stop_hosting ", msg)
	stop_discovery()
	server_disconnect_all_peers(msg)
	stop_server("Game ended by host; " + msg)	
	me.stop_sync()

func close_game_peer():
	multiplayer.multiplayer_peer = null
	game_peer.close()
	# Reset the game peer to a new instance
	game_peer = ENetMultiplayerPeer.new()

# Server Actions *******************************************************************

func start_server() -> void:
	lm("start_server")
	if game_peer and game_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED: close_game_peer()
	var error = game_peer.create_server(game_port, max_players)
	if error != OK:
		close_game_peer()
		var msg = str(error)
		if error == ERR_CANT_CREATE: msg = "Is port %s already in use?" % game_port
		push_error("Error starting server: " + str(error))
		hosting_failed.emit(msg)
		return

	multiplayer.multiplayer_peer = game_peer
	me.set_id(SERVER_ID)
	# Update the lobby_name
	lobby_name = me.username + " - Into the Dawn Game Server"
	hosting_started.emit() # manually because there's no built-in signal

func stop_server(message: String):
	lm("stop_server: ", message)
	if not is_host(): return
	if not multiplayer.is_server():
		lm("!!! stop_server: not multiplayer.is_server() !!!")
		return
	close_game_peer()
	multiplayer.multiplayer_peer = null
	hosting_stopped.emit(message)
	_on_server_stopped(message)

func server_disconnect_all_peers(reason: String = ""):
	if not is_host(): return
	lm("server_disconnect_all_peers: ", reason)
	for pid in multiplayer.get_peers():
		if pid == SERVER_ID: continue # don't disconnect us
		if not multiplayer.get_peers().has(pid): continue
		server_disconnect_peer(pid, reason)

func server_disconnect_peer(pid: int, reason: String = "") -> void:
	if not is_host(): return
	if not pid_in_lobby(pid): return
	lm("server_disconnect_peer: ", pid, " ", reason)
	# Tell the player why they are being disconnected
	send_chat.rpc_id(pid, reason)
	# Now disconnect them	
	multiplayer.multiplayer_peer.disconnect_peer(pid)
	var p = find_by_pid(pid)
	if not p: return
	if is_me(p): return me.stop_sync()
	p.queue_free()

# Finds local ip addresses to tell clients to try to connect to if discovery fails
func server_local_ips() -> Array: return get_local_ipv4_addresses()

# Discovery server ***********************************************************************

func start_discovery() -> void:
	lm("start_discovery")
	if not is_host(): return
	if discovery_server.is_bound(): discovery_server.close()
	var result = discovery_server.bind(broadcast_port)
	if result != OK:
		lm("Lobby: Discovery server failed to bind: ", result, " on port ", broadcast_port)
		discovery_server_failed.emit(result)
		return
	set_process(true) # start listening for pings
	discovery_server_started.emit()
	# lm("discovery_server_started.emit")

func stop_discovery():
	lm("stop_discovery")
	if not discovery_server.is_bound(): return
	set_process(false)
	discovery_server.close()
	discovery_server_stopped.emit()
	# lm("discovery_server_stopped.emit")

func check_for_clients_discovery() -> void:
	if not discovery_server.is_bound(): return pe("Lobby: Discovery server not bound!")
	if discovery_server.get_available_packet_count() == 0: return

	var ping = {
		"data": discovery_server.get_packet().get_string_from_utf8(),
		"ip": discovery_server.get_packet_ip(),
		"port": discovery_server.get_packet_port()
	}
	if ping.data != refresh_packet: return

	var response = {
		"game_name": game_name,
		"game_version": game_version,
		"lobby_name": lobby_name,
		"game_port": game_port,
		"players": multiplayer.get_peers().size() + 1, # +1 for the server itself
		"max_players": max_players
	}
	var response_string = JSON.stringify(response)

	# lm("Sending response: ", response, " to ", ping.ip, ":", ping.port)
	discovery_server.set_dest_address(ping.ip, ping.port)
	discovery_server.put_packet(response_string.to_utf8_buffer())

# Client Actions *******************************************************************

func sync_all_players():
	for p in players():
		if p.is_syncing(): continue
		p.start_sync()
		if is_me(p):
			joined_lobby.emit()
			if is_host(): host_joined_lobby.emit()
		player_joined_lobby.emit(p)
		if is_host(): host_player_joined_lobby.emit(p)

# Refresh the list of local servers
func find_lobbies(callback: Callable, retry = 0):
	lm("find_lobbies ", retry)
	# just in case, close the discovery server if it's already bound
	if discovery_server.is_bound(): discovery_server.close()
	
	refreshing = true
	found_lobbies.clear()

	# Bind to the port that servers will respond to with their information
	var error = discovery_server.bind(response_port)
	if error != OK:
		refreshing = false
		callback.call([], "Error binding client discovery broadcast: " + str(error))
		return
	
	discovery_server.set_broadcast_enabled(true)
	discovery_server.set_dest_address("255.255.255.255", broadcast_port)
	discovery_server.put_packet(refresh_packet.to_utf8_buffer())
	# lm("Sent refresh packet")

	await wait(0.2 * (retry + 1))
	
	while discovery_server.get_available_packet_count() > 0:
		var ping = {
			"data": discovery_server.get_packet().get_string_from_utf8(),
			"ip": discovery_server.get_packet_ip(),
			"port": discovery_server.get_packet_port()
		}
		if ping.ip == "" or ping.data == refresh_packet: continue

		var server_info_parsed = JSON.parse_string(ping.data)

		server_info_parsed["ip"] = ping.ip
		server_info_parsed["port"] = ping.port

		found_lobbies[ping.ip] = server_info_parsed
	
	discovery_server.close()
	refreshing = false

	# Refresh again up to 3 times, sometimes it takes a bit longer
	if found_lobbies.size() <= 0 and retry < 3: # auto-refresh temporarily disabled for testing
		find_lobbies(callback, retry + 1)
	else:
		callback.call(found_lobbies)

# Join a server by IP address and port
func join(lobby: Dictionary) -> void:
	lm("join: ", lobby)
	if not lobby.has("ip") or not lobby.has("port"): return pe("Invalid lobby: ", lobby)

	current_lobby = lobby
	joining_lobby.emit()

	# Connect via proxy first (not enabled yet)
	# if proxy and proxy.is_enabled():
	# 	if not await proxy.connect_proxy(me.username):
	# 		return left_lobby.emit("Failed to connect to proxy")
	
	if multiplayer.has_multiplayer_peer(): close_game_peer()

	var error := game_peer.create_client(lobby.ip, lobby.port)
	if error != OK: left_lobby.emit("Failed to connect to lobby. Error code " + str(error)); return
	multiplayer.multiplayer_peer = game_peer

# Leave the current server
func leave(message: String):
	if not in_lobby(): return
	lm("leave: ", message)
	me.is_ready = false
	if is_host(): return stop_hosting(message)
	# Bubble-wrapping this because it keeps erroring out
	# if multiplayer and multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
	# 	if multiplayer.get_peers().has(SERVER_ID):
	# 		# multiplayer.multiplayer_peer.disconnect_peer(SERVER_ID)
	# 		var pr: ENetPacketPeer = multiplayer.multiplayer_peer.get_peer(SERVER_ID)
	# 		if pr and pr.get_state() == ENetPacketPeer.STATE_CONNECTED: pr.peer_disconnect_later(0)
	if multiplayer: multiplayer.multiplayer_peer = null
	lm("disconnect_peer: ", SERVER_ID)

func create_player_if_not_exists(pid: int) -> JamminPlayer:
	lm("create_player_if_not_exists: ", pid)
	var p := find_by_pid(pid)
	if p: return p
	p = player_scene.instantiate()
	if player_script != null: p.set_script(player_script)
	p.stop_sync()
	p.set_id(pid)
	if pid == SERVER_ID: host = p
	p.is_ready = false
	p.updated.connect(_on_player_updated.bind(p))
	player_room.add_child(p)
	return p

# Host methods **************************************************

func create_me() -> JamminPlayer:
	lm("create_me")
	# Create local player instance
	me = create_player_if_not_exists(multiplayer_id())
	host = me
	if autosave: me.restore() # from disk
	me.on_me_created()
	return me

# Easy way to talk to other players!
func on_ask(req_name: String, player_fn: Callable = request.no_op): request.on_ask(req_name, player_fn)
func remove_on_ask(req_name: String): request.remove_on_ask(req_name)
func ask(pid: int, req_name: String, data: Dictionary) -> Variant: return await request.ask(pid, req_name, data)
func ask_all(req_name: String, data: Dictionary = {}) -> void: request.broadcast(req_name, data)
func broadcast(req_name: String, data: Dictionary = {}) -> void: request.broadcast(req_name, data)

# Chat methods *******************************************************************

func send_chat_to_host(message: String) -> Error:
	# Can't send chat messages if we're not in a lobby
	if multiplayer_id() == 0: return ERR_UNAVAILABLE
	
	send_chat.rpc_id(SERVER_ID, message)
	return OK

@rpc("any_peer", "reliable", "call_local")
func send_chat(message: String) -> Error:
	# If we're not in a lobby, we send a system message
	if multiplayer_id() == 0: return send_system_chat(message)

	# If we're not the host, tell the host to add the message and it will then be sent to all clients
	if not is_host(): return send_chat_to_host(message)

	var sender_id = sid()
	if sender_id == 0: sender_id = multiplayer_id()

	# We are the host, so add the message to our list and broadcast the list to all clients
	add_chat(message, sender_id)

	# Sort the chat messages by timestamp
	chat_messages.sort_custom(func(a, b): return a.get("ts") < b.get("ts"))

	broadcast_chat_messages()
	chat_messages_updated.emit() # for us
	return OK

# System messages are local only, and aren't broadcast to other clients
func send_system_chat(message: String):
	add_chat(message, 0, "system")
	chat_messages_updated.emit()
	return OK

func add_chat(message: String, sender_id: int, channel: String = "lobby"):
	chat_messages.push_back({
		"id": str(sender_id) + "_" + str(timestamp()).replace(".", ""),
		"body": message,
		"sender": sender_id,
		"ts": timestamp(),
		"timestamp": time_str(timestamp()),
		"channel": channel
	})

func broadcast_chat_messages():
	var m = chat_messages.filter(func(msg): return msg.get("channel", "lobby") != "system")
	update_chat_messages.rpc(m)

@rpc("authority", "reliable", "call_local")
func update_chat_messages(messages: Array[Dictionary]):
	# Update chat messages with the server-based ones
	for msg in messages:
		var existing = find_by_key(chat_messages, "id", msg["id"])
		if existing: existing.merge(msg, true)
		else: chat_messages.push_back(msg)
	chat_messages_updated.emit()

# Player methods *******************************************************************

func players() -> Array[JamminPlayer]:
	var pls: Array[JamminPlayer] = []
	for p in player_room.get_children():
		if p is JamminPlayer and not p.is_queued_for_deletion(): pls.append(p)
	return pls

func player_ids() -> Array[int]:
	if not has_multiplayer_connection(): return []
	var ids: Array[int] = [SERVER_ID]
	for pid in multiplayer.get_peers(): if not ids.has(pid): ids.append(pid)
	return ids

func find_by_pid(pid: int) -> JamminPlayer:
	if pid == 0: return null
	for p in players(): if p.id == pid or p.get_multiplayer_authority() == pid: return p
	return null

# Returns if all active players are ready
func all_ready() -> bool:
	return players().all(func(p): return p.is_ready)

# Getting state *******************************************************************

func multiplayer_id() -> int:
	if not has_multiplayer_connection(): return 0
	return game_peer.get_unique_id()

func pid_in_lobby(pid: int) -> bool: return pid == SERVER_ID or multiplayer.get_peers().has(pid)
func in_lobby() -> bool:  return is_host() or has_multiplayer_connection()
func sid() -> int:        return multiplayer.get_remote_sender_id()
func is_host() -> bool:   return has_multiplayer_connection() and multiplayer.is_server()
func is_client() -> bool: return has_multiplayer_connection() and not is_host()
func is_me(p: JamminPlayer) -> bool: return p and me == p
func has_multiplayer_connection() -> bool: return multiplayer and multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
func last_host_message() -> String: return host_messages.back() if host_messages.size() > 0 else ""
func is_authority(node: Node) -> bool:
	if multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED: return node.is_multiplayer_authority()
	return false

# Signal Handlers ***************************************************************

func _on_player_updated(p: JamminPlayer):
	# We are both 0 and <some other id>, so update both
	player_names[p.id] = p.username
	if is_me(p): player_names[0] = p.username
	player_updated.emit(p)
	if is_host(): host_player_updated.emit(p)

func _on_connection_succeeded():
	var pid = multiplayer_id()
	lm("_on_connection_succeeded: ", pid)
	me.set_id(pid)
	joining_lobby.emit()
	if is_host(): host_joining_lobby.emit()

func _on_connection_failed(reason: String = ""):
	lm("_on_connection_failed: ", reason)
	left_lobby.emit(reason)
	if is_host(): host_left_lobby.emit(reason)

func _on_connection_ended(reason: String = ""):
	lm("_on_connection_ended: ", reason)
	# Per: https://github.com/godotengine/godot/issues/77723#issuecomment-1830689802
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	me.stop_sync()
	left_lobby.emit(reason)
	if is_host(): host_left_lobby.emit(reason)
	
func _on_server_started():
	lm("_on_server_started")
	hosting_started.emit()
	lm("hosting_started.emit")
	me.start_sync()

func _on_server_failed(message: String):
	lm("_on_server_failed: ", message)
	hosting_failed.emit(message)
	lm("hosting_failed.emit: ", message)
	me.stop_sync()

func _on_server_stopped(message: String = ""):
	lm("_on_server_stopped: ", message)
	hosting_stopped.emit(message)
	lm("hosting_stopped.emit: ", message)
	me.stop_sync()

func _on_remote_peer_connected(pid: int):
	lm("_on_remote_peer_connected: ", pid)
	if pid == SERVER_ID:
		# I connected to a server
		joining_lobby.emit()
		if is_host(): host_joining_lobby.emit()
		lm("joining_lobby.emit: ", pid)

		# Now set my own id via multiplayer_id(), now that I have a connection
		me.set_id(multiplayer_id())
	else:
		if not is_host():
			push_error("My assumption is wrong; I'm not the host but I got a remote peer connected!")
			lm("!!! My assumption is wrong; I'm not the host but I got a remote peer connected!")
			return

		# Someone else connected to my server, is joining_lobby
		player_joining_lobby.emit(pid)
		if is_host(): host_player_joining_lobby.emit(pid)
		lm("player_joining_lobby.emit: ", pid)

	spawn_all_players(player_ids())

func _on_remote_peer_disconnected(pid: int, reason: String = ""):
	lm("_on_remote_peer_disconnected: ", pid, " " + reason)
	if pid == SERVER_ID: leave("Host disconnected")
	var p = find_by_pid(pid)
	if not p: return
	if is_host() and not is_me(p): p.queue_free()
	player_left_lobby.emit(p)
	if is_host(): host_player_left_lobby.emit(p)

func _on_peer_connected(pid: int):
	lm("_on_peer_connected: ", pid)
	player_joining_lobby.emit(pid)
	if is_host(): host_player_joining_lobby.emit(pid)
	lm("player_joining_lobby.emit: ", pid)

	# Create the player if it doesn't already exist
	var p = create_player_if_not_exists(pid)
	
	if not is_host(): return
	
	# Host activates all players, then tells everyone else to spawn/activate their own copies
	sync_all_players()

	# Now tell everyone all pids to spawn in so we can start syncing them
	spawn_all_players.rpc(player_ids())

func _on_peer_disconnected(pid: int):
	lm("_on_peer_disconnected: ", pid)
	var p = find_by_pid(pid)
	if not p: return
	p.stop_sync()
	p.is_ready = false
	if is_host() and not is_me(p): p.queue_free()
	player_left_lobby.emit(p)
	if is_host(): host_player_left_lobby.emit(p)

# Endpoints ***************************************************************

# Host to client endpoints ************************************************

@rpc("authority", "reliable", "call_local")
func spawn_all_players(pids: Array[int]):
	lm("spawn_all_players: ", pids)
	var players_not_mentioned: Array[int] = player_ids()
	for pid in pids:
		if pid == 0: continue # don't spawn disconnected players
		players_not_mentioned.erase(pid)
		create_player_if_not_exists(pid)
	
	for pid in players_not_mentioned:
		if pid == multiplayer_id(): lm("!!! Host doesn't like us !!!")
		else: find_by_pid(pid).queue_free()
	
	# Now activate all local players
	sync_all_players()
