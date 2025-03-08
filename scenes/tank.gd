class_name Tank extends VehicleBody3D

static var me: Tank

@export var pid: int

@onready var barrel_rotation: Node3D = %BarrelRotation
@onready var tank_camera: Camera3D = %TankCamera
@onready var turret: MeshInstance3D = $tank/Turret
@onready var r1: Node3D = %RotationPoint # For camera up/down
@onready var r2: Node3D = %RotationPoint2 # For camera left/right
@onready var bullet_spawn: Node3D = %BulletSpawn # Where the bullet comes out
@export var bullet_speed: float = 100.0
@export var target_position: Vector3 = Vector3.ZERO

const MAX_STEER = 0.9
const ENGINE_POWER = 4000
const ROTATION_SPEED = 3.0  # Adjust for smoother or snappier rotation

func _ready() -> void:
	# The first tank to spawn is us
	if not me: me = self

func _physics_process(delta: float) -> void:
	rotate_toward_target(delta)
	%EngineAudio.pitch_scale = (linear_velocity.length() / 100.0) + 0.5

	# Only the host for this tank can move it, and only if the menu is not visible
	if Lobby.id() != get_multiplayer_authority(): return
	if Main.menu.visible: return
	
	# TODO: Allow turning when stopped somehow (torque is ok, but not great)
	# apply_torque(Vector3.UP * Input.get_axis("right", "left") * 35000.0)

	steering = move_toward(steering, Input.get_axis("right", "left") * MAX_STEER, delta * 10)
	engine_force = Input.get_axis("back", "forward") * ENGINE_POWER
	
	if Engine.get_physics_frames() % 10 == 0: update_target_position()

func update_target_position() -> void:
	target_position = tank_camera.get_camera_collision()

func rotate_toward_target(delta: float) -> void:
	if target_position == Vector3.ZERO: return
	turret.rotation.y = lerp_angle(turret.rotation.y, r1.rotation.y, ROTATION_SPEED * delta)
	var barrel_to_target = target_position - barrel_rotation.global_position
	var local_direction = barrel_rotation.global_transform.basis.inverse() * barrel_to_target
	var target_pitch = atan2(-local_direction.y, sqrt(local_direction.x * local_direction.x + local_direction.z * local_direction.z))
	barrel_rotation.rotation.x = lerp_angle(barrel_rotation.rotation.x, target_pitch, ROTATION_SPEED * delta)
	
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
	spawn_bullet.rpc(bullet_spawn.global_transform, bullet_spawn.global_transform.basis.z * bullet_speed, name + "-bullet-" + str(Engine.get_physics_frames()))

	# Apply a force to the tank to knock it back
	apply_central_impulse(-bullet_spawn.global_transform.basis.z * bullet_speed * 50.0)

@rpc("reliable", "any_peer", "call_local")
func spawn_bullet(start_transform: Transform3D, start_velo: Vector3, bullet_name: String) -> void:
	var bullet = Game.spawn_at(preload("res://scenes/bullet.tscn"), start_transform.origin)
	bullet.name = bullet_name
	bullet.global_transform = start_transform
	bullet.linear_velocity = start_velo

	Game.play_audio_3d(load("res://assets/tank-shot.mp3"), start_transform.origin)


