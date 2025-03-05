class_name Main extends Node3D

static var menu: JamminLobbyUI

const USER_NAMES = [ "Chainsaw", "Hammer", "Axe", "Crusher", "Dumptruck", "Volcano", "Thunder" ]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	menu = get_node("JamminLobbyUI")
	Lobby.me.username = USER_NAMES[randi() % USER_NAMES.size()]
	Lobby.game_event.connect(_on_game_event)
	Lobby.update_me({ "ready": false })

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

func _on_game_event(command: String, data: Dictionary = {}) -> void:
	if command == "start_game":
		# start the game
		pass

func start_game() -> void:
	spawn_tank_random()

func spawn_tank_random() -> void:
	# Pick a random place to spawn my tank
	var spawn_points = get_tree().get_nodes_in_group("spawn_points")

	# Pick a random spawn point, and then cycle through them to see if it's free
	var start_index = randi() % spawn_points.size()
	for i in range(spawn_points.size()):
		var check_index = (start_index + i) % spawn_points.size()
		var spawn_point = spawn_points[check_index]
		if spawn_point.is_free():
			# Delete my existing tank
			%StarterTank.queue_free()
			spawn_tank_at.rpc(spawn_point)
			break

@rpc("call_local", "reliable", "any_peer")
func spawn_tank_at(spawn_point: Node3D) -> void:
	# Whoever called this is the tank
	var sid = Lobby.sid()
	# var tank = 

	# Spawn the tank
	
	