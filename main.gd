class_name Main extends Node3D

static var menu: JamminLobbyUI
static var level: Node3D
static var hud: Control

const USER_NAMES = [ "Chainsaw", "Hammer", "Axe", "Crusher", "Dumptruck", "Volcano", "Thunder" ]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	menu = get_node("JamminLobbyUI")
	level = get_node("Level")
	hud = get_node("HUD")
	Lobby.game_event.connect(_on_game_event)
	Lobby.restore()
	%StartOfflineGame.pressed.connect(start_game)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if menu.visible:
			hide_menu()
		else:
			show_menu()

func show_menu() -> void:
	menu.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.hide()

func hide_menu() -> void:
	menu.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.show()

func _on_game_event(command: String, _data: Dictionary = {}) -> void:
	if command == "start_game": start_game()

func start_game() -> void:
	Game.status = &"Game"
	spawn_tank_random.rpc_id(Lobby.host_id())
	hide_menu()

@rpc("reliable", "any_peer", "call_local")
func spawn_tank_random() -> void:
	if Lobby.online() and not Lobby.i_am_host(): return

	# Who's asking?
	var sender_id = Lobby.sender_id()

	# Pick a random place to spawn my tank
	var spawn_points = get_tree().get_nodes_in_group("spawn_points")

	# Pick a random spawn point, and then cycle through them to see if it's free
	var start_index = randi() % spawn_points.size()
	# print("start_index: ", start_index)
	for i in range(spawn_points.size()):
		var check_index = (start_index + i) % spawn_points.size()
		var spawn_point = spawn_points[check_index]
		# print("spawn_point: ", spawn_point)
		if spawn_point.is_free():
			# Tell everyone to spawn my tank
			if Lobby.online(): spawn_tank_at.rpc(spawn_point.get_path(), sender_id)
			else: spawn_tank_at(spawn_point.get_path(), sender_id)
			break

@rpc("reliable", "authority", "call_local")
func spawn_tank_at(spawn_point_path: NodePath, sender_id: int) -> void:
	var spawn_point = get_node(spawn_point_path)
	var tank_name = "Tank-" + str(sender_id)
	var tank_root: Node = level.get_node("%Tanks")

	# Is the tank already in the scene?
	var tank: Node3D = null
	if tank_root.has_node(tank_name):
		tank = tank_root.get_node(tank_name)
	else:
		tank = preload("res://scenes/tank.tscn").instantiate()
		tank.name = tank_name
		tank_root.add_child(tank)

	# Spawn the tank
	tank.position = spawn_point.position
	tank.rotation = spawn_point.rotation
	tank.set_multiplayer_authority(sender_id)

	# If it's my tank, set my camera to its camera
	if sender_id == Lobby.id():
		Tank.me = tank
		tank.get_node("%TankCamera").make_current()
		tank.get_node("%FrontIndicator").show()
