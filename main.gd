class_name Main extends Node3D

static var menu: JamminLobbyUI

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# menu = get_node("JamminLobbyUI")
	
	# Let's figure out multiplayer lifecycles!
	
	multiplayer.peer_connected.connect(_mp_callback.bind("peer_connected"))
	multiplayer.peer_disconnected.connect(_mp_callback.bind("peer_disconnected"))
	multiplayer.server_disconnected.connect(_mp_callback.bind("server_disconnected"))
	multiplayer.connected_to_server.connect(_mp_callback.bind("connected_to_server"))
	multiplayer.connection_failed.connect(_mp_callback.bind("connection_failed"))
	multiplayer.peer_packet.connect(_mp_callback.bind("peer_packet"))
	multiplayer.peer_authenticating.connect(_mp_callback.bind("peer_authenticating"))
	multiplayer.peer_authentication_failed.connect(_mp_callback.bind("peer_authentication_failed"))

	multiplayer.multiplayer_peer.peer_connected.connect(_mp_callback.bind("peer_connected"))
	multiplayer.multiplayer_peer.peer_disconnected.connect(_mp_callback.bind("peer_disconnected"))

	lg(str(multiplayer.get_unique_id()))
	lg(str(multiplayer.multiplayer_peer.get_connection_status()))
	multiplayer.multiplayer_peer = null
	lg(str(get_multiplayer_authority()))

	# var peer = ENetMultiplayerPeer.new()

	# peer.peer_connected.connect(_mp_callback.bind("peer_connected"))
	# peer.peer_disconnected.connect(_mp_callback.bind("peer_disconnected"))
	
	# var peer2 = ENetMultiplayerPeer.new()

	# peer2.peer_connected.connect(_mp_callback.bind("peer2_connected"))
	# peer2.peer_disconnected.connect(_mp_callback.bind("peer2_disconnected"))

	# # I'll run the server on macos and connect to it from my windows machine manually.
	# var err = peer.create_server(12345, 8)
	# if err != OK:
	# 	lg("🔴 ERROR: " + str(err))
	# else:
	# 	lg(str(peer.get_unique_id()))
	
	# var err2 = peer2.create_server(12345)
	# if err2 != OK:
	# 	lg("🔴 ERROR: " + str(err2))
	# 	if err2 == ERR_CANT_CREATE:
	# 		lg("peer2: ")
	# else:
	# 	lg(str(peer2.get_unique_id()))

	# multiplayer.multiplayer_peer = peer

func _mp_callback(event: String, a: Variant, b: Variant, c: Variant, d: Variant) -> void:
	lg(event + " - " + str(a) + "; " + str(b) + "; " + str(c) + "; " + str(d))

func lg(message: String) -> void:
	if multiplayer.is_server():
		print("🔵 SERVER: " + message)
	else:
		if multiplayer and multiplayer.multiplayer_peer:
			# get the client ID
			var client_id = multiplayer.get_unique_id()
			print("🟢 CLIENT: " + message + " (id: " + str(client_id) + ")")
		else:
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
