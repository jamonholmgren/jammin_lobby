extends JamminBase

# autoload singleton called "Lobby" which is the core of the lobby system
# Use this class to interact with the lobby system from code

# Signals ***********************************************************************

# Signals for the local player
signal i_connecting_to_lobby()
signal i_joined_lobby(player: Dictionary)
signal i_failed_to_join_lobby(reason: String)
signal i_left_lobby(reason: String)
signal i_updated(player: Dictionary)
signal i_restored(player: Dictionary)

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

# Signals for the host to trigger via .rpc()
signal game_event(command: String, data: Dictionary)

# Configuration and subsystems *************************************************

static var config: JamminLobby = null

var discovery_server: PacketPeerUDP
@onready var request: JamminRequest = JamminRequest.new()
@onready var net: NetworkUtils = NetworkUtils.new()

# State *************************************************************************

enum Status { Offline, Disconnected, Connecting, Connected, Hosting, Unknown }

# This gets assigned to your player before you join a lobby
# You can adjust these values as needed and save your player
# to disk with `Lobby.save()`
const DEFAULT_PLAYER_DATA: Dictionary = {
	"id": 0,
	"username": "",
	"in_lobby": false,
	"host": false,
	"ready": false,
	"ping": 0
}

# Game name
var game_name: String = ProjectSettings.get_setting("application/config/name")

# Game version
var game_version: String = ProjectSettings.get_setting("application/config/version")

# Lobby chat messages
var chat_messages: Array[Dictionary] = []

# Optional save slot to use for the local player, to allow multiple users.
var save_slot: int = 1

# This is a dictionary of all players in the lobby
# The key is the player ID, and the value is a dictionary of player data
# You can access player data with `Lobby.players.get(player_id)`
var players: Dictionary = {}
var _host_players: Dictionary = {}

# Local copy of my player data, which gets updated as you join/leave lobbies
# Don't update this directly; use `Lobby.update_me({ ... })` instead
var me: Dictionary

# Lobbies we've discovered on the local network
var found_lobbies: Dictionary = {}

# Whether we're currently refreshing the list of lobbies
var refreshing := false

# Ping start time, for measuring ping
var ping_start: int = 0

# Lifecycle ***********************************************************************

func _ready() -> void:
	debug = true
	me = {}
	me.merge(DEFAULT_PLAYER_DATA, true)
	me.id = int(me.id)

	setup_multiplayer()
	setup_request()
	setup_network_utils()

func restore() -> void:
	Options.restore()
	if Options.data.has("player-" + str(save_slot)):
		var restored_data = Options.data["player-" + str(save_slot)]
		var restored_data_keys = restored_data.keys()
		restored_data_keys.sort()
		for key in restored_data_keys:
			me[key] = restored_data[key]
		# Reset some values that shouldn't be persisted
		me.merge({ "ready": false, "in_lobby": false, "host": false }, true)
		i_restored.emit.call_deferred(me)

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
	request.name = "Request"
	add_child(request)

func setup_network_utils():
	net = NetworkUtils.new()
	net.name = "NetworkUtils"
	add_child(net)

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
	if not config:
		config = JamminLobby.new()
		add_child(config)
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

func start_hosting(settings: Dictionary = {}):
	lm("start_hosting ", settings)
	configure(settings)
	start_server()
	start_discovery()

func stop_hosting(msg: String = "Game ended by host"):
	lm("stop_hosting ", msg)
	stop_discovery()
	_server_disconnect_all_peers(msg)
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
	hosting_started.emit.call_deferred()
	i_connecting_to_lobby.emit.call_deferred()
	sync_me_with_host.call_deferred()

func update_me(changes: Dictionary):
	# Has anything changed?
	if FileUtils.is_subset(changes, me): return

	me.merge(changes, true)
	Options.set("player-" + str(save_slot), me)
	# have to call manually because `me` is the same object, often, and won't get detected as changed
	Options.autosave()
	i_updated.emit.call_deferred(me)
	sync_me_with_host.call_deferred()

func sync_me_with_host():
	if not online(): return
	# lm("sync_me_with_host", online(), multiplayer.get_peers())
	update_player_data.rpc_id(host_id(), me)

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
	hosting_failed.emit.call_deferred(msg)

func stop_server(message: String):
	if not i_am_host(): return
	close_game_peer()
	update_me({ "host": false, "in_lobby": false })
	i_left_lobby.emit.call_deferred(message)
	hosting_stopped.emit.call_deferred(message)

func _server_disconnect_all_peers(reason: String = ""):
	if not i_am_host(): return
	for pid in multiplayer.get_peers(): _server_disconnect_peer(pid, reason)

func _server_disconnect_peer(pid: int, reason: String = "") -> void:
	if not i_am_host(): return
	if pid == host_id(): return # can't disconnect the server; use stop_server instead
	if not pid_in_lobby(pid): return
	multiplayer.multiplayer_peer.disconnect_peer(pid)
	if not _host_players.has(pid): return
	_host_players.erase(pid)
	update_players_from_host.rpc(_host_players)

# Finds local ip addresses to tell clients to try to connect to if discovery fails
func get_ips() -> Array: return net.get_local_ipv4_addresses()

# Discovery server ***********************************************************************

func start_discovery() -> void:
	lm("start_discovery")
	if not i_am_host(): return
	if discovery_server.is_bound(): discovery_server.close()
	var result = discovery_server.bind(config.broadcast_port)
	if result != OK:
		lm("Lobby: Discovery server failed to bind: ", result, " on port ", config.broadcast_port)
		discovery_server_failed.emit.call_deferred(result)
		return
	set_process(true) # start listening for requests
	discovery_server_started.emit.call_deferred()

func stop_discovery():
	lm("stop_discovery")
	if not discovery_server.is_bound(): return
	set_process(false)
	discovery_server.close()
	discovery_server_stopped.emit.call_deferred()

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
		pid = int(pid)
		var new_player: Dictionary = updated_players[pid]
		active_players.append(pid)

		var is_new: bool = !players.has(pid)
		var is_updated: bool = !is_new and players[pid].hash() != new_player.hash()
		var is_me: bool = pid == id()
		
		# No change? skip
		if not is_new and not is_updated: continue

		# Update my data
		if is_me: update_me(new_player)
		
		# someone else
		if is_new:
			players[pid] = {}
			players[pid].merge(new_player, true)
			players[pid].id = pid
			if is_me: i_joined_lobby.emit.call_deferred(players[pid])
			else: player_joined_lobby.emit.call_deferred(players[pid])
		elif is_updated:
			players[pid].merge(new_player, true)
			if is_me: i_updated.emit.call_deferred(me)
			else: player_updated.emit.call_deferred(new_player)

	# Remove players that are no longer in the lobby
	for pid in players.keys():
		if not active_players.has(pid):
			if is_me: i_left_lobby.emit.call_deferred("Lobby player left")
			var p = players[pid]
			players.erase(pid)
			player_left_lobby.emit.call_deferred(p)

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
		lobbies_refreshed.emit.call_deferred({}, error_msg)
		return
	
	discovery_server.set_broadcast_enabled(true)
	discovery_server.set_dest_address("255.255.255.255", config.broadcast_port)
	discovery_server.put_packet(refresh_packet().to_utf8_buffer())
	lm("Sent refresh packet")

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
		lobbies_refreshed.emit.call_deferred(found_lobbies, "")
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
	# These will emit various signals like i_connecting_to_lobby and player_connecting_to_lobby
	multiplayer.multiplayer_peer = peer

func join_error(error: int) -> void:
	lm("join_error: ", error)
	close_game_peer()
	i_failed_to_join_lobby.emit.call_deferred("Failed to connect to lobby. Error code " + str(error))	

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
	game_event.emit.call_deferred(command, data)

# Chat methods *******************************************************************

func send_chat(message: String):
	if not online(): return send_system_chat(message)
	
	# Send to host, who will then broadcast to all clients
	host_send_chat.rpc_id(host_id(), message)

@rpc("any_peer", "reliable", "call_local")
func host_send_chat(message: String):
	if not i_am_host(): return

	var sid = sender_id()
	if sid == 0: sid = id()

	# We are the host, so add the message to our list and broadcast the list to all clients
	add_chat(message, sid)

	# Sort the chat messages by timestamp
	chat_messages.sort_custom(func(a, b): return a.get("ts") < b.get("ts"))

	broadcast_chat_messages()
	chat_messages_updated.emit.call_deferred() # for us

# System messages are local only, and aren't broadcast to other clients
func send_system_chat(message: String):
	add_chat(message, 0, "system")
	chat_messages_updated.emit.call_deferred()
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
	chat_messages_updated.emit.call_deferred()

# Player methods *******************************************************************

func player_ids() -> Array[int]:
	if not online(): return []
	var ids: Array[int] = [host_id()]
	for pid in multiplayer.get_peers(): if not ids.has(pid): ids.append(pid)
	return ids

func player_count() -> int:
	if not online(): return 0
	return player_ids().size()

func player_id_valid(pid: int) -> bool:
	return player_ids().has(pid)

# Can't type the return type since it can return null
func find_by_pid(pid: int): # -> Dictionary | null
	if pid == 0 and offline(): return me
	return players.get(pid, null)

func host_remove_by_pid(pid: int):
	if not online(): return
	if not i_am_host(): return
	if pid in _host_players:
		_host_players.erase(pid)
		# Tell all connected peers (including ourselves) about all players
		update_players_from_host.rpc(_host_players)

# Getting state *******************************************************************

func id() -> int:
	if not online(): return 0
	return multiplayer.multiplayer_peer.get_unique_id()

func host_id() -> int:
	if not online(): return 0
	return multiplayer.multiplayer_peer.TARGET_PEER_SERVER

# Returns the status of the multiplayer peer (or a specific peer, if you don't give one)
# Returns: Status.Offline, Status.Disconnected, Status.Connecting, Status.Connected, Status.Hosting, Status.Unknown
func status(peer: MultiplayerPeer = null) -> Status:
	if not peer and not multiplayer: return Status.Offline
	if peer == null: peer = multiplayer.multiplayer_peer
	if peer is not ENetMultiplayerPeer: return Status.Offline
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED: return Status.Disconnected
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING: return Status.Connecting
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		# Don't use host_id() because it's recursive and calls this
		var server_id: int = multiplayer.multiplayer_peer.TARGET_PEER_SERVER
		if peer.get_unique_id() == server_id: return Status.Hosting
		return Status.Connected
	return Status.Unknown

func sender_id() -> int: return multiplayer.get_remote_sender_id() if online() else 0

func online() -> bool: return status() == Status.Connected or status() == Status.Hosting
func offline() -> bool: return not online()

func pid_in_lobby(pid: int) -> bool: return online() and (pid == host_id() or multiplayer.get_peers().has(pid))
func i_am_host() -> bool: return status() == Status.Hosting
func is_client() -> bool: return status() == Status.Connected
func is_authority(node: Node) -> bool: return online() and node.is_multiplayer_authority()
func is_me(p: Dictionary) -> bool: return p and me.id == p.id
func is_host(p: Dictionary) -> bool: return p and p.host

func sender_is_host() -> bool: return sender_id() == host_id()
func sender_is_me() -> bool: return sender_id() == id()

func set_authority(node: Node, pid: int) -> void:
	if not online(): return
	node.set_multiplayer_authority(pid)

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
	ping_updated.emit.call_deferred(me.ping)

# Signal Handlers ***************************************************************

# When I connect to a lobby, I want to send
# my player data over there so it'll let me in.
func _on_connection_succeeded():
	lm("_on_connection_succeeded")
	i_connecting_to_lobby.emit.call_deferred()
	sync_me_with_host.call_deferred()

# We tried to join a lobby, but it failed for some reason.
# Only called on clients.
func _on_connection_failed(reason: String = ""):
	lm("_on_connection_failed: ", reason)
	i_failed_to_join_lobby.emit.call_deferred(reason)

# We closed the connection or the server disconnected from us.
func _on_connection_ended(reason: String = ""):
	lm("_on_connection_ended: ", reason)
	close_game_peer()
	i_left_lobby.emit.call_deferred(reason)
	
func _on_server_started(): hosting_started.emit.call_deferred()
func _on_server_failed(message: String): hosting_failed.emit.call_deferred(message)

# This is called when a new remote peer connects to my multiplayer peer
# but only if I'm the server or they're the server
func _on_peer_connected(pid: int):
	lm("_on_peer_connected: ", pid)
	if pid == host_id():
		# I joined a server
		lm(" - _on_peer_connected: ", pid)
		i_connecting_to_lobby.emit.call_deferred()
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
	if pid == host_id():
		close_game_peer()
		i_left_lobby.emit.call_deferred("Host disconnected")
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
	player_connecting_to_lobby.emit.call_deferred(pid)

# - This fires on all clients when any peer disconnects, with the disconnected peer's ID
# - Way too noisy, but we do use it to know when a client is disconnecting from the server
# - and remove it from the host players list
func _on_any_peer_disconnected(pid: int):
	host_remove_by_pid(pid)

# Pass-through methods ***********************************************************

func get_local_ipv4_addresses() -> Array[String]: return net.get_local_ipv4_addresses()
func get_external_ip() -> NetworkUtils.Result: return await net.get_external_ip()
func get_router_ip() -> NetworkUtils.Result: return net.get_router_ip()
func is_good_address(address: String) -> bool: return net.is_good_address(address)

var lobby_name: String:
	get: return config.lobby_name
	set(v): config.lobby_name = v

var game_port: int:
	get: return config.game_port
	set(v): config.game_port = v

var broadcast_port: int:
	get: return config.broadcast_port
	set(v): config.broadcast_port = v

var response_port: int:
	get: return config.response_port
	set(v): config.response_port = v

var max_players:
	get: return config.max_players
	set(v): config.max_players = v

var connection_timeout: int:
	get: return config.connection_timeout
	set(v): config.connection_timeout = v

var player_script: String:
	get: return config.player_script
	set(v): config.player_script = v

var player_scene: String:
	get: return config.player_scene
	set(v): config.player_scene = v

var autosave: bool:
	get: return config.autosave
	set(v): config.autosave = v
