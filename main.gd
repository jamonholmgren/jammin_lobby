class_name Main extends Node3D

static var menu: JamminLobbyUI

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# menu = get_node("JamminLobbyUI")
	
	# Let's figure out multiplayer lifecycles!

	var os = OS.get_name()

	print(Lobby.get_ips())

	multiplayer.peer_connected.connect(_mp_callback.bind("@mp: peer_connected"))
	multiplayer.peer_disconnected.connect(_mp_callback.bind("@mp: peer_disconnected"))
	multiplayer.server_disconnected.connect(_mp_callback.bind("@mp: server_disconnected"))
	multiplayer.connected_to_server.connect(_mp_callback.bind("@mp: connected_to_server"))
	multiplayer.connection_failed.connect(_mp_callback.bind("@mp: connection_failed"))
	multiplayer.peer_packet.connect(_mp_callback.bind("@mp: peer_packet"))
	multiplayer.peer_authenticating.connect(func(peer_id: int):
		print("  WOW   peer authenticating: " + str(peer_id))
		if Lobby.status() == &"Hosting":
			multiplayer.send_auth(peer_id, "Give me the secret".to_utf8_buffer())
	)
	multiplayer.peer_authentication_failed.connect(_mp_callback.bind("@mp: peer_authentication_failed"))

	if os == "Windows":
		create_client("10.0.0.116", 12345)
	else:
		create_server(12345)

func create_server(port: int) -> void:
	multiplayer.set_auth_callback(func(_peer_id: int, secret: String) -> bool:
		lg("server auth callback: " + str(_peer_id) + " " + secret)
		return secret == "Jamon"
	)
	
	var peer := ENetMultiplayerPeer.new()

	peer.peer_connected.connect(_mp_callback.bind("@server: peer_connected"))
	peer.peer_disconnected.connect(_mp_callback.bind("@server: peer_disconnected"))

	# I'll run the server on macos and connect to it from my windows machine manually.
	var err = peer.create_server(port, 8)
	if err != OK:
		lg("🔴 ERROR: " + str(err))
	else:
		lg("Created server with id: " + str(peer.get_unique_id()))
	
	multiplayer.multiplayer_peer = peer

func create_client(ip: String, port: int) -> void:
	var client = ENetMultiplayerPeer.new()
	multiplayer.set_auth_callback(func(_peer_id: int, secret: String) -> bool:
		lg("client auth callback: " + str(_peer_id) + " " + secret)
		return secret == "Jamon"
	)
	var err = client.create_client(ip, port)
	if err != OK:
		lg("🔴 ERROR: " + str(err))
	else:
		lg("🟢 Connecting to server at " + ip + ":" + str(port))

	client.peer_connected.connect(_mp_callback.bind("@client: peer_connected"))
	client.peer_disconnected.connect(_mp_callback.bind("@client: peer_disconnected"))

	multiplayer.multiplayer_peer = client


func _mp_callback(first: Variant, a: Variant = null, b: Variant = null, c: Variant = null, d: Variant = null) -> void:
	var pid = multiplayer.get_unique_id() if Lobby.online() else 0
	var sid = multiplayer.get_remote_sender_id()
	lg("pid: " + str(pid) + "; sid: " + str(sid) + "; " + str(first) + "; " + str(a) + "; " + str(b) + "; " + str(c) + "; " + str(d))

func lg(message: String) -> void:
	match Lobby.status():
		&"Hosting":
			print("🔵 SERVER: " + message)
		&"Connected":
			# get the client ID
			var client_id = multiplayer.get_unique_id()
			print("🟢 CLIENT: " + message + " (id: " + str(client_id) + ")")
		_:
			print("🟢 CLIENT: " + message)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if menu.visible:
			hide_menu()
		else:
			show_menu()

func show_menu() -> void:
	menu.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func hide_menu() -> void:
	menu.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
