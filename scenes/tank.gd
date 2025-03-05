extends VehicleBody3D

@export var pid: int

@onready var turret: MeshInstance3D = $tank/Turret
@onready var r1: Node3D = %RotationPoint # For camera up/down
@onready var r2: Node3D = %RotationPoint2 # For camera left/right
@onready var bullet_spawn: Node3D = %BulletSpawn # Where the bullet comes out
@export var bullet_speed: float = 100.0

const MAX_STEER = 0.9
const ENGINE_POWER = 150
const ROTATION_SPEED = 3.0  # Adjust for smoother or snappier rotation

func _physics_process(delta: float) -> void:
	turret.rotation.y = lerp_angle(turret.rotation.y, r1.rotation.y, ROTATION_SPEED * delta)
	
	if Lobby.id() != get_multiplayer_authority(): return
	steering = move_toward(steering, Input.get_axis("right", "left") * MAX_STEER, delta * 10)
	engine_force = Input.get_axis("back", "forward") * ENGINE_POWER

func _input(event: InputEvent) -> void:
	# Check if the menu is visible -- if so, don't accept input
	if Main.menu.visible: return
	if Lobby.id() != get_multiplayer_authority(): return
	
	if event is InputEventMouseMotion:
		# Check if it's still in the screen or not
		r1.rotate_y(-event.relative.x * 0.005)
		r2.rotate_x(event.relative.y * 0.005)
	
	# TODO: Add button to fire weapon, and then call fire()

# Firing weapon
func fire() -> void:
	# Only the host for this tank can fire
	if Lobby.id() != get_multiplayer_authority(): return
	spawn_bullet.rpc()

@rpc("reliable", "any_peer", "call_local")
func spawn_bullet() -> void:
	# TODO: Implement bullet spawning
	pass
	# var bullet = preload("res://scenes/bullet.tscn").instantiate()
	# bullet.global_transform = bullet_spawn.global_transform
	# bullet.set_multiplayer_authority(Lobby.sid())
	# bullet.linear_velocity = bullet_spawn.global_transform.basis.z * bullet_speed
	# get_tree().current_scene.add_child(bullet)
