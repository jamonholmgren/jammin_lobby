extends VehicleBody3D

@export var pid: int

@onready var turret: MeshInstance3D = $tank/Turret
@onready var rotation_point: Node3D = $tank/Turret/RotationPoint

const MAX_STEER = 0.9
const ENGINE_POWER = 150

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
	steering = move_toward(steering, Input.get_axis("right", "left") * MAX_STEER, delta * 10)
	engine_force = Input.get_axis("back", "forward") * ENGINE_POWER

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		turret.rotate_y(-event.relative.x * 0.005)
		rotation_point.rotate_x(event.relative.y * 0.005)
