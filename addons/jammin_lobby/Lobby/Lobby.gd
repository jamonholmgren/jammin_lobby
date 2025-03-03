extends JamminBase

# autoload singleton called "Lobby" which is the core of the lobby system
# Use this class to interact with the lobby system from code

# Signals ***********************************************************************

# Signals for the local player
signal me_connecting_to_lobby()
signal me_joined_lobby(player: Dictionary)
signal me_left_lobby(reason: String)
signal me_updated(player: Dictionary)

# Signals for other players
signal player_connecting_to_lobby(pid: int) # all we have is a pid, no player yet
signal player_joined_lobby(player: Dictionary)
signal player_left_lobby(player: Dictionary)
signal player_updated(player: Dictionary)

# Signals for the lobby
signal hosting_started()
signal hosting_failed(message: String)
signal hosting_stopped(message: String)

# Signals for the discovery server
signal discovery_server_started()
signal discovery_server_failed(error: int)
signal discovery_server_stopped()
signal lobbies_refreshed(lobbies: Dictionary)

# Signals for the chat messages
signal chat_messages_updated()

# Constants **********************************************************

const SERVER_ID := MultiplayerPeer.TARGET_PEER_SERVER

static var config: JamminLobby = null

# Lobby chat messages
var chat_messages: Array[Dictionary] = []

# Optional save slot to use for the local player, to allow multiple users.
var save_slot: int = 1

# Game name
var game_name: String = ProjectSettings.get_setting("application/config/name")

# Game version
var game_version: String = ProjectSettings.get_setting("application/config/version")

# State *************************************************************************

var discovery_server: PacketPeerUDP
var request: JamminRequest

# This gets assigned to your player before you join a lobby
# You can adjust these values as needed and save your player
# to disk with `Lobby.save()`
const DEFAULT_PLAYER_DATA: Dictionary = {
	"id": 0,
	"username": "",
	"in_lobby": false,
	"host": false
}

# This is a dictionary of all players in the lobby
# The key is the player ID, and the value is a dictionary of player data
# You can access player data with `Lobby.get_player(player_id)`
var players: Dictionary = {}
var _host_players: Dictionary = {}

# Local copy of my player data, which gets updated as you join/leave lobbies
# Don't update this directly; use `Lobby.update_me({ ... })` instead
var me: Dictionary

var options: JamminOptions = null:
	get: return options_get({
		"save_file": config.options_save_file,
		"backup_file": config.options_save_file + ".backup.json",
		"restore": true
	})

var found_lobbies: Dictionary = {}
var refreshing := false

# Lifecycle ***********************************************************************

func _ready() -> void:
	debug = true
	me = {}
	me.merge(DEFAULT_PLAYER_DATA, true)
	setup_multiplayer()
	setup_request()

func _process(_delta) -> void:
	if not discovery_server.is_bound(): set_process(false); return
	check_for_clients_discovery()

func _exit_tree():
	leave("Lobby is exiting the tree, leaving")

func setup_multiplayer():
	lm("Lobby: _ready")
	
	# Connect to Multiplayer signals if not already online
	cs(multiplayer, "connected_to_server", _on_connection_succeeded)
	cs(multiplayer, "connection_failed", _on_connection_failed)
	cs(multiplayer, "server_disconnected", _on_connection_ended)
	cs(multiplayer, "peer_connected", _on_peer_connected)
	cs(multiplayer, "peer_disconnected", _on_peer_disconnected)

	# Discovery server
	if discovery_server: discovery_server.queue_free()
	discovery_server = PacketPeerUDP.new()

func setup_request():
	request = JamminRequest.new()
	request.name = "Request"
	add_child(request)

func setup_game_peer() -> ENetMultiplayerPeer:
	# Game peer setup
	close_game_peer()
	var new_game_peer = ENetMultiplayerPeer.new()
	cs(new_game_peer, "peer_connected", _on_remote_peer_connected)
	cs(new_game_peer, "peer_disconnected", _on_remote_peer_disconnected)
	return new_game_peer

# Lobby Host Actions *************************************************************

func setup(settings: Dictionary):
	lm("setup")
	configure(settings)

func configure(settings: Dictionary):
	lm("configure")
	if settings.has("lobby_name"): config.lobby_name = settings.lobby_name
	if settings.has("game_port"): config.game_port = settings.game_port
	if settings.has("broadcast_port"): config.broadcast_port = settings.broadcast_port
	if settings.has("response_port"): config.response_port = settings.response_port
	if settings.has("max_players"): config.max_players = settings.max_players
	if settings.has("connection_timeout"): config.connection_timeout = settings.connection_timeout
	if settings.has("player_script"): config.player_script = settings.player_script
	if settings.has("player_scene"): config.player_scene = settings.player_scene
	if settings.has("autosave"): config.autosave = settings.autosave
	if settings.has("save_slot"): save_slot = settings.save_slot
	if settings.has("player_save_file"): config.player_save_file = settings.player_save_file
	if settings.has("options_save_file"): config.options_save_file = settings.options_save_file
	# if settings.has("proxy_url"): proxy.proxy_url = settings.proxy_url

func start_hosting(settings: Dictionary = {}):
	lm("start_hosting ", settings)
	configure(settings)
	start_server()
	start_discovery()

func stop_hosting(msg: String = "Game ended by host"):
	lm("stop_hosting ", msg)
	stop_discovery()
	server_disconnect_all_peers(msg)
	stop_server("Game ended by host; " + msg)	

func close_game_peer():
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

# Server Actions *******************************************************************

func start_server() -> void:
	var peer = setup_game_peer()
	var error = peer.create_server(config.game_port, config.max_players)
	if error != OK: return start_server_failed(error)
	multiplayer.multiplayer_peer = peer
	# TODO: update the lobby name somehow
	
	# manually signal because there's no built-in signal
	hosting_started.emit()
	me_connecting_to_lobby.emit()
	sync_players()

func update_me(data: Dictionary):
	me.merge(data, true)
	sync_players()

func sync_players():
	if not online(): return
	update_player_data.rpc_id(SERVER_ID, me)

@rpc("any_peer", "reliable", "call_local")
func update_player_data(player: Dictionary):
	if not i_am_host(): return
	var pid = sid()
	if not _host_players.has(pid): _host_players[pid] = {}
	# No change? skip
	if _host_players[pid].hash() == player.hash(): return
	# Merge the new data
	_host_players[pid].merge(player, true)
	_host_players[pid].id = pid
	# Sync to all _host_players

	host_sync_all_players()

func start_server_failed(error: int) -> void:
	close_game_peer()
	var msg = str(error)
	if error == ERR_CANT_CREATE: msg = "Is port %s already in use?" % config.game_port
	push_error("Error starting server (" + str(error) + "): " + msg)
	hosting_failed.emit(msg)

func stop_server(message: String):
	if not i_am_host(): return
	close_game_peer()
	me_left_lobby.emit(message)
	hosting_stopped.emit(message)

func server_disconnect_all_peers(reason: String = ""):
	if not i_am_host(): return
	for pid in multiplayer.get_peers(): server_disconnect_peer(pid, reason)

func server_disconnect_peer(pid: int, reason: String = "") -> void:
	if not i_am_host(): return
	if pid == SERVER_ID: return # can't disconnect the server; use stop_server instead
	if not pid_in_lobby(pid): return
	multiplayer.multiplayer_peer.disconnect_peer(pid)
	var p = find_by_pid(pid)
	if not p: return
	p.queue_free()

# Finds local ip addresses to tell clients to try to connect to if discovery fails
func get_ips() -> Array: return NetworkUtils.get_local_ipv4_addresses()

# Discovery server ***********************************************************************

func start_discovery() -> void:
	lm("start_discovery")
	if not i_am_host(): return
	if discovery_server.is_bound(): discovery_server.close()
	var result = discovery_server.bind(config.broadcast_port)
	if result != OK:
		lm("Lobby: Discovery server failed to bind: ", result, " on port ", config.broadcast_port)
		discovery_server_failed.emit(result)
		return
	set_process(true) # start listening for pings
	discovery_server_started.emit()

func stop_discovery():
	lm("stop_discovery")
	if not discovery_server.is_bound(): return
	set_process(false)
	discovery_server.close()
	discovery_server_stopped.emit()

func check_for_clients_discovery() -> void:
	if not discovery_server.is_bound(): return pe("Lobby: Discovery server not bound!")
	if discovery_server.get_available_packet_count() == 0: return

	var ping = {
		"data": discovery_server.get_packet().get_string_from_ascii(),
		"ip": discovery_server.get_packet_ip(),
		"port": discovery_server.get_packet_port()
	}
	if ping.data != refresh_packet(): return

	var response = {
		"game_name": game_name,
		"game_version": game_version,
		"lobby_name": config.lobby_name,
		"game_port": config.game_port,
		"players": player_count(),
		"max_players": config.max_players
	}
	var response_string = JSON.stringify(response)

	# lm("Sending response: ", response, " to ", ping.ip, ":", ping.port)
	discovery_server.set_dest_address(ping.ip, ping.port)
	discovery_server.put_packet(response_string.to_ascii_buffer())

# Client Actions *******************************************************************

func host_sync_all_players():
	if not i_am_host(): return
	sync_all_players.rpc(_host_players)

@rpc("authority", "reliable", "call_local")
func sync_all_players(updated_players: Dictionary):

	# Track the active players so we can remove inactive ones
	var active_players: Array[int] = []
	
	# Process the updated (maybe) players
	for pid in updated_players:
		var new_player: Dictionary = updated_players[pid]
		active_players.append(pid)

		var is_new: bool = !players.has(pid)
		var is_updated: bool = !is_new and players[pid].hash() != new_player.hash()
		var is_me: bool = pid == id()
		var is_host: bool = pid == SERVER_ID
		
		# No change? skip
		if not is_new and not is_updated: continue
		
		# Update my data
		if is_me: me.merge(new_player, true)
		
		# someone else
		if is_new:
			players[pid] = {}
			players[pid].merge(new_player, true)
			if is_me: me_joined_lobby.emit(me)
			else: player_joined_lobby.emit(new_player)
		elif is_updated:
			players[pid].merge(new_player, true)
			if is_me: me_updated.emit(me)
			else: player_updated.emit(new_player)

	# Remove players that are no longer in the lobby
	for pid in players.keys():
		if not active_players.has(pid):
			if is_me: me_left_lobby.emit("Lobby player left")
			var p = players[pid]
			players.erase(pid)
			player_left_lobby.emit(p)

func refresh_packet() -> String:
	return "LOOKING-FOR-LOBBY"

# Refresh the list of local servers
func find_lobbies(callback: Callable = func(_lobbies: Dictionary, _error: String = ""): pass, retry = 0):
	lm("find_lobbies ", retry)
	# just in case, close the discovery server if it's already bound
	if discovery_server.is_bound(): discovery_server.close()
	
	refreshing = true
	found_lobbies.clear()

	# Bind to the port that servers will respond to with their information
	var error = discovery_server.bind(config.response_port)
	if error != OK:
		refreshing = false
		var error_msg = "Error binding client discovery broadcast: " + str(error)
		callback.call({}, error_msg)
		lobbies_refreshed.emit({}, error_msg)
		return
	
	discovery_server.set_broadcast_enabled(true)
	discovery_server.set_dest_address("255.255.255.255", config.broadcast_port)
	discovery_server.put_packet(refresh_packet().to_utf8_buffer())
	# lm("Sent refresh packet")

	await wait(0.2 * (retry + 1))
	
	while discovery_server.get_available_packet_count() > 0:
		var packet = discovery_server.get_packet()
		var decoded = packet.get_string_from_utf8()
		var ping = {
			"data": decoded,
			"ip": discovery_server.get_packet_ip(),
			"port": discovery_server.get_packet_port()
		}
		if ping.ip == "" or ping.data == refresh_packet(): continue

		var server_info_parsed = JSON.parse_string(ping.data)

		server_info_parsed["ip"] = ping.ip
		server_info_parsed["port"] = ping.port

		found_lobbies[ping.ip] = server_info_parsed
	
	discovery_server.close()
	refreshing = false

	# Refresh again up to 3 times, sometimes it takes a bit longer
	if found_lobbies.size() <= 0 and retry < 3:
		find_lobbies(callback, retry + 1)
	else:
		callback.call(found_lobbies, "")
		lobbies_refreshed.emit(found_lobbies, "")
		lm("found_lobbies: ", found_lobbies)

# Join a server by IP address and port
func join(lobby: Dictionary) -> void:
	if not lobby.has("ip") or not lobby.has("port"): return pe("Invalid lobby - ip and port are required", lobby)
	lm("Lobby.join: ", lobby)
	close_game_peer()
	var peer = setup_game_peer()
	var ip: String = str(lobby.ip)
	var port: int = int(str(lobby.get("game_port", lobby.port)))
	lm("ip: ", ip, " port: ", port)
	var error: Error = peer.create_client(ip, port)
	lm("error: ", error)
	if error != OK: return join_error(error)
	multiplayer.multiplayer_peer = peer

func join_error(error: int) -> void:
	lm("join_error: ", error)
	close_game_peer()
	me_left_lobby.emit("Failed to connect to lobby. Error code " + str(error))	

# Leave the current server
func leave(message: String = ""):
	if not online(): return
	if i_am_host(): return stop_hosting(message)
	close_game_peer()

# Easy async way to talk to other players!
func on_ask(req_name: String, callback: Callable = request.no_op): request.on_ask(req_name, callback)
func remove_on_ask(req_name: String): request.remove_on_ask(req_name)
func ask(pid: int, req_name: String, data: Dictionary) -> Variant: return await request.ask(pid, req_name, data)
func broadcast(req_name: String, data: Dictionary = {}) -> void: request.broadcast(req_name, data)

# Chat methods *******************************************************************

func send_chat(message: String):
	if not online(): return send_system_chat(message)
	
	# Send to host, who will then broadcast to all clients
	host_send_chat.rpc_id(SERVER_ID, message)

@rpc("any_peer", "reliable", "call_local")
func host_send_chat(message: String):
	if not i_am_host(): return

	var sender_id = sid()
	if sender_id == 0: sender_id = id()

	# We are the host, so add the message to our list and broadcast the list to all clients
	add_chat(message, sender_id)

	# Sort the chat messages by timestamp
	chat_messages.sort_custom(func(a, b): return a.get("ts") < b.get("ts"))

	broadcast_chat_messages()
	chat_messages_updated.emit() # for us

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
	if not i_am_host(): return
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

func player_ids() -> Array[int]:
	if not online(): return []
	var ids: Array[int] = [SERVER_ID]
	for pid in multiplayer.get_peers(): if not ids.has(pid): ids.append(pid)
	return ids

func player_count() -> int:
	if not online(): return 0
	return player_ids().size()

func find_by_pid(pid: int):
	if pid == 0: return me
	return players.get(pid, null)

# Getting state *******************************************************************

func id() -> int:
	if not online(): return 0
	return multiplayer.multiplayer_peer.get_unique_id()

# Returns the status of the multiplayer peer (or a specific peer, if you don't give one)
# Returns: "Offline", "Disconnected", "Connecting", "Connected", "Hosting"
func status(peer: MultiplayerPeer = null) -> StringName:
	if not peer and not multiplayer: return &"Offline"
	if peer == null: peer = multiplayer.multiplayer_peer
	if peer is not ENetMultiplayerPeer: return &"Offline"
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED: return &"Disconnected"
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING: return &"Connecting"
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		# check if peer is server by checking if it has a host object
		# if multiplayer and multiplayer.multiplayer_peer and multiplayer.multiplayer_peer == peer and multiplayer.is_server(): return &"Hosting"
		print(" xxx ", peer.host.get_peers())
		# if peer.host and peer.host.get_peers().has(id()): return &"Server"
		return &"Connected"
	return &"Unknown"

func sid() -> int: return multiplayer.get_remote_sender_id()

func online() -> bool: return status() == &"Connected" or status() == &"Hosting"
func pid_in_lobby(pid: int) -> bool: return online() and (pid == SERVER_ID or multiplayer.get_peers().has(pid))
func i_am_host() -> bool: return status() == &"Hosting"
func is_client() -> bool: return status() == &"Connected"
func is_authority(node: Node) -> bool: return online() and node.is_multiplayer_authority()
func is_me(p: Dictionary) -> bool: return p and me.id == p.id

# Signal Handlers ***************************************************************

func _on_connection_succeeded():
	lm("_on_connection_succeeded")
	# var pid = id()
	me_connecting_to_lobby.emit()
	# Tell the server who I am
	sync_players()

func _on_connection_failed(reason: String = ""):
	lm("_on_connection_failed: ", reason)
	me_left_lobby.emit(reason)

func _on_connection_ended(reason: String = ""):
	lm("_on_connection_ended: ", reason)
	# Per: https://github.com/godotengine/godot/issues/77723#issuecomment-1830689802
	close_game_peer()
	me_left_lobby.emit(reason)
	
func _on_server_started(): hosting_started.emit()
func _on_server_failed(message: String): hosting_failed.emit(message)

# This is called when any remote peer connects to my multiplayer peer
# It's less useful than other signals.
func _on_remote_peer_connected(pid: int):
	lm("_on_remote_peer_connected: ", pid)
	if pid == SERVER_ID:
		# I joined a server
		lm(" - _on_remote_peer_connected: ", pid)
		me_connecting_to_lobby.emit()
	else:
		assert(i_am_host(), JamminErrors.REMOTE_PEER_NOT_HOST)
		# # Someone else remote to my server is joining_lobby
		# player_connecting_to_lobby.emit(pid)

func _on_remote_peer_disconnected(pid: int, reason: String = ""):
	lm("_on_remote_peer_disconnected: ", pid, " " + reason)
	if pid == SERVER_ID: leave("Host disconnected")
	var p = find_by_pid(pid)
	if not p: return
	player_left_lobby.emit(p) # TODO: Does this really need to be here?
	if i_am_host():
		_host_players.erase(pid)
		host_sync_all_players()

func _on_peer_connected(pid: int):
	lm("_on_peer_connected: ", pid)
	player_connecting_to_lobby.emit(pid)
	lm("player_connecting_to_lobby.emit: ", pid)

func _on_peer_disconnected(pid: int):
	lm("_on_peer_disconnected: ", pid)
	var p = find_by_pid(pid)
	if not p: return
	p.stop_sync()
	p.is_ready = false
	if i_am_host() and not is_me(p): p.queue_free()
	player_left_lobby.emit(p)

# Endpoints ***************************************************************
