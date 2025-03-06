extends VehicleBody3D

@export var pid: int

@onready var barrel_rotation: Node3D = %BarrelRotation
@onready var tank_camera: Camera3D = %TankCamera
@onready var turret: MeshInstance3D = $tank/Turret
@onready var r1: Node3D = %RotationPoint # For camera up/down
@onready var r2: Node3D = %RotationPoint2 # For camera left/right
@onready var bullet_spawn: Node3D = %BulletSpawn # Where the bullet comes out
@export var bullet_speed: float = 100.0

const MAX_STEER = 0.9
const ENGINE_POWER = 4000
const ROTATION_SPEED = 3.0  # Adjust for smoother or snappier rotation

func _physics_process(delta: float) -> void:
	turret.rotation.y = lerp_angle(turret.rotation.y, r1.rotation.y, ROTATION_SPEED * delta)
	
	if Lobby.id() != get_multiplayer_authority(): return
	steering = move_toward(steering, Input.get_axis("right", "left") * MAX_STEER, delta * 10)
	engine_force = Input.get_axis("back", "forward") * ENGINE_POWER
	
	if tank_camera.get_camera_collision():
		var target_position = tank_camera.get_camera_collision()
		var direction = (target_position - barrel_rotation.global_position).normalized()
		var target_angle_x = atan2(-direction.y, direction.z)  # Extract X-axis rotation
		# Lerp the rotation angle towards the target angle
		barrel_rotation.rotation.x = lerp_angle(barrel_rotation.rotation.x, target_angle_x, 0.05)
		# Clamp to prevent over-rotation
		barrel_rotation.rotation.x = clamp(barrel_rotation.rotation.x, -0.3, 0.2)
	else:
		barrel_rotation.rotation.x = barrel_rotation.rotation.x

func _input(event: InputEvent) -> void:
	# Check if the menu is visible -- if so, don't accept input
	if Main.menu.visible: return
	if Lobby.id() != get_multiplayer_authority(): return
	
	if event is InputEventMouseMotion:
		# Check if it's still in the screen or not
		r1.rotate_y(-event.relative.x * 0.005)
		r2.rotate_x(event.relative.y * 0.005)
		r2.rotation.x = clamp(r2.rotation.x, -1.5, 1.5)
		
	if event.is_action_pressed("fire"): fire()

# Firing weapon
func fire() -> void:
	# Only the host for this tank can fire
	if Lobby.id() != get_multiplayer_authority(): return
	spawn_bullet.rpc()

@rpc("reliable", "any_peer", "call_local")
func spawn_bullet() -> void:
	var bullet = preload("res://scenes/bullet.tscn").instantiate()
	bullet.global_transform = bullet_spawn.global_transform
	bullet.set_multiplayer_authority(Lobby.sender_id())
	bullet.linear_velocity = bullet_spawn.global_transform.basis.z * bullet_speed
	get_tree().current_scene.add_child(bullet)
