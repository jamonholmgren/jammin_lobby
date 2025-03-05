class_name Main extends Node3D

static var menu: JamminLobbyUI
static var level: Node3D

const USER_NAMES = [ "Chainsaw", "Hammer", "Axe", "Crusher", "Dumptruck", "Volcano", "Thunder" ]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	menu = get_node("JamminLobbyUI")
	level = get_node("Level")
	Lobby.me.username = USER_NAMES[randi() % USER_NAMES.size()]
	Lobby.game_event.connect(_on_game_event)

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

func _on_game_event(command: String, _data: Dictionary = {}) -> void:
	if command == "start_game":
		# start the game
		start_game()

func start_game() -> void:
	spawn_tank_random()
	hide_menu()

func spawn_tank_random() -> void:
	# Pick a random place to spawn my tank
	var spawn_points = get_tree().get_nodes_in_group("spawn_points")

	# Pick a random spawn point, and then cycle through them to see if it's free
	var start_index = randi() % spawn_points.size()
	print("start_index: ", start_index)
	for i in range(spawn_points.size()):
		var check_index = (start_index + i) % spawn_points.size()
		var spawn_point = spawn_points[check_index]
		print("spawn_point: ", spawn_point)
		if spawn_point.is_free():
			# Tell everyone to spawn my tank
			spawn_tank_at.rpc(spawn_point, "Tank-" + str(Lobby.sid()))
			break

@rpc("reliable", "any_peer", "call_local")
func spawn_tank_at(spawn_point: Node3D, tank_name: String) -> void:
	# Spawn the tank
	var tank = preload("res://scenes/tank.tscn").instantiate()
	tank.name = tank_name
	level.get_node("%Tanks").add_child(tank)
	tank.position = spawn_point.position
	tank.rotation = spawn_point.rotation
	tank.set_multiplayer_authority(Lobby.sid())

	# If it's my tank, set my camera to its camera
	if Lobby.sid() == Lobby.id(): tank.get_node("%TankCamera").make_current()
