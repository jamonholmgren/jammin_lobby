extends VehicleBody3D

@export var pid: int

@onready var turret: MeshInstance3D = $tank/Turret
@onready var r1: Node3D = $tank/Main/RotationPoint
@onready var r2: Node3D = $tank/Main/RotationPoint/RotationPoint2

const MAX_STEER = 0.9
const ENGINE_POWER = 150
const ROTATION_SPEED = 3.0  # Adjust for smoother or snappier rotation

func _physics_process(delta: float) -> void:
	turret.rotation.y = lerp_angle(turret.rotation.y, r1.rotation.y, ROTATION_SPEED * delta)
	
	if Lobby.id() != get_multiplayer_authority(): return
	steering = move_toward(steering, Input.get_axis("right", "left") * MAX_STEER, delta * 10)
	engine_force = Input.get_axis("back", "forward") * ENGINE_POWER

func _unhandled_input(event: InputEvent) -> void:
	# Check if the menu is visible -- if so, don't accept input
	if Main.menu.visible: return
	if Lobby.id() != get_multiplayer_authority(): return
	
	if event is InputEventMouseMotion:
		# Check if it's still in the screen or not
		r1.rotate_y(-event.relative.x * 0.005)
		r2.rotate_x(event.relative.y * 0.005)
