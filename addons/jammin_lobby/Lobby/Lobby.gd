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

# Signals for the lobby host only
signal hosting_started()
signal hosting_failed(message: String)
signal hosting_stopped(message: String)

# Signals for the discovery server
signal discovery_server_started()
signal discovery_server_failed(error: int)
signal discovery_server_stopped()
signal lobbies_refreshed(lobbies: Dictionary)

# Signals for the ping
signal ping_updated(ping: int)

# Signals for the chat messages
signal chat_messages_updated()

# Signals for the host to trigger via 
signal game_event(command: String)

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
	"host": false,
	"ping": 0
}

# This is a dictionary of all players in the lobby
# The key is the player ID, and the value is a dictionary of player data
# You can access player data with `Lobby.get_player(player_id)`
var players: Dictionary = {}
var _host_players: Dictionary = {}

# Local copy of my player data, which gets updated as you join/leave lobbies
# Don't update this directly; use `Lobby.update_me({ ... })` instead
var me: Dictionary

var found_lobbies: Dictionary = {}
var refreshing := false
var ping_start: int = 0

# Lifecycle ***********************************************************************

func _ready() -> void:
	debug = true
	me = {}
	me.merge(DEFAULT_PLAYER_DATA, true)
	Options.restore()
	if Options.data.has("player-" + str(save_slot)):
		var restored_data = Options.data["player-" + str(save_slot)]
		var restored_data_keys = restored_data.keys()
		restored_data_keys.sort()
		for key in restored_data_keys:
			me[key] = restored_data[key]
		# Reset some values that shouldn't be persisted
		me.merge({ "ready": false, "in_lobby": false, "host": false }, true)

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

	# This fires on a client only when connecting to a server (no args)
	cs(multiplayer, "connected_to_server", _on_connection_succeeded)

	# This fires on a client only when a join() connection failed (no args)
	cs(multiplayer, "connection_failed", _on_connection_failed)

	# This fires on a client only when the server disconnects 
	cs(multiplayer, "server_disconnected", _on_connection_ended)
	
	# This fires for every single peer that connects
	cs(multiplayer, "peer_connected", _on_any_peer_connected)

	# This fires for every single peer that disconnects
	cs(multiplayer, "peer_disconnected", _on_any_peer_disconnected)

	# peer_packet
	# peer_authenticating
	# peer_authentication_failed

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

	# Server: fires once when a new peer connects
	# Client: only fires once when connected to server
	#   (similar to connected_to_server)
	cs(new_game_peer, "peer_connected", _on_peer_connected)

	# Server: fires when any peer disconnects
	# Client: fires when the server disconnects
	#   (similar to server_disconnected)
	cs(new_game_peer, "peer_disconnected", _on_peer_disconnected)
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
	update_me({ "host": false, "in_lobby": false })
	
	if multiplayer.multiplayer_peer and multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	
	# We set to OfflineMultiplayerPeer rather than to null.
	# This prevents errors like "No multiplayer peer is assigned"
	# that happen when you access things like get_multiplayer_authority()
	# Ref: https://github.com/godotengine/godot/issues/77723#issuecomment-1830689802
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

# Server Actions *******************************************************************

func start_server() -> void:
	var peer = setup_game_peer()
	var error = peer.create_server(config.game_port, config.max_players)
	if error != OK: return start_server_failed(error)
	
	# Set the peer - no built-in signals are emitted when starting a server
	# We manually emit our own signals
	multiplayer.multiplayer_peer = peer
	
	# Manually signal because Godot doesn't provide signals for server start
	update_me({ "host": true, "in_lobby": true })
	hosting_started.emit()
	me_connecting_to_lobby.emit()
	sync_me_with_host()

func update_me(changes: Dictionary):
	# Has anything changed?
	if FileUtils.is_subset(changes, me): return

	me.merge(changes, true)
	Options.set("player-" + str(save_slot), me)
	me_updated.emit(me)
	sync_me_with_host()

func sync_me_with_host():
	if not online(): return
	update_player_data.rpc_id(SERVER_ID, me)

@rpc("any_peer", "reliable", "call_local")
func update_player_data(player: Dictionary):
	if not i_am_host(): return

	var pid = sender_id()
	if not _host_players.has(pid): _host_players[pid] = {}
	
	# No change? skip
	if FileUtils.is_eq(_host_players[pid], player): return
	
	# Merge the new data
	_host_players[pid].merge(player, true)
	_host_players[pid].id = pid
	
	# Tell all connected peers (including ourselves) about all players
	update_players_from_host.rpc(_host_players)

func start_server_failed(error: int) -> void:
	close_game_peer()
	var msg = str(error)
	if error == ERR_CANT_CREATE: msg = "Is port %s already in use?" % config.game_port
	push_error("Error starting server (" + str(error) + "): " + msg)
	update_me({ "host": false, "in_lobby": false })
	hosting_failed.emit(msg)

func stop_server(message: String):
	if not i_am_host(): return
	close_game_peer()
	update_me({ "host": false, "in_lobby": false })
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
	set_process(true) # start listening for requests
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

	var req = {
		"data": discovery_server.get_packet().get_string_from_ascii(),
		"ip": discovery_server.get_packet_ip(),
		"port": discovery_server.get_packet_port()
	}
	if req.data != refresh_packet(): return

	var response = {
		"game_name": game_name,
		"game_version": game_version,
		"lobby_name": config.lobby_name,
		"game_port": config.game_port,
		"players": player_count(),
		"max_players": config.max_players
	}
	var response_string = JSON.stringify(response)

	discovery_server.set_dest_address(req.ip, req.port)
	discovery_server.put_packet(response_string.to_ascii_buffer())

# Client Actions *******************************************************************

# This is called by the host to make sure all clients have the same player data
@rpc("authority", "reliable", "call_local")
func update_players_from_host(updated_players: Dictionary):
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
		if is_me: update_me(new_player)
		
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
		var req = {
			"data": decoded,
			"ip": discovery_server.get_packet_ip(),
			"port": discovery_server.get_packet_port()
		}
		if req.ip == "" or req.data == refresh_packet(): continue

		var server_info_parsed = JSON.parse_string(req.data)

		server_info_parsed["ip"] = req.ip
		server_info_parsed["port"] = req.port

		found_lobbies[req.ip] = server_info_parsed
	
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
	
	# Set the peer - this will eventually trigger:
	# 1. _on_peer_connected when connected to server (pid=1)
	# 2. _on_connection_succeeded when successfully connected
	# 3. _on_any_peer_connected for each existing peer
	# These will emit various signals like me_connecting_to_lobby and player_connecting_to_lobby
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

func send_game_event(command: String, data: Dictionary = {}) -> void:
	_send_game_event.rpc_id(sender_id(), command, data)

# The host can send to all clients "game events" via this signal.
# It's kind of an all-purpose communication signal.
@rpc("authority", "reliable", "call_local")
func _send_game_event(command: String, data: Dictionary = {}) -> void:
	if not sender_id() > 0: return pe("send_game_event should be sent via .rpc()")
	game_event.emit(command, data)

# Chat methods *******************************************************************

func send_chat(message: String):
	if not online(): return send_system_chat(message)
	
	# Send to host, who will then broadcast to all clients
	host_send_chat.rpc_id(SERVER_ID, message)

@rpc("any_peer", "reliable", "call_local")
func host_send_chat(message: String):
	if not i_am_host(): return

	var sender_id = sender_id()
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

func host_remove_by_pid(pid: int):
	if not i_am_host(): return
	if pid in _host_players:
		_host_players.erase(pid)
		# Tell all connected peers (including ourselves) about all players
		update_players_from_host.rpc(_host_players)

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
		if peer.get_unique_id() == SERVER_ID: return &"Hosting"
		
		# # This could be used, but tbh the above is reliable enough
		# # if paired with the ENetMultiplayerPeer type check above.
		# var p = multiplayer.multiplayer_peer
		# if peer == p and multiplayer.is_server(): return &"Hosting"
		
		return &"Connected"
	return &"Unknown"

func sender_id() -> int: return multiplayer.get_remote_sender_id()

func online() -> bool: return status() == &"Connected" or status() == &"Hosting"
func pid_in_lobby(pid: int) -> bool: return online() and (pid == SERVER_ID or multiplayer.get_peers().has(pid))
func i_am_host() -> bool: return status() == &"Hosting"
func is_client() -> bool: return status() == &"Connected"
func is_authority(node: Node) -> bool: return online() and node.is_multiplayer_authority()
func is_me(p: Dictionary) -> bool: return p and me.id == p.id

func update_ping() -> void:
	if not online(): return
	ping_start = Time.get_ticks_usec()
	ping_server.rpc_id(sender_id())

@rpc("any_peer", "reliable", "call_local")
func ping_server() -> void:
	pong_client.rpc_id(sender_id())

@rpc("any_peer", "reliable", "call_local")
func pong_client() -> void:
	if not ping_start: return

	# We divide by 2 because the ping is sent and received
	var new_ping = (Time.get_ticks_usec() - ping_start) / 2
	update_me({ "ping": new_ping })
	ping_start = 0
	ping_updated.emit(me.ping)

# Signal Handlers ***************************************************************

# When I connect to a lobby, I want to send
# my player data over there so it'll let me in.
func _on_connection_succeeded():
	lm("_on_connection_succeeded")
	me_connecting_to_lobby.emit()
	sync_me_with_host()

# We tried to join a lobby, but it failed for some reason.
# Only called on clients.
func _on_connection_failed(reason: String = ""):
	lm("_on_connection_failed: ", reason)
	me_left_lobby.emit(reason)

# We closed the connection or the server disconnected from us.
func _on_connection_ended(reason: String = ""):
	lm("_on_connection_ended: ", reason)
	close_game_peer()
	me_left_lobby.emit(reason)
	
func _on_server_started(): hosting_started.emit()
func _on_server_failed(message: String): hosting_failed.emit(message)

# This is called when a new remote peer connects to my multiplayer peer
# but only if I'm the server or they're the server
func _on_peer_connected(pid: int):
	lm("_on_peer_connected: ", pid)
	if pid == SERVER_ID:
		# I joined a server
		lm(" - _on_peer_connected: ", pid)
		me_connecting_to_lobby.emit()
		# This will update me as well as send my data to the host
		update_me({ "in_lobby": true })
	else:
		# I am the server and someone else is connecting to me
		# This shouldn't happen unless I'm the host
		assert(i_am_host(), JamminErrors.REMOTE_PEER_NOT_HOST)
		
# Server: Fires once per client that disconnects
# Client: Fires only if the server disconnects from us
func _on_peer_disconnected(pid: int, reason: String = ""):
	lm("_on_peer_disconnected: ", pid, " " + reason)

	# The server disconnected from us
	if pid == SERVER_ID:
		close_game_peer()
		me_left_lobby.emit("Host disconnected")
		return

	# OK, if we're the host, a client has disconnected from us
	host_remove_by_pid(pid)

# These are noisy and fire for every single peer that connects/disconnects
# - On the server, this fires once when a new peer connects
# - On a client, this fires for every peer already connected to the server (including the server)
# We are using it primarily to know when a client is starting to connect to
# the server. The client then will update us with its player data later.
func _on_any_peer_connected(pid: int):
	# - We mute this signal for anyone except the server
	if not i_am_host(): return
	player_connecting_to_lobby.emit(pid)

# - This fires on all clients when any peer disconnects, with the disconnected peer's ID
# - Way too noisy, but we do use it to know when a client is disconnecting from the server
# - and remove it from the host players list
func _on_any_peer_disconnected(pid: int):
	host_remove_by_pid(pid)
