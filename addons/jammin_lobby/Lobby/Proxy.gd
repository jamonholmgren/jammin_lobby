class_name JamminProxy extends Node

signal connected
signal disconnected
signal message_received(data: Dictionary)

signal proxy_authenticated
signal proxy_connected
signal proxy_disconnected

var socket := WebSocketPeer.new()
@export var proxy_url := "" # usually soemthing like "ws://localhost:7000"
var username := ""
var client_id := 0

func is_enabled() -> bool: return not proxy_url.is_empty()
func is_proxy_active() -> bool: return is_enabled() and socket.get_ready_state() == WebSocketPeer.STATE_OPEN

func setup_proxy_routing():
	# Intercept outgoing packets
	multiplayer.multiplayer_peer.peer_packet.connect(func(packet): if is_proxy_active(): send_packet(packet))

	# Forward incoming proxy packets to ENet
	socket.message.connect(func(packet): if multiplayer.multiplayer_peer: multiplayer.multiplayer_peer.put_packet(packet))

func connect_to_proxy():
	var auth = username + ":" + username # TODO: Use actual password
	var headers := PackedStringArray([ "Authorization: Basic " + Marshalls.utf8_to_base64(auth) ])
	
	# First authenticate
	var result = await fetch_auth()
	if not result: return false
		
	client_id = result.client_id
	
	# Now connect WebSocket
	socket.connect_to_url(proxy_url + "/ws")
	return true

func fetch_auth():
	var http = HTTPClient.new()
	# Do auth request, return client_id
	# TODO: Implement this
	pass

func _process(_delta):
	socket.poll()
	var state = socket.get_ready_state()
	
	match state:
		WebSocketPeer.STATE_OPEN:
			while socket.get_available_packet_count():
				var packet = socket.get_packet()
				# Forward packet to ENet
				if packet.size() > 10: multiplayer.multiplayer_peer.put_packet(packet)
		
		WebSocketPeer.STATE_CLOSING:
			pass
				
		WebSocketPeer.STATE_CLOSED:
			proxy_disconnected.emit()
			set_process(false)

# Forward ENet packets to proxy
func send_packet(packet: PackedByteArray):
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN: return
	socket.send(packet)

# Original packet format
func create_proxy_packet(type_byte: int, channel: int, from_id: int, to_id: int, data: PackedByteArray) -> PackedByteArray:
	var packet := PackedByteArray()
	packet.resize(10 + data.size())
	packet[0] = type_byte # reliable vs unreliable
	packet[1] = channel
	packet.encode_u32(2, from_id)
	packet.encode_u32(6, to_id) 
	packet.append_array(data)
	return packet

func _on_enet_packet(packet: PackedByteArray):
	# Forward to proxy
	socket.send(packet)

func _on_proxy_packet(packet: PackedByteArray):
	# Forward to ENet
	multiplayer.multiplayer_peer.put_packet(packet)

func connect_proxy(username: String) -> bool:
	var auth_result = await do_auth(username)
	if not auth_result or not auth_result.has("client_id"): return false
			
	client_id = auth_result.client_id
	var err = socket.connect_to_url(proxy_url + "/ws?id=" + str(client_id))
	if err != OK: return false
			
	proxy_authenticated.emit()
	return true

func do_auth(username: String) -> Dictionary:
	var http = HTTPClient.new()
	var err = http.connect_to_host(proxy_url.split("://")[1], 7000)
	if err != OK: return {}
			
	while http.get_status() == HTTPClient.STATUS_CONNECTING:
		http.poll()
		await get_tree().process_frame
			
	if http.get_status() != HTTPClient.STATUS_CONNECTED: return {}

	var auth = username + ":" + username
	var headers = [ "Authorization: Basic " + Marshalls.utf8_to_base64(auth) ]
	
	err = http.request(HTTPClient.METHOD_POST, "/auth", headers)
	if err != OK: return {}
			
	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		await get_tree().process_frame
		
	if http.get_status() != HTTPClient.STATUS_BODY: return {}

	var response = http.read_response_body_chunk()
	return JSON.parse_string(response.get_string_from_utf8())

# TODO: figure out where to put this code

# static var instance: JamminProxy

# static func setup_proxy(base_node: Node, options: Dictionary):
# 	instance = JamminProxy.new()
# 	base_node.add_child(instance)
# 	instance.proxy_authenticated.connect(options["proxy_authenticated"])
# 	instance.proxy_connected.connect(options["proxy_connected"]) 
# 	instance.proxy_disconnected.connect(options["proxy_disconnected"])

# func _on_proxy_authenticated():
# 	# Continue with normal lobby join flow
# 	pass

# func _on_proxy_connected():
# 	# Forward ENet packets to proxy
# 	multiplayer.multiplayer_peer.connect("peer_packet", proxy.send_packet)

# func _on_proxy_disconnected():
# 	# TODO: Handle proxy disconnection
# 	pass

